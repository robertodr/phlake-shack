"""Isolated VM fixture: request/reply services, no Tailscale credentials."""

import socket
import socketserver
import threading

PAYLOAD_LIMIT = 4096


class TCP(socketserver.BaseRequestHandler):
    def handle(self):
        data = self.request.recv(PAYLOAD_LIMIT)
        self.request.sendall(data)


class UDP(socketserver.BaseRequestHandler):
    def handle(self):
        data, sock = self.request
        sock.sendto(data, self.client_address)


servers = []
for family, address in [(socket.AF_INET, "0.0.0.0"), (socket.AF_INET6, "::")]:
    for base, handler in [
        (socketserver.ThreadingTCPServer, TCP),
        (socketserver.ThreadingUDPServer, UDP),
    ]:

        class Server(base):
            address_family = family
            allow_reuse_address = True
            daemon_threads = True

            def server_bind(self):
                if self.address_family == socket.AF_INET6:
                    self.socket.setsockopt(socket.IPPROTO_IPV6, socket.IPV6_V6ONLY, 1)
                super().server_bind()

        for port in (8080, 41641) if handler is UDP else (8080,):
            instance = Server((address, port), handler)
            servers.append(instance)
            threading.Thread(target=instance.serve_forever, daemon=True).start()

threading.Event().wait()
