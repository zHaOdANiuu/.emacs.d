#!/usr/bin/env python3
import argparse
import base64
import hashlib
import http.server
import html
import mimetypes
import pathlib
import socketserver
import threading
import time
import urllib.parse

WEBSOCKET_GUID = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"
LIVE_RELOAD_SCRIPT = """<script>
(() => {
    function connect() {
        const socket = new WebSocket(
            "ws://" + location.host + "/__live_reload"
        );
        socket.onmessage = () => location.reload();
        socket.onclose = () => setTimeout(connect, 250);
    }
    connect();
})();
</script>"""

class State:
    def __init__(self, root):
        self.root = pathlib.Path(root).resolve()
        self.clients = set()
        self.lock = threading.Lock()
        self.snapshot = {}

    def scan(self):
        files = {}
        for path in self.root.rglob("*"):
            if path.is_file():
                try:
                    files[str(path)] = path.stat().st_mtime_ns
                except OSError:
                    pass
        return files

    def broadcast(self):
        with self.lock:
            clients = list(self.clients)
        for client in clients:
            try:
                client.sendall(bytes((0x81, 6)) + b"reload")
            except OSError:
                with self.lock:
                    self.clients.discard(client)

    def watch(self):
        self.snapshot = self.scan()
        while True:
            time.sleep(0.25)
            current = self.scan()
            changed = {
                path for path in set(current) | set(self.snapshot)
                if current.get(path) != self.snapshot.get(path)
            }
            if changed:
                self.snapshot = current
                for path in sorted(changed):
                    print(f"Changed: {path}", flush=True)
                self.broadcast()

class Handler(http.server.BaseHTTPRequestHandler):
    server_version = "LiveServer/1.0"

    def directory_listing(self, directory, request_path):
        """Return a simple HTML directory listing."""
        entries = []
        base = request_path.rstrip("/") + "/"
        for entry in sorted(
            directory.iterdir(), key=lambda item: item.name.lower()
        ):
            name = entry.name + ("/" if entry.is_dir() else "")
            href = urllib.parse.quote(base + entry.name)
            entries.append(
                f'<li><a href="{html.escape(href)}">'
                f'{html.escape(name)}</a></li>'
            )
        title = html.escape("Index of " + request_path)
        return (
            "<!doctype html><meta charset=\"utf-8\">"
            f"<title>{title}</title><h1>{title}</h1><ul>"
            + "".join(entries)
            + "</ul>"
        ).encode("utf-8")

    def log_message(self, _fmt, *_args):
        """Suppress BaseHTTPRequestHandler access logs."""
        return

    def do_GET(self):
        if self.headers.get("Upgrade", "").lower() == "websocket":
            return self.websocket()
        root = self.server.state.root
        url_path = urllib.parse.urlsplit(self.path).path
        path = pathlib.Path(urllib.parse.unquote(url_path).lstrip("/"))
        target = (root / path).resolve()
        if target != root and root not in target.parents:
            self.send_error(403)
        if target.is_dir():
            data = self.directory_listing(target, url_path)
            content_type = "text/html; charset=utf-8"
            self.send_response(200)
            self.send_header("Content-Type", content_type)
            self.send_header("Content-Length", str(len(data)))
            self.end_headers()
            self.wfile.write(data)
            return
        if target.is_file():
            try:
                data = target.read_bytes()
            except OSError:
                self.send_error(404)
                return
            content_type = (
                mimetypes.guess_type(str(target))[0]
                or "application/octet-stream"
            )
            if content_type == "text/html":
                text = data.decode("utf-8", "replace")
                if "</body>" in text:
                    text = text.replace(
                        "</body>", LIVE_RELOAD_SCRIPT + "</body>", 1
                    )
                else:
                    text += LIVE_RELOAD_SCRIPT
                data = text.encode("utf-8")
                content_type = "text/html; charset=utf-8"
            self.send_response(200)
            self.send_header("Content-Type", content_type)
            self.send_header("Content-Length", str(len(data)))
            self.end_headers()
            self.wfile.write(data)
        else:
            self.send_error(404)

    def websocket(self):
        key = self.headers.get("Sec-WebSocket-Key", "")
        accept = base64.b64encode(
            hashlib.sha1((key + WEBSOCKET_GUID).encode()).digest()
        ).decode()
        self.send_response(101, "Switching Protocols")
        self.send_header("Upgrade", "websocket")
        self.send_header("Connection", "Upgrade")
        self.send_header("Sec-WebSocket-Accept", accept)
        self.end_headers()
        self.wfile.flush()
        sock = self.connection
        self.server.state.clients.add(sock)
        try:
            while sock.recv(2):
                continue
        except (ConnectionError, TimeoutError, OSError) as error:
            self.log_message("WebSocket closed: %s", error)
        finally:
            self.server.state.clients.discard(sock)

class Server(socketserver.ThreadingMixIn, http.server.HTTPServer):
    daemon_threads = True
    allow_reuse_address = True

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", required=True)
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=5500)
    args = parser.parse_args()
    server = Server((args.host, args.port), Handler)
    server.state = State(args.root)
    print(f"Live Server: {server.state.root}", flush=True)
    print(f"Live Server: http://{args.host}:{args.port}/", flush=True)
    threading.Thread(target=server.state.watch, daemon=True).start()
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("Live Server stopped", flush=True)
    finally:
        server.server_close()

if __name__ == "__main__":
    main()
