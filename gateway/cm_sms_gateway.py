#!/usr/bin/env python3
"""CM SMS gateway daemon.

Bridges a SIM modem (driven through gammu) and the court-message app:

  * polls the app to claim outbound messages queued on this gateway's
    phone line and sends them through the modem;
  * reads SMS received by the modem and pushes them to the app;
  * reports send outcomes back to the app, and delivery to the recipient's
    phone when the network sends a status report (see StatusPort);
  * reports modem health (signal, network state) through a heartbeat, and
    pings an optional external dead-man's switch;
  * never sends while the modem is not registered on a network, so the app
    routes new messages to the line's fallback instead;
  * notifies the systemd watchdog every cycle, so a hung modem call gets the
    daemon restarted;
  * asks for a USB reset of the modem when it cannot be opened anymore (see
    cm-modem-reset).

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
import socket
import sys
import termios
import time
from datetime import datetime, timedelta, timezone

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
# Watched by cm-modem-reset.path, which runs the (root) USB reset script.
DEFAULT_RESET_FLAG = "/run/cm-sms-gateway/modem-reset"
# Cycles run every ~10 s, but healthchecks.io asks for at most 5 pings per
# minute per check (and may block clients that ping more).
HEALTHCHECK_INTERVAL = 60
# Status reports normally come within seconds, but the service centre keeps
# retrying an unreachable phone for its validity period (a day by default).
# Past this, nobody waits for them anymore.
REPORT_WAIT = timedelta(days=3)

# gammu GetNetworkInfo() states in which the modem can send SMS.
REGISTERED_STATES = {"HomeNetwork", "RoamingNetwork"}


def sd_notify(message):
    """Minimal sd_notify(3), without the python3-systemd dependency. Does
    nothing when not run by systemd (NOTIFY_SOCKET unset)."""
    address = os.environ.get("NOTIFY_SOCKET")
    if not address:
        return
    if address.startswith("@"):
        address = "\0" + address[1:]
    try:
        with socket.socket(socket.AF_UNIX, socket.SOCK_DGRAM) as sock:
            sock.connect(address)
            sock.sendall(message.encode())
    except OSError as error:
        log.debug("sd_notify(%s) failed: %s", message, error)


def is_gsm_compatible(text):
    return all(char in GSM_BASIC or char in GSM_EXTENSION for char in text)


def parse_status_report(pdu_hex):
    """Decodes an SMS-STATUS-REPORT PDU (3GPP TS 23.040, 9.2.2.3), as listed
    by AT+CMGL in PDU mode. Returns {"reference", "number", "status"}; raises
    ValueError for anything else."""
    try:
        pdu = bytes.fromhex(pdu_hex)
        i = pdu[0] + 1  # service centre address
        first_octet = pdu[i]
        if first_octet & 0x03 != 0x02:
            raise ValueError(f"not a status report (first octet {first_octet:#04x})")
        reference = pdu[i + 1]
        digits, address_type = pdu[i + 2], pdu[i + 3]
        address_octets = (digits + 1) // 2
        i += 4
        semi_octets = pdu[i : i + address_octets].hex()
        number = "".join(semi_octets[k + 1] + semi_octets[k] for k in range(0, len(semi_octets), 2))
        number = number.rstrip("fF")
        if address_type & 0x70 == 0x10:  # international
            number = "+" + number
        i += address_octets + 7 + 7  # service centre time stamp, discharge time
        status = pdu[i]
    except (IndexError, ValueError) as error:
        raise ValueError(f"unreadable status report {pdu_hex!r}: {error}") from error
    return {"reference": reference, "number": number, "status": status}


def delivery_outcome(status):
    """The app status for a status report's TP-ST value, or None while the
    service centre is still trying (a final report follows)."""
    if status < 0x20:
        return "delivered"
    if status < 0x40:
        return None
    if status == 0x46:  # validity period expired
        return "expired"
    return "undeliverable"


class StatusPortError(Exception):
    pass


class StatusPort:
    """Status reports, read over the modem's second AT port.

    The network answers each SMS sent with a report request by an
    SMS-STATUS-REPORT. The EC25 files them in its own "SR" memory, which
    gammu never reads, and that memory holds only 5: they are read and
    deleted every cycle. gammu keeps the main port (/dev/modem-at); this one
    is only used between gammu calls, as the daemon is single-threaded.
    """

    def __init__(self, path, timeout=5):
        self.path = path
        self.timeout = timeout

    def enable(self):
        """Stores status reports in memory (CNMI <ds>=2). Lost when the modem
        restarts: called after every modem initialisation."""
        with self._open() as port:
            port.command("AT+CNMI=2,1,0,2,0")

    def drain(self, handler):
        """Calls handler(pdu_hex) for each stored report and deletes those
        for which it returns True."""
        with self._open() as port:
            port.command('AT+CPMS="SR","ME","ME"')
            try:
                port.command("AT+CMGF=0")
                lines = port.command("AT+CMGL=4")
                for index, pdu in self._listed(lines):
                    if handler(pdu):
                        port.command(f"AT+CMGD={index}")
            finally:
                # The preferred memory is the modem's, not this port's: put
                # back what gammu expects before it reads the inbox again.
                port.command('AT+CPMS="ME","ME","ME"')

    @staticmethod
    def _listed(lines):
        for k, line in enumerate(lines):
            if line.startswith("+CMGL:") and k + 1 < len(lines):
                yield int(line.split(":")[1].split(",")[0]), lines[k + 1]

    def _open(self):
        return _AtSession(self.path, self.timeout)


class _AtSession:
    def __init__(self, path, timeout):
        self.path = path
        self.timeout = timeout

    def __enter__(self):
        self.fd = os.open(self.path, os.O_RDWR | os.O_NOCTTY | os.O_NONBLOCK)
        attrs = termios.tcgetattr(self.fd)
        attrs[0] = attrs[1] = attrs[3] = 0
        attrs[2] = termios.CS8 | termios.CREAD | termios.CLOCAL
        attrs[4] = attrs[5] = termios.B115200
        termios.tcsetattr(self.fd, termios.TCSANOW, attrs)
        return self

    def __exit__(self, *_exc):
        os.close(self.fd)

    def command(self, command):
        """Sends one AT command; returns its response lines without the echo
        and the final OK. Raises StatusPortError on ERROR or timeout."""
        self._read_available()
        os.write(self.fd, (command + "\r").encode())
        deadline = time.monotonic() + self.timeout
        output = b""
        while time.monotonic() < deadline:
            output += self._read_available()
            lines = [line for line in output.decode(errors="replace").split("\r\n") if line]
            if lines and lines[-1] == "OK":
                return [line for line in lines[:-1] if line != command]
            if lines and "ERROR" in lines[-1]:
                raise StatusPortError(f"{command}: {lines[-1]}")
            time.sleep(0.05)
        raise StatusPortError(f"{command}: no answer within {self.timeout}s")

    def _read_available(self):
        data = b""
        while True:
            try:
                chunk = os.read(self.fd, 65536)
            except BlockingIOError:
                return data
            if not chunk:
                return data
            data += chunk


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

    def report_status(self, uuid, status, code=None):
        """code: the network's TP-ST value behind a final status, which says
        why a message was not delivered."""
        payload = {"status": status}
        if code is not None:
            payload["code"] = code
        response = self.session.patch(
            f"{self.base_url}/gateway/v1/messages/{uuid}",
            json=payload,
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
        """Returns True when the SMS can be removed from the SIM: the app has
        it, or refused this very SMS for good (400, 422). Raises (a
        RequestException) when it must stay on the SIM and be retried."""
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
        if response.status_code == 400:
            # The payload itself is invalid: retrying cannot help. Log it in
            # full before letting it go.
            log.error(
                "app rejected inbound SMS from %s as invalid (HTTP 400): %r",
                sender,
                text,
            )
            return True
        # Anything else says nothing about this SMS: a bad or rotated token
        # (401), an app without the gateway API or a wrong url (404),
        # throttling, server errors. Keep it on the SIM and retry next cycle
        # (deliver_inbound moves on to the next message meanwhile).
        response.raise_for_status()
        log.error("unexpected HTTP %s pushing inbound SMS from %s, keeping it", response.status_code, sender)
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

    def send(self, number, text, report=False):
        """Sends every part; returns the network's message reference for each
        (0-255, they wrap), which its status report will carry."""
        smsinfo = {
            "Class": -1,
            "Unicode": not is_gsm_compatible(text),
            "Entries": [{"ID": "ConcatenatedTextLong", "Buffer": text}],
        }
        references = []
        for part in gammu.EncodeSMS(smsinfo):
            part["SMSC"] = {"Location": 1}
            part["Number"] = number
            if report:
                # gammu's name for "status report requested" (TP-SRR).
                part["Type"] = "Status_Report"
            references.append(self.state_machine.SendSMS(part))
        return references

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

    def network_state(self):
        """gammu's registration state, e.g. "HomeNetwork" or "NoNetwork"."""
        return self.state_machine.GetNetworkInfo().get("State")

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
    def missing_parts(linked_message):
        """How many parts of a long (concatenated) SMS have not arrived yet;
        0 for a complete or single-part SMS."""
        udh = linked_message[0].get("UDH") or {}
        expected = udh.get("AllParts") or -1
        return max(expected - len(linked_message), 0)

    @staticmethod
    def decode(linked_message):
        """Returns (sender, text, received_at ISO 8601) for a linked group."""
        decoded = gammu.DecodeSMS(linked_message)
        text = ""
        if decoded is not None:
            text = "".join(
                entry["Buffer"] for entry in decoded["Entries"] if entry.get("Buffer")
            )
        if not text:
            # Not a multipart message, or one whose header gammu cannot turn
            # into text (e.g. a user-defined UDH): the raw parts still carry
            # it, and a blank result would get the SMS deleted unread.
            text = "".join(part.get("Text") or "" for part in linked_message)
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
        data = self._load()
        self.sent = dict(data.get("sent", {}))
        # Messages waiting for status reports: uuid -> {"refs": [...],
        # "at": ISO time sent, "results": {ref: outcome}}.
        self.awaiting = dict(data.get("awaiting", {}))

    def _load(self):
        try:
            with open(self.path, "r", encoding="utf-8") as handle:
                return json.load(handle)
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
        try:
            directory = os.path.dirname(self.path)
            if directory:
                os.makedirs(directory, exist_ok=True)
            tmp_path = f"{self.path}.tmp"
            with open(tmp_path, "w", encoding="utf-8") as handle:
                json.dump({"sent": self.sent, "awaiting": self.awaiting}, handle)
            os.replace(tmp_path, self.path)
        except OSError as error:
            # Full or read-only SD card. Crashing here, right after a send,
            # would skip its ack and get the SMS claimed and sent again: keep
            # the entry in memory and let the ack go through.
            log.error("could not save state file %s: %s", self.path, error)

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

    def await_reports(self, uuid, references):
        # Re-inserted at the end: entries stay in the order they were sent.
        self.awaiting.pop(uuid, None)
        self.awaiting[uuid] = {
            "refs": [str(reference) for reference in references],
            "at": datetime.now(timezone.utc).isoformat(),
            "results": {},
        }
        self._save()

    def record_report(self, reference, outcome, code=None):
        """Files a final outcome (and the network's code behind it) under the
        latest message sent with this reference (references wrap after 256
        parts). Returns its uuid, or None when nobody waits for it."""
        reference = str(reference)
        candidates = [
            uuid
            for uuid, entry in self.awaiting.items()
            if reference in entry["refs"] and reference not in entry["results"]
        ]
        if not candidates:
            return None
        uuid = candidates[-1]
        self.awaiting[uuid]["results"][reference] = outcome
        self.awaiting[uuid].setdefault("codes", {})[reference] = code
        self._save()
        return uuid

    def outcomes(self):
        """(uuid, status, code) for each message whose fate is known:
        delivered once every part is, or the first failure of any part. code
        is that part's network status (None in journals from before codes
        were kept)."""
        known = []
        for uuid, entry in self.awaiting.items():
            codes = entry.get("codes", {})
            failures = [ref for ref, result in entry["results"].items() if result != "delivered"]
            if failures:
                known.append((uuid, entry["results"][failures[0]], codes.get(failures[0])))
            elif len(entry["results"]) == len(entry["refs"]):
                known.append((uuid, "delivered", codes.get(entry["refs"][-1])))
        return known

    def finish(self, uuid):
        if self.awaiting.pop(uuid, None) is not None:
            self._save()

    def expire(self, older_than):
        expired = [
            uuid for uuid, entry in self.awaiting.items()
            if datetime.fromisoformat(entry["at"]) < older_than
        ]
        for uuid in expired:
            del self.awaiting[uuid]
        if expired:
            self._save()
        return expired


class Daemon:
    def __init__(self, config):
        app = config["app"]
        modem = config["modem"]
        self.poll_interval = app.getint("poll_interval", fallback=10)
        self.claim_limit = app.getint("claim_limit", fallback=5)
        self.send_pause = modem.getfloat("send_pause", fallback=2.0)
        self.multipart_grace = modem.getint("multipart_grace", fallback=600)
        self.incomplete_since = {}
        self.healthcheck_url = app.get("healthcheck_url", fallback=None)
        self.last_healthcheck_ping = None
        self.client = AppClient(app["url"], app["token"], app["line_phone"])
        self.gammu_config = modem.get("gammu_config", "/etc/gammurc")
        self.gammu_section = modem.getint("gammu_section", fallback=0)
        self.journal = Journal(app.get("state_file", fallback=DEFAULT_STATE_FILE))
        self.reset_flag = modem.get("reset_flag", fallback=DEFAULT_RESET_FLAG)
        self.reset_after_failures = modem.getint("reset_after_failures", fallback=3)
        self.init_failures = 0
        self.last_error = None
        self.registered = None
        status_port = modem.get("status_port", fallback=None)
        self.status_port = StatusPort(status_port) if status_port else None
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
            self.init_failures += 1
            if self.init_failures >= self.reset_after_failures:
                self._request_modem_reset()
                self.init_failures = 0
            return None
        log.info("modem ready")
        self.init_failures = 0
        self.last_error = None
        if self.status_port is not None:
            try:
                self.status_port.enable()
            except (StatusPortError, OSError) as error:
                # Sending still works; reports just won't be stored.
                log.warning("could not turn status reports on: %s", error)
        return modem

    def _request_modem_reset(self):
        """Asks the root-owned cm-modem-reset service to re-enumerate the
        modem on USB: after an electrical glitch the kernel may give up on
        the device for good, which no gammu Init() can recover from."""
        if not self.reset_flag:
            return
        try:
            with open(self.reset_flag, "w", encoding="utf-8") as handle:
                handle.write(datetime.now(timezone.utc).isoformat())
        except OSError as error:
            log.error("could not request a modem reset via %s: %s", self.reset_flag, error)
            return
        log.warning(
            "modem unreachable after %d attempts, requested a USB reset",
            self.reset_after_failures,
        )

    def _check_registration(self):
        """True when the modem is registered on a network. Sending without
        registration can block gammu indefinitely, and the app should route
        new messages to the fallback line meanwhile (it does so as soon as
        the heartbeat reports the modem unhealthy)."""
        state = self.modem.network_state()
        registered = state in REGISTERED_STATES
        if registered != self.registered:
            if registered:
                log.info("modem registered on the network (%s)", state)
            else:
                log.warning("modem not registered on the network (%s), not sending", state)
            self.registered = registered
        if not registered:
            self.last_error = f"not registered on the network ({state})"
        return registered

    def run(self):
        log.info("gateway started for line %s", self.client.line_phone)
        sd_notify("READY=1")
        while self.running:
            sd_notify("WATCHDOG=1")
            self.last_error = None
            cycle_ok = True
            try:
                if self.modem is None:
                    self.modem = self._ensure_modem()
                self.deliver_inbound()
                self.collect_reports()
                self.send_outbound()
            except (requests.RequestException, gammu.GSMError) as error:
                log.error("cycle failed, will retry: %s", error)
                cycle_ok = False
                if isinstance(error, gammu.GSMError):
                    # Looks like a dead link: force a fresh Init() next cycle,
                    # and log the registration state again once it is back.
                    self.last_error = str(error)
                    self.modem = None
                    self.registered = None
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
        if self.modem is None or not self._check_registration():
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
                references = self.modem.send(to, content, report=self.status_port is not None)
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
            if self.status_port is not None:
                self.journal.await_reports(uuid, references)
            self._ack(uuid, status)
            sd_notify("WATCHDOG=1")
            # SIM modems are slow; pace outbound traffic.
            time.sleep(self.send_pause)

    def collect_reports(self):
        """Files the status reports the network sent back, then tells the
        app the fate of each message known by now."""
        if self.status_port is None or self.modem is None:
            # No modem (e.g. off USB): its second port is gone too.
            return
        try:
            self.status_port.drain(self._file_report)
        except (StatusPortError, OSError) as error:
            # Never a reason to stop sending: the reports wait in the modem.
            log.warning("could not read status reports: %s", error)
        for uuid in self.journal.expire(datetime.now(timezone.utc) - REPORT_WAIT):
            log.info("no final status report for message %s, giving up", uuid)
        for uuid, status, code in self.journal.outcomes():
            if uuid in self.journal.sent:
                # "submitted" is not acknowledged yet: sent after this, it
                # would overwrite the final status.
                continue
            try:
                self.client.report_status(uuid, status, code=code)
            except requests.RequestException as error:
                log.error("failed to report %s for %s, will retry later: %s", status, uuid, error)
                continue
            if code is None:
                log.info("message %s %s", uuid, status)
            else:
                log.info("message %s %s (network status %#04x)", uuid, status, code)
            self.journal.finish(uuid)

    def _file_report(self, pdu):
        """Records one status report; True when it can leave the modem."""
        try:
            report = parse_status_report(pdu)
        except ValueError as error:
            log.warning("%s; deleting it", error)
            return True
        outcome = delivery_outcome(report["status"])
        if outcome is None:
            log.info(
                "network still trying reference %s (status %#04x)",
                report["reference"],
                report["status"],
            )
            return True
        uuid = self.journal.record_report(report["reference"], outcome, report["status"])
        if uuid is None:
            log.info(
                "status report for reference %s (%s) matches no message waiting for one",
                report["reference"],
                outcome,
            )
        return True

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
            if self._waiting_for_parts(linked_message):
                continue
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

    def _waiting_for_parts(self, linked_message):
        """True while a long SMS misses parts: they can arrive seconds apart,
        across two cycles, and pushing early would split the message. Held on
        the SIM for multipart_grace seconds at most, then forwarded as is (a
        part may never come)."""
        udh = linked_message[0].get("UDH") or {}
        key = (linked_message[0].get("Number"), udh.get("ID8bit"), udh.get("ID16bit"))
        missing = Modem.missing_parts(linked_message)
        if not missing:
            self.incomplete_since.pop(key, None)
            return False
        if key not in self.incomplete_since:
            self.incomplete_since[key] = time.monotonic()
            log.info("waiting for %d more part(s) of an SMS from %s", missing, key[0])
        if time.monotonic() - self.incomplete_since[key] < self.multipart_grace:
            return True
        log.warning(
            "forwarding an SMS from %s with %d part(s) still missing after %ds",
            key[0],
            missing,
            self.multipart_grace,
        )
        del self.incomplete_since[key]
        return False

    def _report_heartbeat(self):
        details = {"signal_percent": None, "network_state": None, "error": None}
        modem_ok = False
        if self.modem is not None:
            # Queried even after an error this cycle (e.g. not registered):
            # signal and network state are what tell a coverage problem from
            # a SIM or operator one.
            health = self.modem.health()
            if isinstance(health, str):
                self.last_error = self.last_error or health
            else:
                details["signal_percent"] = health["signal_percent"]
                details["network_state"] = health["network_state"]
                if self.last_error is None:
                    if health["network_state"] in REGISTERED_STATES:
                        modem_ok = True
                    else:
                        self.last_error = (
                            f"not registered on the network ({health['network_state']})"
                        )
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
        now = time.monotonic()
        if self.last_healthcheck_ping is not None and now - self.last_healthcheck_ping < HEALTHCHECK_INTERVAL:
            return
        self.last_healthcheck_ping = now
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
