#!/usr/bin/env python3

"""Small authenticated KORemote v1 server for simulator and integration tests."""

from __future__ import annotations

import argparse
import base64
import binascii
import hashlib
import hmac
import json
from collections import deque
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from socketserver import TCPServer
from threading import Lock


class MockServer(ThreadingHTTPServer):
    allow_reuse_address = True
    daemon_threads = True

    secret: bytes
    event_path: Path
    nonces: set[str]
    nonce_order: deque[str]
    state_lock: Lock

    def server_bind(self) -> None:
        # HTTPServer performs a reverse-DNS lookup here, which can block startup
        # on isolated CI hosts. The display name is irrelevant to this mock.
        TCPServer.server_bind(self)
        self.server_name = self.server_address[0]
        self.server_port = self.server_address[1]


class RequestHandler(BaseHTTPRequestHandler):
    server: MockServer

    def do_GET(self) -> None:
        self._respond(200, {"ok": True, "message": "mock ready"})

    def do_POST(self) -> None:
        try:
            length = int(self.headers.get("Content-Length", "0"))
            if length <= 0:
                self._respond(400, {"ok": False, "message": "invalid body"})
                return
            if length > 4_096:
                self._respond(413, {"ok": False, "message": "content too large"})
                return
            payload = json.loads(self.rfile.read(length))
            if not isinstance(payload, dict):
                raise TypeError("request must be an object")
            version = payload["version"]
            action = payload["action"]
            nonce = payload["nonce"]
            supplied_mac = payload["mac"]
        except (KeyError, TypeError, ValueError, json.JSONDecodeError):
            self._respond(400, {"ok": False, "message": "invalid request"})
            return

        if self.path == "/v1/ping":
            allowed_actions = {"ping"}
        elif self.path == "/v1/action":
            allowed_actions = {"next", "previous", "sleep"}
        else:
            self._respond(404, {"ok": False, "message": "invalid path"})
            return

        if (
            type(version) is not int
            or version != 1
            or not isinstance(action, str)
            or not isinstance(nonce, str)
            or not 16 <= len(nonce) <= 128
            or not isinstance(supplied_mac, str)
            or len(supplied_mac) != 64
        ):
            self._respond(400, {"ok": False, "message": "invalid protocol"})
            return
        if action not in allowed_actions:
            self._respond(400, {"ok": False, "message": "invalid action path"})
            return

        canonical = f"version={version}\naction={action}\nnonce={nonce}".encode()
        expected_mac = hmac.new(self.server.secret, canonical, hashlib.sha256).hexdigest()
        if not hmac.compare_digest(expected_mac, str(supplied_mac)):
            self._respond(401, {"ok": False, "message": "authentication failed"})
            return

        with self.server.state_lock:
            if nonce in self.server.nonces:
                self._respond(409, {"ok": False, "message": "replay rejected"})
                return
            if len(self.server.nonce_order) == 128:
                self.server.nonces.discard(self.server.nonce_order.popleft())
            self.server.nonce_order.append(nonce)
            self.server.nonces.add(nonce)
            try:
                with self.server.event_path.open("a", encoding="utf-8") as events:
                    events.write(json.dumps({"path": self.path, "action": action, "nonce": nonce}) + "\n")
            except OSError:
                self._respond(500, {"ok": False, "message": "event log unavailable"})
                return

        self._respond(200, {"ok": True, "message": "mock accepted"})

    def log_message(self, _format: str, *_args: object) -> None:
        return

    def _respond(self, status: int, payload: dict[str, object]) -> None:
        body = json.dumps(payload).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)


def decode_secret(value: str) -> bytes:
    padding = "=" * ((4 - len(value) % 4) % 4)
    try:
        secret = base64.b64decode(value + padding, altchars=b"-_", validate=True)
    except (binascii.Error, ValueError) as error:
        raise argparse.ArgumentTypeError("secret must be URL-safe base64") from error
    if len(secret) != 32:
        raise argparse.ArgumentTypeError("secret must decode to exactly 32 bytes")
    return secret


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=19090)
    parser.add_argument("--secret", type=decode_secret, required=True)
    parser.add_argument("--events", type=Path, required=True)
    args = parser.parse_args()

    args.events.parent.mkdir(parents=True, exist_ok=True)
    args.events.touch()
    server = MockServer((args.host, args.port), RequestHandler)
    server.secret = args.secret
    server.event_path = args.events
    server.nonces = set()
    server.nonce_order = deque()
    server.state_lock = Lock()
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()


if __name__ == "__main__":
    main()
