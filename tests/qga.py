#!/usr/bin/env python3
"""Cliente mínimo do QEMU Guest Agent: roda um comando dentro da VM e devolve a saída.

Uso:
  qga.py SOCKET ping                 # sai com 0 quando o agente responde
  qga.py SOCKET exec 'COMANDO' [TIMEOUT]
"""
import base64
import json
import socket
import sys
import time


def call(sock_path, cmd, args=None, timeout=10):
    s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    s.settimeout(timeout)
    s.connect(sock_path)
    f = s.makefile("rwb")
    # guest-sync descarta respostas antigas que ficaram no canal
    sync_id = int(time.time() * 1000) % 2**31
    f.write(json.dumps({"execute": "guest-sync", "arguments": {"id": sync_id}}).encode() + b"\n")
    f.flush()
    while json.loads(f.readline()).get("return") != sync_id:
        pass
    msg = {"execute": cmd}
    if args is not None:
        msg["arguments"] = args
    f.write(json.dumps(msg).encode() + b"\n")
    f.flush()
    resp = json.loads(f.readline())
    s.close()
    if "error" in resp:
        raise RuntimeError(resp["error"])
    return resp["return"]


def run(sock_path, command, timeout=60):
    pid = call(sock_path, "guest-exec", {
        "path": "/bin/sh", "arg": ["-c", command], "capture-output": True,
    })["pid"]
    deadline = time.time() + timeout
    while time.time() < deadline:
        st = call(sock_path, "guest-exec-status", {"pid": pid})
        if st.get("exited"):
            out = base64.b64decode(st.get("out-data", "")).decode(errors="replace")
            err = base64.b64decode(st.get("err-data", "")).decode(errors="replace")
            return st.get("exitcode", 1), out + err
        time.sleep(1)
    return 124, f"timeout depois de {timeout}s"


if __name__ == "__main__":
    sock_path, action = sys.argv[1], sys.argv[2]
    if action == "ping":
        try:
            call(sock_path, "guest-ping", timeout=3)
        except Exception:
            sys.exit(1)
        sys.exit(0)
    if action == "exec":
        code, out = run(sock_path, sys.argv[3], int(sys.argv[4]) if len(sys.argv) > 4 else 60)
        sys.stdout.write(out)
        sys.exit(code)
    sys.exit(f"ação desconhecida: {action}")
