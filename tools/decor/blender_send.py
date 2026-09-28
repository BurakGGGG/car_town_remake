#!/usr/bin/env python3
"""Açık Blender oturumuna (blender-mcp eklentisi, 127.0.0.1:9876) Python kodu gönderir.

Kullanım:  python3 tools/decor/blender_send.py <script.py> [<script2.py> ...]
           python3 tools/decor/blender_send.py --kit <script.py>   # kit.py'yi başa ekler
           echo "kod" | python3 tools/decor/blender_send.py -

Eklenti her çağrıyı TEMİZ bir isim alanında çalıştırıyor: kit.py'deki yardımcılar bir sonraki
çağrıya taşınmıyor. Bu yüzden prop script'leri `--kit` ile gönderilir.

Eklenti eşzamanlı çalışır: gönderilen kod Blender'ın kendi yorumlayıcısında çalışır,
sonuç (stdout dahil) geri döner. Böylece modelleme kullanıcının ekranında CANLI görünür.
"""
import json
import os
import socket
import sys

HOST, PORT = "localhost", 9876


def call(message: dict, timeout: float = 120.0) -> dict:
    sock = socket.socket()
    sock.settimeout(timeout)
    sock.connect((HOST, PORT))
    sock.sendall(json.dumps(message).encode())
    buf = b""
    while True:
        chunk = sock.recv(65536)
        if not chunk:
            break
        buf += chunk
        try:
            return json.loads(buf.decode())
        except json.JSONDecodeError:
            continue
    sock.close()
    raise RuntimeError("Blender yanıtı çözülemedi")


def run_code(code: str) -> None:
    reply = call({"type": "execute_code", "params": {"code": code}})
    if reply.get("status") != "success":
        print("HATA:", json.dumps(reply, ensure_ascii=False)[:2000])
        sys.exit(1)
    out = str(reply.get("result", {}).get("result", "")).rstrip()
    if out:
        print(out)


if __name__ == "__main__":
    args = sys.argv[1:]
    prefix = ""
    if args and args[0] == "--kit":
        args = args[1:]
        kit = os.path.join(os.path.dirname(os.path.abspath(__file__)), "kit.py")
        prefix = open(kit, encoding="utf-8").read() + "\n"
    for target in (args or ["-"]):
        body = sys.stdin.read() if target == "-" else open(target, encoding="utf-8").read()
        run_code(prefix + body)
