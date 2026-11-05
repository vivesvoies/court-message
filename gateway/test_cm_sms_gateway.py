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


class FakeModem:
    def __init__(self, state="HomeNetwork"):
        self.state = state
        self.sent = []

    def network_state(self):
        return self.state

    def health(self):
        return {"signal_percent": 60, "network_state": self.state}

    def send(self, number, text):
        self.sent.append((number, text))

    def read_inbox(self):
        return []


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
        patcher = mock.patch.object(gateway, "Modem", side_effect=modem_factory)
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
