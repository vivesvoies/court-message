"""Unit tests for the gateway daemon. They stub out gammu, so they run
without a modem (and without python3-gammu installed):

    python3 -m unittest discover -s gateway
"""

import configparser
import os
import socket
import sys
import tempfile
import types
import unittest
from unittest import mock

# Stand-in for python3-gammu, which needs libgammu and a modem. Installed
# unconditionally so the tests behave the same on a Pi that has the real one.
fake_gammu = types.ModuleType("gammu")


class GSMError(Exception):
    pass


class ERR_EMPTY(GSMError):
    pass


fake_gammu.GSMError = GSMError
fake_gammu.ERR_EMPTY = ERR_EMPTY
fake_gammu.StateMachine = mock.MagicMock
sys.modules["gammu"] = fake_gammu

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import cm_sms_gateway as gateway  # noqa: E402
import requests  # noqa: E402


class FakeModem:
    def __init__(self, state="HomeNetwork", inbox=None):
        self.state = state
        self.sent = []
        self.inbox = inbox or []
        self.deleted = []

    def network_state(self):
        return self.state

    def health(self):
        return {"signal_percent": 60, "network_state": self.state}

    def send(self, number, text, report=False):
        self.sent.append((number, text))
        self.report_requested = report
        # One network reference per SMS part; tests send single-part texts.
        return [len(self.sent) % 256]

    def read_inbox(self):
        return list(self.inbox)

    def delete(self, linked_message):
        self.deleted.append(linked_message)
        self.inbox.remove(linked_message)


def sms_part(text, part=-1, of=-1):
    """A raw gammu SMS dict; part/of describe a concatenated (long) SMS."""
    return {
        "Number": "+33611111111",
        "Text": text,
        "DateTime": None,
        "UDH": {"ID8bit": 42 if of > 0 else -1, "ID16bit": -1, "PartNumber": part, "AllParts": of},
    }


def unreachable_modem(*_args):
    raise GSMError("Error opening device, it doesn't exist")


class DaemonTestCase(unittest.TestCase):
    def setUp(self):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        self.reset_flag = os.path.join(tmp.name, "modem-reset")
        self.state_file = os.path.join(tmp.name, "state.json")
        # Not under systemd: sd_notify must stay a no-op.
        environ = mock.patch.dict(os.environ)
        environ.start()
        self.addCleanup(environ.stop)
        os.environ.pop("NOTIFY_SOCKET", None)

    def build_daemon(self, modem_factory, **modem_options):
        config = configparser.ConfigParser()
        config["app"] = {
            "url": "https://cm.test",
            "token": "token",
            "line_phone": "+33600000000",
            "state_file": self.state_file,
        }
        config["modem"] = {
            "reset_flag": self.reset_flag,
            "send_pause": "0",
            **modem_options,
        }
        # Replaces Modem construction only: its static helpers stay real.
        real = gateway.Modem
        patcher = mock.patch.object(
            gateway,
            "Modem",
            side_effect=modem_factory,
            decode=real.decode,
            missing_parts=real.missing_parts,
        )
        patcher.start()
        self.addCleanup(patcher.stop)
        daemon = gateway.Daemon(config)
        daemon.client = mock.Mock()
        return daemon

    def heartbeat(self, daemon):
        daemon._report_heartbeat()
        return daemon.client.report_heartbeat.call_args.args


class RegistrationTest(DaemonTestCase):
    def test_does_not_claim_messages_while_not_registered(self):
        daemon = self.build_daemon(lambda *_args: FakeModem(state="NoNetwork"))

        daemon.send_outbound()

        daemon.client.claim_messages.assert_not_called()

    def test_reports_the_modem_unhealthy_while_not_registered(self):
        daemon = self.build_daemon(lambda *_args: FakeModem(state="NoNetwork"))

        daemon.send_outbound()
        modem_ok, details = self.heartbeat(daemon)

        self.assertFalse(modem_ok)
        self.assertIn("not registered", details["error"])
        self.assertEqual("NoNetwork", details["network_state"])
        self.assertEqual(60, details["signal_percent"])

    def test_sends_claimed_messages_once_registered(self):
        modem = FakeModem(state="RoamingNetwork")
        daemon = self.build_daemon(lambda *_args: modem)
        daemon.client.claim_messages.return_value = [
            {"uuid": "u1", "to": "+33611111111", "content": "Bonjour"}
        ]

        daemon.send_outbound()
        modem_ok, details = self.heartbeat(daemon)

        self.assertEqual([("+33611111111", "Bonjour")], modem.sent)
        daemon.client.report_status.assert_called_once_with("u1", "submitted")
        self.assertTrue(modem_ok)
        self.assertIsNone(details["error"])


class MultipartTest(DaemonTestCase):
    def setUp(self):
        super().setUp()
        # Incomplete groups are not decodable: gammu returns None for them.
        decode = mock.patch.object(gateway.gammu, "DecodeSMS", return_value=None, create=True)
        decode.start()
        self.addCleanup(decode.stop)

    def pushed_texts(self, daemon):
        return [call.args[1] for call in daemon.client.push_inbound.call_args_list]

    def test_holds_a_long_sms_back_until_all_its_parts_arrived(self):
        modem = FakeModem(inbox=[[sms_part("Bon", 1, 2)]])
        daemon = self.build_daemon(lambda *_args: modem)
        daemon.client.push_inbound.return_value = True

        daemon.deliver_inbound()
        self.assertEqual([], self.pushed_texts(daemon))
        self.assertEqual([], modem.deleted)

        modem.inbox = [[sms_part("Bon", 1, 2), sms_part("jour", 2, 2)]]
        daemon.deliver_inbound()
        self.assertEqual(["Bonjour"], self.pushed_texts(daemon))
        self.assertEqual(1, len(modem.deleted))

    def test_forwards_an_incomplete_sms_after_the_grace_period(self):
        modem = FakeModem(inbox=[[sms_part("Bon", 1, 2)]])
        daemon = self.build_daemon(lambda *_args: modem, multipart_grace="0")
        daemon.client.push_inbound.return_value = True

        daemon.deliver_inbound()

        self.assertEqual(["Bon"], self.pushed_texts(daemon))

    def test_forwards_a_single_part_sms_right_away(self):
        modem = FakeModem(inbox=[[sms_part("Oui")]])
        daemon = self.build_daemon(lambda *_args: modem)
        daemon.client.push_inbound.return_value = True

        daemon.deliver_inbound()

        self.assertEqual(["Oui"], self.pushed_texts(daemon))


class JournalFailureTest(DaemonTestCase):
    def test_still_acknowledges_a_sent_message_when_the_journal_cannot_be_written(self):
        modem = FakeModem()
        daemon = self.build_daemon(lambda *_args: modem)
        # A full or read-only SD card: the journal's directory is unusable.
        blocker = os.path.join(os.path.dirname(self.state_file), "not-a-directory")
        open(blocker, "w").close()
        daemon.journal.path = os.path.join(blocker, "state.json")
        daemon.client.claim_messages.return_value = [
            {"uuid": "u1", "to": "+33611111111", "content": "Bonjour"}
        ]

        daemon.send_outbound()

        self.assertEqual(1, len(modem.sent))
        daemon.client.report_status.assert_called_once_with("u1", "submitted")


class ModemResetTest(DaemonTestCase):
    def test_requests_a_usb_reset_after_repeated_open_failures(self):
        daemon = self.build_daemon(unreachable_modem, reset_after_failures="3")

        daemon._ensure_modem()
        self.assertFalse(os.path.exists(self.reset_flag))

        daemon._ensure_modem()
        self.assertTrue(os.path.exists(self.reset_flag))
        self.assertEqual(0, daemon.init_failures)

    def test_a_successful_open_clears_the_failure_count(self):
        attempts = iter([GSMError("gone"), FakeModem(), GSMError("gone")])

        def flaky(*_args):
            attempt = next(attempts)
            if isinstance(attempt, Exception):
                raise attempt
            return attempt

        daemon = self.build_daemon(flaky, reset_after_failures="2")
        self.assertIsNotNone(daemon._ensure_modem())
        self.assertIsNone(daemon._ensure_modem())

        self.assertFalse(os.path.exists(self.reset_flag))

    def test_a_missing_reset_directory_does_not_crash_the_daemon(self):
        daemon = self.build_daemon(unreachable_modem, reset_after_failures="1")
        daemon.reset_flag = os.path.join(self.reset_flag, "missing", "flag")

        self.assertIsNone(daemon._ensure_modem())


class HealthcheckPingTest(DaemonTestCase):
    def test_pings_the_healthcheck_url_at_most_once_a_minute(self):
        daemon = self.build_daemon(lambda *_args: FakeModem())
        daemon.healthcheck_url = "https://hc-ping.test/check"

        with mock.patch.object(gateway.requests, "get") as get, \
                mock.patch.object(gateway.time, "monotonic") as monotonic:
            for now in (1000, 1010, 1050, 1060, 1070):
                monotonic.return_value = now
                daemon._ping_healthcheck()

        self.assertEqual(2, get.call_count)


class DecodeTest(unittest.TestCase):
    def part(self, text):
        return {"Number": "+33611111111", "Text": text, "DateTime": None}

    def test_joins_the_decoded_entries(self):
        decoded = {"Entries": [{"Buffer": "Bonjour "}, {"Buffer": "à vous"}]}
        with mock.patch.object(gateway.gammu, "DecodeSMS", return_value=decoded, create=True):
            _sender, text, _received_at = gateway.Modem.decode([self.part("Bonjour "), self.part("à vous")])

        self.assertEqual("Bonjour à vous", text)

    def test_falls_back_to_the_raw_text_when_decoding_yields_none(self):
        # Seen on the Pi with an SMS carrying a user-defined header: gammu
        # decodes it to entries without text.
        decoded = {"Entries": [{"ID": "UserUDH", "Buffer": None}]}
        with mock.patch.object(gateway.gammu, "DecodeSMS", return_value=decoded, create=True):
            _sender, text, _received_at = gateway.Modem.decode([self.part("STATE?state=Active")])

        self.assertEqual("STATE?state=Active", text)

    def test_uses_the_raw_text_of_every_part_when_not_decodable(self):
        with mock.patch.object(gateway.gammu, "DecodeSMS", return_value=None, create=True):
            _sender, text, _received_at = gateway.Modem.decode([self.part("Bon"), self.part("jour")])

        self.assertEqual("Bonjour", text)


class PushInboundTest(unittest.TestCase):
    """push_inbound decides whether an SMS may leave the SIM: only when the
    app has it, or has refused that SMS for good."""

    def push(self, status_code):
        client = gateway.AppClient("https://cm.test", "token", "+33600000000")
        response = requests.Response()
        response.status_code = status_code
        response.reason = "test"
        response.url = "https://cm.test/gateway/v1/inbound_messages"
        client.session = mock.Mock(post=mock.Mock(return_value=response))
        return client.push_inbound("+33611111111", "Bonjour", None, "id")

    def test_delivered_messages_can_leave_the_sim(self):
        self.assertTrue(self.push(201))

    def test_messages_the_app_refuses_for_good_can_leave_the_sim(self):
        self.assertTrue(self.push(422))  # unknown sender
        self.assertTrue(self.push(400))  # invalid payload

    def test_messages_stay_on_the_sim_when_the_app_cannot_take_them_yet(self):
        # Bad or rotated token, an app without the gateway API (or a wrong
        # url), throttling, server errors: the SMS is fine, retry later.
        for status_code in (401, 403, 404, 429, 500, 503):
            with self.assertRaises(requests.RequestException, msg=status_code):
                self.push(status_code)


# A status report captured from the EC25's "SR" memory on 2026-11-26: message
# reference 246 delivered to +33645505205 (TP-ST 0x00).
REAL_STATUS_REPORT = "0693050066F0F006F60B913346555002F562116291854440621162918524400000FFFFFF"


def status_report(reference, status, number="33645505205"):
    """Builds a status report PDU like the one above, for another reference
    and status."""
    pdu = bytearray.fromhex(REAL_STATUS_REPORT)
    smsc = pdu[0] + 1
    pdu[smsc + 1] = reference
    address_octets = (pdu[smsc + 2] + 1) // 2
    pdu[smsc + 4 + address_octets + 14] = status
    return pdu.hex().upper()


class FakeStatusPort:
    def __init__(self, reports=None):
        self.reports = list(reports or [])
        self.enabled = 0
        self.fail = None

    def enable(self):
        self.enabled += 1

    def drain(self, handler):
        if self.fail:
            raise self.fail
        for pdu in list(self.reports):
            if handler(pdu):
                self.reports.remove(pdu)


class StatusReportParsingTest(unittest.TestCase):
    def test_reads_the_reference_recipient_and_status_of_a_real_report(self):
        report = gateway.parse_status_report(REAL_STATUS_REPORT)
        self.assertEqual(report, {"reference": 246, "number": "+33645505205", "status": 0})

    def test_rejects_a_pdu_that_is_not_a_status_report(self):
        deliver = "07913396050036F0040B913346555002F50000621162918544400474747A0E"
        with self.assertRaises(ValueError):
            gateway.parse_status_report(deliver)

    def test_rejects_a_truncated_pdu(self):
        with self.assertRaises(ValueError):
            gateway.parse_status_report(REAL_STATUS_REPORT[:30])

    def test_maps_network_statuses_to_app_statuses(self):
        outcome = gateway.delivery_outcome
        self.assertEqual(outcome(0x00), "delivered")
        self.assertEqual(outcome(0x01), "delivered")
        self.assertIsNone(outcome(0x20), "the service centre is still trying")
        self.assertIsNone(outcome(0x3F))
        self.assertEqual(outcome(0x46), "expired")
        self.assertEqual(outcome(0x41), "undeliverable")
        self.assertEqual(outcome(0x62), "undeliverable", "temporary error, no more attempts")


class FakeAtSession:
    def __init__(self, listing, fail_on=None):
        self.listing = listing
        self.fail_on = fail_on
        self.commands = []

    def __enter__(self):
        return self

    def __exit__(self, *_exc):
        return False

    def command(self, command):
        self.commands.append(command)
        if command == self.fail_on:
            raise gateway.StatusPortError(f"{command}: ERROR")
        if command == "AT+CMGL=4":
            return self.listing
        return []


class StatusPortTest(unittest.TestCase):
    def drain(self, session, handler):
        port = gateway.StatusPort("/dev/null")
        with mock.patch.object(port, "_open", return_value=session):
            port.drain(handler)

    def test_reads_the_status_report_memory_and_deletes_what_was_handled(self):
        # As the EC25 answered on 2026-11-26.
        session = FakeAtSession(["+CMGL: 0,,29", "PDU-A", "+CMGL: 1,,29", "PDU-B"])
        self.drain(session, lambda pdu: pdu == "PDU-B")
        self.assertEqual(
            session.commands,
            ['AT+CPMS="SR","ME","ME"', "AT+CMGF=0", "AT+CMGL=4", "AT+CMGD=1", 'AT+CPMS="ME","ME","ME"'],
        )

    def test_gives_gammu_its_memory_back_even_when_listing_fails(self):
        session = FakeAtSession([], fail_on="AT+CMGL=4")
        with self.assertRaises(gateway.StatusPortError):
            self.drain(session, lambda pdu: True)
        self.assertEqual(session.commands[-1], 'AT+CPMS="ME","ME","ME"')


class DeliveryReportTest(DaemonTestCase):
    def build(self, reports=None):
        self.modem = FakeModem()
        self.port = FakeStatusPort(reports)
        patcher = mock.patch.object(gateway, "StatusPort", return_value=self.port)
        patcher.start()
        self.addCleanup(patcher.stop)
        daemon = self.build_daemon(lambda *_: self.modem, status_port="/dev/ttyUSB3")
        daemon.client.claim_messages.return_value = []
        return daemon

    def send(self, daemon, uuid):
        daemon.client.claim_messages.return_value = [{"uuid": uuid, "to": "+33645505205", "content": "Bonjour"}]
        daemon.send_outbound()
        daemon.client.claim_messages.return_value = []

    def test_turns_reports_on_in_the_modem_and_asks_for_one_with_each_sms(self):
        daemon = self.build()
        self.send(daemon, "u1")
        self.assertEqual(self.port.enabled, 1)
        self.assertTrue(self.modem.report_requested)

    def test_reports_delivery_once_the_network_confirms_it(self):
        daemon = self.build()
        self.send(daemon, "u1")
        daemon.client.report_status.reset_mock()
        self.port.reports.append(status_report(1, 0x00))

        daemon.collect_reports()

        daemon.client.report_status.assert_called_once_with("u1", "delivered")
        self.assertEqual(self.port.reports, [], "the report leaves the modem's 5-slot memory")
        self.assertEqual(daemon.journal.awaiting, {})

    def test_reports_a_permanent_failure_as_undeliverable(self):
        daemon = self.build()
        self.send(daemon, "u1")
        daemon.client.report_status.reset_mock()
        self.port.reports.append(status_report(1, 0x41))

        daemon.collect_reports()

        daemon.client.report_status.assert_called_once_with("u1", "undeliverable")

    def test_waits_for_a_final_report_while_the_service_centre_keeps_trying(self):
        daemon = self.build()
        self.send(daemon, "u1")
        daemon.client.report_status.reset_mock()
        self.port.reports.append(status_report(1, 0x20))

        daemon.collect_reports()

        daemon.client.report_status.assert_not_called()
        self.assertEqual(self.port.reports, [])
        self.assertIn("u1", daemon.journal.awaiting)

    def test_a_long_sms_is_delivered_only_when_every_part_is(self):
        daemon = self.build()
        self.modem.send = lambda *_args, **_kwargs: [10, 11]
        self.send(daemon, "u1")
        daemon.client.report_status.reset_mock()

        self.port.reports.append(status_report(10, 0x00))
        daemon.collect_reports()
        daemon.client.report_status.assert_not_called()

        self.port.reports.append(status_report(11, 0x00))
        daemon.collect_reports()
        daemon.client.report_status.assert_called_once_with("u1", "delivered")

    def test_a_long_sms_fails_as_soon_as_one_part_does(self):
        daemon = self.build()
        self.modem.send = lambda *_args, **_kwargs: [10, 11]
        self.send(daemon, "u1")
        daemon.client.report_status.reset_mock()
        self.port.reports.append(status_report(11, 0x46))

        daemon.collect_reports()

        daemon.client.report_status.assert_called_once_with("u1", "expired")

    def test_a_reused_reference_goes_to_the_latest_message_sent_with_it(self):
        daemon = self.build()
        self.modem.send = lambda *_args, **_kwargs: [7]
        self.send(daemon, "old")
        self.send(daemon, "new")
        daemon.client.report_status.reset_mock()
        self.port.reports.append(status_report(7, 0x00))

        daemon.collect_reports()

        daemon.client.report_status.assert_called_once_with("new", "delivered")

    def test_holds_the_outcome_back_until_submitted_is_acknowledged(self):
        daemon = self.build()
        daemon.client.report_status.side_effect = requests.ConnectionError("app down")
        self.send(daemon, "u1")
        self.port.reports.append(status_report(1, 0x00))

        daemon.collect_reports()
        self.assertEqual(
            [c.args for c in daemon.client.report_status.call_args_list], [("u1", "submitted")],
            "delivered must not reach the app before submitted, or submitted would overwrite it",
        )

        daemon.client.report_status.side_effect = None
        daemon.client.report_status.reset_mock()
        daemon.send_outbound()
        daemon.collect_reports()
        self.assertEqual(
            [c.args for c in daemon.client.report_status.call_args_list], [("u1", "submitted"), ("u1", "delivered")]
        )

    def test_keeps_the_outcome_when_the_app_cannot_take_it_yet(self):
        daemon = self.build()
        self.send(daemon, "u1")
        daemon.client.report_status.side_effect = requests.ConnectionError("app down")
        self.port.reports.append(status_report(1, 0x00))

        daemon.collect_reports()

        self.assertEqual(self.port.reports, [], "recorded in the journal, so it can leave the modem")
        self.assertEqual(daemon.journal.awaiting["u1"]["results"], {"1": "delivered"})
        daemon.client.report_status.side_effect = None
        daemon.collect_reports()
        daemon.client.report_status.assert_called_with("u1", "delivered")

    def test_outcomes_survive_a_restart(self):
        daemon = self.build()
        self.send(daemon, "u1")
        restarted = self.build([status_report(1, 0x00)])

        restarted.collect_reports()

        restarted.client.report_status.assert_called_once_with("u1", "delivered")

    def test_drops_reports_nobody_waits_for_and_unreadable_ones(self):
        daemon = self.build([status_report(99, 0x00), "00"])

        daemon.collect_reports()

        daemon.client.report_status.assert_not_called()
        self.assertEqual(self.port.reports, [])

    def test_gives_up_waiting_after_a_few_days(self):
        daemon = self.build()
        self.send(daemon, "u1")
        daemon.journal.awaiting["u1"]["at"] = "2026-01-01T00:00:00+00:00"

        daemon.collect_reports()

        self.assertEqual(daemon.journal.awaiting, {})

    def test_a_failing_status_port_does_not_stop_the_gateway(self):
        daemon = self.build()
        self.port.fail = OSError("device busy")

        daemon.collect_reports()  # must not raise

    def test_leaves_the_status_port_alone_while_the_modem_is_gone(self):
        daemon = self.build()
        daemon.modem = None
        self.port.fail = AssertionError("must not be read")

        daemon.collect_reports()

    def test_without_a_status_port_nothing_changes(self):
        self.modem = FakeModem()
        daemon = self.build_daemon(lambda *_: self.modem)
        daemon.client.claim_messages.return_value = [{"uuid": "u1", "to": "+33645505205", "content": "Bonjour"}]

        daemon.send_outbound()
        daemon.collect_reports()

        self.assertFalse(self.modem.report_requested)
        self.assertEqual(daemon.journal.awaiting, {})


class SdNotifyTest(unittest.TestCase):
    def test_sends_the_message_to_the_notify_socket(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = os.path.join(tmp, "notify")
            with socket.socket(socket.AF_UNIX, socket.SOCK_DGRAM) as server:
                server.bind(path)
                with mock.patch.dict(os.environ, {"NOTIFY_SOCKET": path}):
                    gateway.sd_notify("WATCHDOG=1")

                self.assertEqual(b"WATCHDOG=1", server.recv(64))

    def test_is_a_no_op_outside_systemd(self):
        with mock.patch.dict(os.environ):
            os.environ.pop("NOTIFY_SOCKET", None)

            gateway.sd_notify("READY=1")


if __name__ == "__main__":
    unittest.main()
