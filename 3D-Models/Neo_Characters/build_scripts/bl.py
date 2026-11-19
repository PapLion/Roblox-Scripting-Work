#!/usr/bin/env python3
"""Tiny client for the BlenderMCP addon socket (127.0.0.1:9876).
Usage: bl.py file.py           -> execute_code with file contents
       bl.py --cmd TYPE [json] -> arbitrary command
"""
import json, socket, sys

def send(cmd, timeout=600):
    s = socket.create_connection(("127.0.0.1", 9876), timeout=timeout)
    s.sendall(json.dumps(cmd).encode())
    buf = b""
    while True:
        chunk = s.recv(65536)
        if not chunk:
            break
        buf += chunk
        try:
            res = json.loads(buf.decode())
            break
        except (ValueError, UnicodeDecodeError):
            continue
    s.close()
    return res

if __name__ == "__main__":
    if sys.argv[1] == "--cmd":
        params = json.loads(sys.argv[3]) if len(sys.argv) > 3 else {}
        r = send({"type": sys.argv[2], "params": params})
    else:
        code = open(sys.argv[1]).read()
        r = send({"type": "execute_code", "params": {"code": code}})
    if r.get("status") == "error":
        msg = r.get("message", "")
        try:
            d = json.loads(msg)
            print("ERROR:", d.get("message")); print(d.get("traceback"))
        except Exception:
            print("ERROR:", msg)
        sys.exit(1)
    res = r.get("result")
    if isinstance(res, dict) and "result" in res:
        print(res["result"])
    else:
        print(json.dumps(res, indent=1)[:4000])
