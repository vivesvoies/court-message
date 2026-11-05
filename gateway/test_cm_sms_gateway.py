"""Unit tests for the gateway daemon. They stub out gammu, so they run
without a modem (and without python3-gammu installed):

    python3 -m unittest discover -s gateway
"""

import configparser
import os
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


class DaemonTestCase(unittest.TestCase):
    def setUp(self):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        self.reset_flag = os.path.join(tmp.name, "modem-reset")
        self.state_file = os.path.join(tmp.name, "state.json")

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


if __name__ == "__main__":
    unittest.main()
