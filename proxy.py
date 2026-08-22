#!/usr/bin/env python3
"""
Simple CORS proxy untuk Flutter Web development.
Forward semua request dari localhost:9001 → 103.236.140.19:9001
Jalankan: python3 proxy.py
"""
import http.server
import urllib.request
import urllib.error

BACKEND = "http://103.236.140.19:9001"

class ProxyHandler(http.server.BaseHTTPRequestHandler):
    def log_message(self, format, *args):
        print(f"[Proxy] {args[0]} {args[1]}")

    def _send_cors_headers(self):
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS, PATCH")
        self.send_header("Access-Control-Allow-Headers", "Content-Type, Authorization, Accept, Accept-Encoding, Connection, Cache-Control, X-Requested-With")
        self.send_header("Access-Control-Allow-Credentials", "true")

    def do_OPTIONS(self):
        self.send_response(204)
        self._send_cors_headers()
        self.end_headers()

    def _proxy(self, method):
        target = BACKEND + self.path
        length = int(self.headers.get("Content-Length", 0))
        body = self.rfile.read(length) if length else None

        # Forward headers (skip hop-by-hop)
        fwd_headers = {}
        skip = {"host", "connection", "accept-encoding", "transfer-encoding"}
        for k, v in self.headers.items():
            if k.lower() not in skip:
                fwd_headers[k] = v

        try:
            req = urllib.request.Request(target, data=body, headers=fwd_headers, method=method)
            with urllib.request.urlopen(req, timeout=15) as resp:
                self.send_response(resp.status)
                # Forward response headers
                for k, v in resp.headers.items():
                    if k.lower() not in {"transfer-encoding", "connection"}:
                        self.send_header(k, v)
                self._send_cors_headers()
                self.end_headers()
                self.wfile.write(resp.read())
        except urllib.error.HTTPError as e:
            self.send_response(e.code)
            self._send_cors_headers()
            self.end_headers()
            self.wfile.write(e.read())
        except Exception as e:
            print(f"[Proxy ERROR] {e}")
            self.send_response(502)
            self._send_cors_headers()
            self.end_headers()
            self.wfile.write(str(e).encode())

    def do_GET(self): self._proxy("GET")
    def do_POST(self): self._proxy("POST")
    def do_PUT(self): self._proxy("PUT")
    def do_DELETE(self): self._proxy("DELETE")
    def do_PATCH(self): self._proxy("PATCH")

if __name__ == "__main__":
    PORT = 9001
    print(f"🚀 CORS Proxy berjalan di http://localhost:{PORT}")
    print(f"   Forwarding → {BACKEND}")
    print(f"   Flutter web sekarang bisa akses backend via localhost:9001")
    httpd = http.server.HTTPServer(("127.0.0.1", PORT), ProxyHandler)
    httpd.serve_forever()
