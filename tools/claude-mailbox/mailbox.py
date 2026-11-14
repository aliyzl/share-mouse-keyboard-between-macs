#!/usr/bin/env python3
"""A tiny LAN mailbox so Claude Code sessions on two machines can talk to each other.

Usage:
  mailbox.py --host <this-machine-lan-ip> [--port 8765] [--token TOKEN] [--log messages.jsonl]

API (every call except the viewer needs the header  X-Token: <token>):
  POST /msg?from=<name>    body = message text (UTF-8, at most 64 KiB)   -> {"id": N}
  GET  /msgs?since=<id>                                                -> [{"id","from","ts","text"}, ...]
  GET  /#<token>           a read-only web page that shows the conversation live

Standard library only. Bind it to the LAN address, not 0.0.0.0, and stop it when the work is done:
the token keeps out other devices on the network, but traffic is plain HTTP.
"""
import argparse
import json
import secrets
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import parse_qs, urlparse

MAX_BODY = 64 * 1024
VIEWER = Path(__file__).with_name("viewer.html")


def make_handler(token, log_path, messages, lock):
    class Handler(BaseHTTPRequestHandler):
        def _reply(self, code, obj):
            body = json.dumps(obj, ensure_ascii=False).encode()
            self.send_response(code)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

        def _authorized(self):
            if not secrets.compare_digest(self.headers.get("X-Token", ""), token):
                self._reply(401, {"error": "bad token"})
                return False
            return True

        def do_GET(self):
            url = urlparse(self.path)
            if url.path == "/":  # static page; it reads the token from the URL fragment
                body = VIEWER.read_bytes()
                self.send_response(200)
                self.send_header("Content-Type", "text/html; charset=utf-8")
                self.send_header("Content-Length", str(len(body)))
                self.end_headers()
                self.wfile.write(body)
                return
            if not self._authorized():
                return
            if url.path != "/msgs":
                return self._reply(404, {"error": "use GET /msgs?since=N"})
            try:
                since = int(parse_qs(url.query).get("since", ["0"])[0])
            except ValueError:
                return self._reply(400, {"error": "since must be an integer"})
            with lock:
                self._reply(200, [m for m in messages if m["id"] > since])

        def do_POST(self):
            if not self._authorized():
                return
            url = urlparse(self.path)
            if url.path != "/msg":
                return self._reply(404, {"error": "use POST /msg?from=NAME"})
            try:
                length = int(self.headers.get("Content-Length", 0))
            except ValueError:
                length = -1
            if length <= 0 or length > MAX_BODY:
                return self._reply(400, {"error": f"body must be 1..{MAX_BODY} bytes"})
            sender = parse_qs(url.query).get("from", ["unknown"])[0][:32]
            text = self.rfile.read(length).decode("utf-8", errors="replace")
            with lock:
                msg = {"id": len(messages) + 1, "from": sender,
                       "ts": time.strftime("%H:%M:%S"), "text": text}
                messages.append(msg)
                with log_path.open("a") as f:
                    f.write(json.dumps(msg, ensure_ascii=False) + "\n")
            self._reply(200, {"id": msg["id"]})

        def log_message(self, *args):
            pass

    return Handler


def main():
    p = argparse.ArgumentParser(description="LAN mailbox for two Claude Code sessions")
    p.add_argument("--host", required=True, help="the LAN address to listen on")
    p.add_argument("--port", type=int, default=8765)
    p.add_argument("--token", default=None, help="shared secret (default: a new random one)")
    p.add_argument("--log", default="messages.jsonl", help="where messages are kept")
    a = p.parse_args()

    token = a.token or secrets.token_hex(8)
    log_path = Path(a.log)
    lines = log_path.read_text().splitlines() if log_path.exists() else []
    messages = [json.loads(l) for l in lines if l.strip()]
    server = ThreadingHTTPServer((a.host, a.port), make_handler(token, log_path, messages, threading.Lock()))
    print(f"mailbox on http://{a.host}:{a.port}  token {token}", flush=True)
    print(f"viewer:  http://{a.host}:{a.port}/#{token}", flush=True)
    server.serve_forever()


if __name__ == "__main__":
    main()
