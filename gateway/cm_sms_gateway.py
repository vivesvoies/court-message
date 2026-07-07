#!/usr/bin/env python3
"""CM SMS gateway daemon.

Bridges a SIM modem (driven through gammu) and the court-message app:

  * polls the app to claim outbound messages queued on this gateway's
    phone line and sends them through the modem;
  * reads SMS received by the modem and pushes them to the app;
  * reports send outcomes back to the app.

All communication is outbound HTTPS from this device to the app,
authenticated with a bearer token issued by `rake sms_gateway:provision`.
The device never listens on any port. Run one instance of this daemon per
SIM modem; multiple modems on the same device are handled by running the
daemon several times with different config files.

Dependencies (Raspberry Pi OS / Debian):
    sudo apt install python3-gammu python3-requests
"""

import configparser
import logging
import signal
import sys
import time

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
        response.raise_for_status()

    def push_inbound(self, sender, text, received_at):
        """Returns True when the app took ownership of the message (even if
        it rejected it as coming from an unknown contact), False when it
        should be retried later."""
        response = self.session.post(
            f"{self.base_url}/gateway/v1/inbound_messages",
            json={
                "from": sender,
                "to": self.line_phone,
                "text": text,
                "received_at": received_at,
            },
            timeout=self.timeout,
        )
        if response.status_code == 201:
            return True
        if response.status_code == 422:
            # Unknown sender: the app refuses it by design. Nothing to retry.
            log.warning("app rejected inbound SMS from %s (no matching contact)", sender)
            return True
        response.raise_for_status()
        return False


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


class Daemon:
    def __init__(self, config):
        app = config["app"]
        modem = config["modem"]
        self.poll_interval = app.getint("poll_interval", fallback=10)
        self.claim_limit = app.getint("claim_limit", fallback=5)
        self.send_pause = modem.getfloat("send_pause", fallback=2.0)
        self.client = AppClient(app["url"], app["token"], app["line_phone"])
        self.modem = Modem(
            modem.get("gammu_config", "/etc/gammurc"),
            modem.getint("gammu_section", fallback=0),
        )
        self.running = True

    def stop(self, *_args):
        log.info("stopping...")
        self.running = False

    def run(self):
        log.info("gateway started for line %s", self.client.line_phone)
        while self.running:
            try:
                self.deliver_inbound()
                self.send_outbound()
            except (requests.RequestException, gammu.GSMError) as error:
                log.error("cycle failed, will retry: %s", error)
            for _ in range(self.poll_interval):
                if not self.running:
                    break
                time.sleep(1)

    def send_outbound(self):
        messages = self.client.claim_messages(self.claim_limit)
        for message in messages:
            uuid, to, content = message["uuid"], message["to"], message["content"]
            log.info("sending message %s to %s", uuid, to)
            try:
                self.modem.send(to, content)
                status = "submitted"
            except gammu.GSMError as error:
                log.error("modem failed to send %s: %s", uuid, error)
                status = "failed"
            self.client.report_status(uuid, status)
            # SIM modems are slow; pace outbound traffic.
            time.sleep(self.send_pause)

    def deliver_inbound(self):
        for linked_message in self.modem.read_inbox():
            sender, text, received_at = Modem.decode(linked_message)
            log.info("received SMS from %s", sender)
            # Only remove the SMS from the SIM once the app owns it, so an
            # unreachable app never loses inbound messages.
            if self.client.push_inbound(sender, text, received_at):
                self.modem.delete(linked_message)


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
