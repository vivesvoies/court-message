#!/usr/bin/env python3
"""CM SMS gateway daemon.

Bridges a SIM modem (driven through gammu) and the court-message app:

  * polls the app to claim outbound messages queued on this gateway's
    phone line and sends them through the modem;
  * reads SMS received by the modem and pushes them to the app;
  * reports send outcomes back to the app;
  * reports modem health (signal, network state) through a heartbeat, and
    pings an optional external dead-man's switch.

All communication is outbound HTTPS from this device to the app,
authenticated with a bearer token issued by `rake sms_gateway:provision`.
The device never listens on any port. Run one instance of this daemon per
SIM modem; multiple modems on the same device are handled by running the
daemon several times with different config files.

Dependencies (Raspberry Pi OS / Debian):
    sudo apt install python3-gammu python3-requests
"""

import configparser
import hashlib
import json
import logging
import os
import signal
import sys
import time
from datetime import datetime, timezone

import gammu
import requests

log = logging.getLogger("cm-sms-gateway")

# GSM 03.38 default alphabet (basic + extension tables). Anything outside
# this set forces Unicode (UCS-2) encoding, which gammu handles for us.
GSM_BASIC = set(
    "@£$¥èéùìòÇ\nØø\rÅåΔ_ΦΓΛΩΠΨΣΘΞÆæßÉ !\"#¤%&'()*+,-./0123456789:;<=>?"
    "¡ABCDEFGHIJKLMNOPQRSTUVWXYZÄÖÑܧ¿abcdefghijklmnopqrstuvwxyzäöñüà"
)
GSM_EXTENSION = set("^{}\\[~]|€")

DEFAULT_STATE_FILE = "/var/lib/cm-sms-gateway/state.json"


def is_gsm_compatible(text):
    return all(char in GSM_BASIC or char in GSM_EXTENSION for char in text)


class AppClient:
    """Client for the court-message gateway API (see Gateway::V1)."""

    def __init__(self, base_url, token, line_phone, timeout=30):
        self.base_url = base_url.rstrip("/")
        self.line_phone = line_phone
        self.timeout = timeout
        self.session = requests.Session()
        self.session.headers["Authorization"] = f"Bearer {token}"

    def claim_messages(self, limit):
        response = self.session.post(
            f"{self.base_url}/gateway/v1/messages/claims",
            json={"limit": limit, "phone": self.line_phone},
            timeout=self.timeout,
        )
        response.raise_for_status()
        return response.json()["messages"]

    def report_status(self, uuid, status):
        response = self.session.patch(
            f"{self.base_url}/gateway/v1/messages/{uuid}",
            json={"status": status},
            timeout=self.timeout,
        )
        if response.status_code == 404:
            # The app no longer knows this message. Nothing more we can do
            # about it; treat it as acknowledged so it doesn't stick around
            # in the journal forever.
            log.warning("app does not know message %s anymore, treating as acked", uuid)
            return
        response.raise_for_status()

    def push_inbound(self, sender, text, received_at, modem_message_id):
        """Returns True when the SMS can be removed from the SIM (delivered,
        or permanently rejected by the app), False when it should be kept
        and retried later (network trouble or a transient server error)."""
        response = self.session.post(
            f"{self.base_url}/gateway/v1/inbound_messages",
            json={
                "from": sender,
                "to": self.line_phone,
                "text": text,
                "received_at": received_at,
                "modem_message_id": modem_message_id,
            },
            timeout=self.timeout,
        )
        if response.status_code == 201:
            return True
        if response.status_code == 422:
            # The app refuses it by design (e.g. unknown sender). Log the
            # full content now: this is the only copy that will ever exist.
            log.warning(
                "app permanently rejected inbound SMS from %s (422): %r",
                sender,
                text,
            )
            return True
        if 400 <= response.status_code < 500:
            # Any other 4xx means the payload itself is permanently invalid.
            # Keeping it on the SIM would just wedge every future cycle, so
            # log it in full and let it go.
            log.error(
                "app rejected inbound SMS from %s as invalid (HTTP %s): %r",
                sender,
                response.status_code,
                text,
            )
            return True
        # Network errors and 5xx: keep the SMS on the SIM, retry next cycle.
        response.raise_for_status()
        return False

    def report_heartbeat(self, modem_ok, details):
        response = self.session.post(
            f"{self.base_url}/gateway/v1/heartbeat",
            json={
                "phone": self.line_phone,
                "modem_ok": modem_ok,
                "details": details,
            },
            timeout=self.timeout,
        )
        if response.status_code == 404:
            log.warning(
                "app does not recognize phone %s for heartbeat", self.line_phone
            )
            return
        response.raise_for_status()


class Modem:
    """Thin wrapper around gammu for sending and draining the SIM inbox."""

    def __init__(self, gammu_config, gammu_section=0):
        self.state_machine = gammu.StateMachine()
        self.state_machine.ReadConfig(Section=gammu_section, Filename=gammu_config)
        self.state_machine.Init()

    def send(self, number, text):
        smsinfo = {
            "Class": -1,
            "Unicode": not is_gsm_compatible(text),
            "Entries": [{"ID": "ConcatenatedTextLong", "Buffer": text}],
        }
        for part in gammu.EncodeSMS(smsinfo):
            part["SMSC"] = {"Location": 1}
            part["Number"] = number
            self.state_machine.SendSMS(part)

    def read_inbox(self):
        """Returns received messages as a list of multipart groups (lists of
        raw gammu SMS dicts), multipart parts already linked together."""
        messages = []
        start = True
        current = None
        while True:
            try:
                if start:
                    current = self.state_machine.GetNextSMS(Folder=0, Start=True)
                    start = False
                else:
                    current = self.state_machine.GetNextSMS(
                        Folder=0, Location=current[0]["Location"]
                    )
            except gammu.ERR_EMPTY:
                break
            messages.append(current)
        return gammu.LinkSMS(messages)

    def delete(self, linked_message):
        for part in linked_message:
            try:
                self.state_machine.DeleteSMS(Folder=0, Location=part["Location"])
            except gammu.ERR_EMPTY:
                pass

    def health(self):
        """Returns {"signal_percent": int, "network_state": str} when the
        modem answers, or the gammu error message (str) when it does not."""
        try:
            signal_quality = self.state_machine.GetSignalQuality()
            network = self.state_machine.GetNetworkInfo()
            return {
                "signal_percent": signal_quality.get("SignalPercent"),
                "network_state": network.get("State"),
            }
        except gammu.GSMError as error:
            return str(error)

    @staticmethod
    def decode(linked_message):
        """Returns (sender, text, received_at ISO 8601) for a linked group."""
        decoded = gammu.DecodeSMS(linked_message)
        if decoded is None:
            text = linked_message[0]["Text"]
        else:
            text = "".join(
                entry["Buffer"] for entry in decoded["Entries"] if entry.get("Buffer")
            )
        sender = linked_message[0]["Number"]
        received_at = linked_message[0]["DateTime"]
        return sender, text, received_at.isoformat() if received_at else None


class Journal:
    """Durable record of SMS that were already handed to the modem (or
    failed there) but whose status has not yet been acknowledged by the
    app. This is what makes send_outbound crash-safe: without it, a daemon
    restart (or a lost PATCH) between a successful modem.send and its ack
    would cause the same message to be claimed and sent again."""

    def __init__(self, path):
        self.path = path
        self.sent = self._load()

    def _load(self):
        try:
            with open(self.path, "r", encoding="utf-8") as handle:
                data = json.load(handle)
            return dict(data.get("sent", {}))
        except FileNotFoundError:
            return {}
        except (OSError, ValueError) as error:
            log.warning(
                "could not load state file %s, starting with an empty journal: %s",
                self.path,
                error,
            )
            return {}

    def _save(self):
        directory = os.path.dirname(self.path)
        if directory:
            os.makedirs(directory, exist_ok=True)
        tmp_path = f"{self.path}.tmp"
        with open(tmp_path, "w", encoding="utf-8") as handle:
            json.dump({"sent": self.sent}, handle)
        os.replace(tmp_path, self.path)

    def record(self, uuid, status):
        self.sent[uuid] = {
            "status": status,
            "at": datetime.now(timezone.utc).isoformat(),
        }
        self._save()

    def clear(self, uuid):
        if uuid in self.sent:
            del self.sent[uuid]
            self._save()

    def pending(self):
        """Returns a snapshot list of (uuid, entry) still awaiting ack."""
        return list(self.sent.items())


class Daemon:
    def __init__(self, config):
        app = config["app"]
        modem = config["modem"]
        self.poll_interval = app.getint("poll_interval", fallback=10)
        self.claim_limit = app.getint("claim_limit", fallback=5)
        self.send_pause = modem.getfloat("send_pause", fallback=2.0)
        self.healthcheck_url = app.get("healthcheck_url", fallback=None)
        self.client = AppClient(app["url"], app["token"], app["line_phone"])
        self.gammu_config = modem.get("gammu_config", "/etc/gammurc")
        self.gammu_section = modem.getint("gammu_section", fallback=0)
        self.journal = Journal(app.get("state_file", fallback=DEFAULT_STATE_FILE))
        self.last_error = None
        self.modem = self._ensure_modem()
        self.running = True

    def stop(self, *_args):
        log.info("stopping...")
        self.running = False

    def _ensure_modem(self):
        """(Re)initializes the modem link. Returns a Modem instance, or None
        (with self.last_error set) when the modem can't be reached. Failure
        here must never crash the daemon: the app should be able to tell
        'Pi up, modem dead' from 'Pi down' via the heartbeat."""
        try:
            modem = Modem(self.gammu_config, self.gammu_section)
        except gammu.GSMError as error:
            log.error("modem initialization failed: %s", error)
            self.last_error = str(error)
            return None
        self.last_error = None
        return modem

    def run(self):
        log.info("gateway started for line %s", self.client.line_phone)
        while self.running:
            self.last_error = None
            cycle_ok = True
            try:
                if self.modem is None:
                    self.modem = self._ensure_modem()
                self.deliver_inbound()
                self.send_outbound()
            except (requests.RequestException, gammu.GSMError) as error:
                log.error("cycle failed, will retry: %s", error)
                cycle_ok = False
                if isinstance(error, gammu.GSMError):
                    # Looks like a dead link: force a fresh Init() next cycle.
                    self.last_error = str(error)
                    self.modem = None
            self._report_heartbeat()
            if cycle_ok:
                self._ping_healthcheck()
            for _ in range(self.poll_interval):
                if not self.running:
                    break
                time.sleep(1)

    def send_outbound(self):
        # Drain any acks left over from a previous cycle (or a previous run
        # of the daemon) first, so they eventually get through even when no
        # new messages are claimed.
        self._retry_journal_acks()
        if self.modem is None:
            return
        messages = self.client.claim_messages(self.claim_limit)
        for message in messages:
            uuid, to, content = message["uuid"], message["to"], message["content"]
            journaled = self.journal.sent.get(uuid)
            if journaled is not None:
                # Already handed to the modem earlier; only the ack is
                # missing. Do not send it a second time.
                log.info("message %s already sent, retrying ack only", uuid)
                self._ack(uuid, journaled["status"])
                continue
            log.info("sending message %s to %s", uuid, to)
            try:
                self.modem.send(to, content)
                status = "submitted"
            except gammu.GSMError as error:
                log.error("modem failed to send %s: %s", uuid, error)
                status = "failed"
                self.last_error = str(error)
                self.journal.record(uuid, status)
                self._ack(uuid, status)
                # The link looks dead: stop trying for this cycle and force
                # a fresh Init() next time instead of failing every
                # remaining message one by one.
                self.modem = None
                break
            self.journal.record(uuid, status)
            self._ack(uuid, status)
            # SIM modems are slow; pace outbound traffic.
            time.sleep(self.send_pause)

    def _retry_journal_acks(self):
        for uuid, entry in self.journal.pending():
            self._ack(uuid, entry["status"])

    def _ack(self, uuid, status):
        try:
            self.client.report_status(uuid, status)
        except requests.RequestException as error:
            # A failed ack must not abort the batch or the cycle; it will
            # be retried from the journal next time.
            log.error("failed to report status for %s, will retry later: %s", uuid, error)
            return
        self.journal.clear(uuid)

    def deliver_inbound(self):
        if self.modem is None:
            return
        for linked_message in self.modem.read_inbox():
            sender, text, received_at = Modem.decode(linked_message)
            if not text or not text.strip():
                # The app rejects blank text; forwarding it would just be a
                # wasted round trip. Log everything we know before the only
                # copy of this SMS disappears from the SIM.
                log.warning(
                    "received blank SMS from %s at %s (parts=%r); discarding",
                    sender,
                    received_at,
                    linked_message,
                )
                self.modem.delete(linked_message)
                continue
            modem_message_id = hashlib.sha256(
                f"{sender}|{received_at}|{text}".encode()
            ).hexdigest()[:32]
            log.info("received SMS from %s (id %s)", sender, modem_message_id)
            try:
                delivered = self.client.push_inbound(
                    sender, text, received_at, modem_message_id
                )
            except requests.RequestException as error:
                # One failing message must not block the rest of the inbox
                # or the outbound leg. Keep it on the SIM for next cycle.
                log.error("failed to push inbound SMS from %s, will retry: %s", sender, error)
                continue
            if delivered:
                self.modem.delete(linked_message)

    def _report_heartbeat(self):
        details = {"signal_percent": None, "network_state": None, "error": None}
        modem_ok = False
        if self.modem is not None and self.last_error is None:
            health = self.modem.health()
            if isinstance(health, str):
                self.last_error = health
            else:
                details["signal_percent"] = health["signal_percent"]
                details["network_state"] = health["network_state"]
                modem_ok = True
        if not modem_ok:
            details["error"] = self.last_error or "modem not initialized"
        try:
            self.client.report_heartbeat(modem_ok, details)
        except requests.RequestException as error:
            log.warning("failed to send heartbeat: %s", error)

    def _ping_healthcheck(self):
        """Optional external dead-man's switch (e.g. healthchecks.io)."""
        if not self.healthcheck_url:
            return
        try:
            requests.get(self.healthcheck_url, timeout=10)
        except Exception as error:  # noqa: BLE001 - this must never raise
            log.debug("healthcheck ping failed: %s", error)


def main():
    logging.basicConfig(
        level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s"
    )
    if len(sys.argv) != 2:
        print(f"usage: {sys.argv[0]} /etc/cm-sms-gateway.conf", file=sys.stderr)
        sys.exit(2)

    config = configparser.ConfigParser()
    if not config.read(sys.argv[1]):
        print(f"cannot read config file {sys.argv[1]}", file=sys.stderr)
        sys.exit(2)

    daemon = Daemon(config)
    signal.signal(signal.SIGTERM, daemon.stop)
    signal.signal(signal.SIGINT, daemon.stop)
    daemon.run()


if __name__ == "__main__":
    main()
