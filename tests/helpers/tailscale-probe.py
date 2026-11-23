"""Exit 0 for an exact reply, 1 only for timeout/refusal, 2 for fixture errors."""

import socket
import sys
import uuid

protocol, source, destination = sys.argv[1:4]
port = int(sys.argv[4]) if len(sys.argv) == 5 else 8080
family = socket.AF_INET6 if ":" in destination else socket.AF_INET
kind = socket.SOCK_STREAM if protocol == "tcp" else socket.SOCK_DGRAM
payload = uuid.uuid4().hex.encode()
try:
    with socket.socket(family, kind) as sock:
        sock.settimeout(2)
        sock.bind((source, 0))
        sock.connect((destination, port))
        sock.sendall(payload)
        reply = sock.recv(4096)
        if reply != payload:
            raise RuntimeError(f"unexpected response: {reply!r}")
except (TimeoutError, ConnectionRefusedError):
    sys.exit(1)
except Exception as error:
    print(repr(error), file=sys.stderr)
    sys.exit(2)
