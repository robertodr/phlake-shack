"""Offline LSP lifecycle test for the configured, Nix-built language servers."""
import json
import os
from pathlib import Path
import signal
import subprocess
import tempfile


def smoke(kind, command, workspace, language, text):
    with tempfile.TemporaryFile() as errors:
        process = subprocess.Popen(
            command, stdin=subprocess.PIPE, stdout=subprocess.PIPE,
            stderr=errors, start_new_session=True,
        )

        def send(message):
            body = json.dumps({"jsonrpc": "2.0", **message}).encode()
            process.stdin.write(f"Content-Length: {len(body)}\r\n\r\n".encode() + body)
            process.stdin.flush()

        def response(request_id):
            while True:
                headers = {}
                while True:
                    line = process.stdout.readline()
                    if not line:
                        raise RuntimeError(f"{kind} exited before replying")
                    if line in (b"\r\n", b"\n"):
                        break
                    key, value = line.decode().split(":", 1)
                    headers[key.lower()] = value.strip()
                length = int(headers["content-length"])
                if not 0 < length <= 16 * 1024 * 1024:
                    raise RuntimeError(f"{kind} sent an invalid message length")
                body = process.stdout.read(length)
                message = json.loads(body)
                if "method" in message and "id" in message:
                    # No editor-provided configuration or client extensions.
                    result = [] if message["method"] == "workspace/configuration" else None
                    send({"id": message["id"], "result": result})
                elif message.get("id") == request_id:
                    assert "error" not in message, message
                    return message.get("result")

        signal.alarm(45)
        try:
            send({"id": 1, "method": "initialize", "params": {
                "processId": os.getpid(), "rootUri": workspace.as_uri(),
                "workspaceFolders": [{"uri": workspace.as_uri(), "name": "smoke"}],
                "capabilities": {},
                "initializationOptions": {"exportPdf": "never", "compileStatus": "disable"}
                if kind == "tinymist" else {},
            }})
            initialized = response(1)
            assert isinstance(initialized.get("capabilities"), dict), initialized
            send({"method": "initialized", "params": {}})
            document = workspace / ("main.typ" if kind == "tinymist" else "main.tex")
            document.write_text(text)
            send({"method": "textDocument/didOpen", "params": {"textDocument": {
                "uri": document.as_uri(), "languageId": language, "version": 1, "text": text,
            }}})
            send({"id": 2, "method": "textDocument/documentSymbol", "params": {
                "textDocument": {"uri": document.as_uri()},
            }})
            response(2)
            send({"id": 3, "method": "shutdown", "params": None})
            response(3)
            send({"method": "exit"})
            process.wait(timeout=10)
            assert process.returncode == 0, process.returncode
            print(f"{kind}: initialize, document symbols, shutdown passed")
        except BaseException:
            errors.seek(0)
            print(errors.read().decode(errors="replace"))
            raise
        finally:
            signal.alarm(0)
            if process.poll() is None:
                os.killpg(process.pid, signal.SIGKILL)
                process.wait()


def timed_out(_signal, _frame):
    raise TimeoutError("language server did not respond within 45 seconds")


signal.signal(signal.SIGALRM, timed_out)
for kind, argument, language, text in [
    ("texlab", "run", "latex", "\\documentclass{article}\n\\begin{document}\n\\end{document}\n"),
    ("tinymist", "lsp", "typst", "#rect(width: 10pt, height: 10pt)\n"),
]:
    workspace = Path.cwd() / kind
    workspace.mkdir()
    smoke(kind, [os.environ[f"OLEAFLY_{kind.upper()}"], argument], workspace, language, text)
