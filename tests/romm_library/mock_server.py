#!/usr/bin/env python3
"""RomM de mentira para testar o app RomM Library (nao e o RomM de verdade).

Reproduz o que o app usa da API:  /api/heartbeat, /api/platforms, /api/roms (paginado),
/api/roms/{id}/content/{arquivo}, /api/roms/download, /api/romsfiles/{id}/content/{arquivo}, /api/token.

Modos (--mode):
  modern     envelope {items,total,limit,offset,char_index}; todas as rotas de download
  legacy     /api/roms devolve um array simples (sem paginacao no servidor)
  bulkonly   como modern, mas /api/roms/{id}/content/... responde 404 (so /api/roms/download funciona)
  filesonly  como modern, mas so /api/romsfiles/... baixa
  basicfail  Basic recusado (401); so Bearer/OAuth funciona
Opcoes: --flaky  derruba a conexao na metade da 1a tentativa do ROM id 3 (testa retomada)
        --norange  ignora cabecalho Range (testa recomeco do zero)
"""
import argparse, base64, hashlib, io, json, os, sys, threading, time, zipfile
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlparse, parse_qs, unquote

TOKEN = "rmm_" + "ab12" * 16
USER, PASSWORD = "pedro", 'p@ss"w\\ord:1'

def blob(seed, size):
    out, h = bytearray(), hashlib.sha256(seed.encode()).digest()
    while len(out) < size:
        h = hashlib.sha256(h).digest()
        out += h
    return bytes(out[:size])

PLATFORMS = [
    dict(id=1, slug="gba", fs_slug="gba", name="Game Boy Advance", display_name="Game Boy Advance"),
    dict(id=2, slug="arcade", fs_slug="arcade", name="Arcade", display_name="Arcade"),
    dict(id=3, slug="psx", fs_slug="psx", name="PlayStation", display_name="PlayStation"),
    dict(id=4, slug="ngc", fs_slug="ngc", name="Nintendo GameCube", display_name="Nintendo GameCube"),
    dict(id=5, slug="vazia", fs_slug="vazia", name="Vazia", display_name="Vazia"),
]

ROMS = []
def add(pid, name, fs_name, size, multi=False, files=None, regions=None):
    rid = len(ROMS) + 1
    pl = next(p for p in PLATFORMS if p["id"] == pid)
    ROMS.append(dict(
        id=rid, name=name, fs_name=fs_name, fs_name_no_ext=os.path.splitext(fs_name)[0],
        fs_size_bytes=size, has_multiple_files=multi, regions=regions or ["USA"],
        files=files if files is not None else [dict(id=1000 + rid, file_name=fs_name, file_size_bytes=size)],
        platform_id=pid, platform_slug=pl["slug"], platform_fs_slug=pl["fs_slug"],
        platform_display_name=pl["display_name"]))

# ids 1..3: casos especiais de nome (id 3 e' o que a opcao --flaky derruba)
add(1, "Advançe: Emerald & Co.", "Advançe: Emerald & Co. (USA).gba", 200_000)
add(1, 'Boss/Link? "Minish" <Cap>', 'Boss/Link? "Minish" <Cap> (USA).gba', 150_000)
add(1, "Big Flaky Adventure", "Big Flaky Adventure.gba", 600_000)
for i in range(4, 80):
    add(1, f"Game {i:02d}", f"Game {i:02d}.gba", 40_000 + i)
add(2, "Metal Slug", "mslug.zip", 90_000)
add(2, "Zed Fighters", "zedfight.zip", 90_000, regions=["WORLD"])
# PS1 multi-arquivo: o servidor entrega um ZIP com uma pasta contendo .cue + .bin
add(3, "Crash Test (PS1)", "Crash Test (PS1)", 500_000, multi=True,
    files=[dict(id=7001, file_name="Crash Test (PS1).cue", file_size_bytes=100),
           dict(id=7002, file_name="Crash Test (PS1).bin", file_size_bytes=499_900)])
add(4, "Gamecube Thing", "gc.iso", 70_000)

PLATFORM_COUNTS = {}
for r in ROMS:
    PLATFORM_COUNTS[r["platform_id"]] = PLATFORM_COUNTS.get(r["platform_id"], 0) + 1

def rom_bytes(r):
    return blob(r["fs_name"], r["fs_size_bytes"])

def rom_zip(r):
    buf = io.BytesIO()
    with zipfile.ZipFile(buf, "w", zipfile.ZIP_STORED) as z:
        if r["has_multiple_files"]:
            base = r["fs_name"]
            z.writestr(f"{base}/{base}.cue", b'FILE "x.bin" BINARY\n')
            z.writestr(f"{base}/{base}.bin", blob(base, r["fs_size_bytes"] - 100))
        else:
            z.writestr(r["fs_name"], rom_bytes(r))
    return buf.getvalue()

class Handler(BaseHTTPRequestHandler):
    server_version = "MockRomM/0"
    def log_message(self, *a): pass

    def record(self, code, note=""):
        with open(self.server.reqlog, "a") as f:
            f.write(f"{self.command} {self.path} -> {code} auth={self.auth_kind()} {note}\n")

    def auth_kind(self):
        h = self.headers.get("Authorization", "")
        if h.startswith("Bearer "): return "bearer"
        if h.startswith("Basic "): return "basic"
        return "none"

    def authed(self):
        h = self.headers.get("Authorization", "")
        if h == f"Bearer {TOKEN}": return True
        if h == "Bearer oauth-session-token": return True
        if h.startswith("Basic ") and self.server.mode != "basicfail":
            try:
                u, _, p = base64.b64decode(h[6:]).decode().partition(":")
                return u == USER and p == PASSWORD
            except Exception:
                return False
        return False

    def send_json(self, obj, code=200):
        body = json.dumps(obj).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)
        self.record(code)

    def deny(self, code, msg="x"):
        self.send_json({"detail": msg}, code)

    def do_POST(self):
        n = int(self.headers.get("Content-Length", 0))
        form = parse_qs(self.rfile.read(n).decode())
        if self.path == "/api/token":
            ok = form.get("username", [""])[0] == USER and form.get("password", [""])[0] == PASSWORD
            if ok:
                return self.send_json({"access_token": "oauth-session-token", "token_type": "bearer"})
            return self.deny(401, "bad credentials")
        self.deny(404)

    def do_GET(self):
        u = urlparse(self.path)
        q = {k: v[0] for k, v in parse_qs(u.query).items()}
        p = u.path
        if p == "/api/heartbeat":
            return self.send_json({"SYSTEM": {"VERSION": "4.9.2-mock", "SHOW_SETUP_WIZARD": False}})
        if not p.startswith("/api/"):
            return self.deny(404)
        if not self.authed():
            return self.deny(401, "unauthorized")
        if p == "/api/platforms":
            return self.send_json([dict(pl, rom_count=PLATFORM_COUNTS.get(pl["id"], 0)) for pl in PLATFORMS])
        if p == "/api/roms":
            return self.list_roms(q)
        parts = p.split("/")
        # /api/roms/download
        if p == "/api/roms/download":
            if self.server.mode == "filesonly":
                return self.deny(404, "no such route")
            ids = [int(x) for x in q.get("rom_ids", "").split(",") if x]
            return self.send_blob(rom_zip(ROMS[ids[0] - 1]), "bulk")
        # /api/roms/{id}/content/{name}
        if len(parts) >= 6 and parts[2] == "roms" and parts[4] == "content":
            if self.server.mode in ("bulkonly", "filesonly"):
                return self.deny(404, "no such route")
            r = ROMS[int(parts[3]) - 1]
            name = unquote("/".join(parts[5:]))
            if name != r["fs_name"]:
                return self.deny(404, f"name mismatch: {name!r}")
            data = rom_zip(r) if r["has_multiple_files"] else rom_bytes(r)
            return self.send_blob(data, f"content id={r['id']}", flaky=(r["id"] == 3))
        # /api/romsfiles/{fid}/content/{name}
        if len(parts) >= 6 and parts[2] == "romsfiles" and parts[4] == "content":
            if self.server.mode == "bulkonly":
                return self.deny(404)
            fid = int(parts[3])
            r = next((x for x in ROMS if any(f["id"] == fid for f in x["files"])), None)
            if not r: return self.deny(404)
            return self.send_blob(rom_bytes(r), f"romsfiles fid={fid}")
        self.deny(404)

    def list_roms(self, q):
        items = sorted(ROMS, key=lambda r: r["name"].lower())
        pid = q.get("platform_ids") or q.get("platform_id")
        if pid: items = [r for r in items if str(r["platform_id"]) == pid]
        term = q.get("search_term")
        if term: items = [r for r in items if term.lower() in r["name"].lower()]
        if self.server.mode == "legacy":
            return self.send_json(items)
        limit, offset = int(q.get("limit", 50)), int(q.get("offset", 0))
        char_index, seen = {}, set()
        for i, r in enumerate(items):
            c = r["name"][0].upper()
            c = c if c.isalpha() and c.isascii() else "#"
            if c not in seen:
                seen.add(c); char_index[c] = i
        self.send_json(dict(items=items[offset:offset + limit], total=len(items), limit=limit,
                            offset=offset, char_index=char_index, rom_id_index=[r["id"] for r in items]))

    def send_blob(self, data, note, flaky=False):
        start, code = 0, 200
        rng = self.headers.get("Range")
        if rng and not self.server.norange and rng.startswith("bytes="):
            start = int(rng[6:].split("-")[0] or 0)
            if start >= len(data):
                self.send_response(416); self.send_header("Content-Range", f"bytes */{len(data)}")
                self.send_header("Content-Length", "0"); self.end_headers()
                return self.record(416, note)
            code = 206
        chunk = data[start:]
        self.send_response(code)
        self.send_header("Content-Type", "application/octet-stream")
        self.send_header("Content-Length", str(len(chunk)))
        if code == 206:
            self.send_header("Content-Range", f"bytes {start}-{len(data) - 1}/{len(data)}")
        self.send_header("Accept-Ranges", "bytes")
        self.end_headers()
        if flaky and self.server.flaky and not self.server.flaky_done:
            self.server.flaky_done = True
            self.wfile.write(chunk[: len(chunk) // 2])
            self.wfile.flush()
            self.connection.close()
            return self.record(code, note + " DROPPED-HALFWAY")
        try:
            for i in range(0, len(chunk), 16384):
                self.wfile.write(chunk[i:i + 16384])
                if self.server.delay:
                    self.wfile.flush(); time.sleep(self.server.delay)
        except (BrokenPipeError, ConnectionResetError):
            return self.record(code, note + " client-gone")
        self.record(code, f"{note} range-from={start}")

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--port", type=int, default=0)
    ap.add_argument("--mode", default="modern")
    ap.add_argument("--flaky", action="store_true")
    ap.add_argument("--norange", action="store_true")
    ap.add_argument("--delay", type=float, default=0.0, help="pausa (s) a cada 16 KB, para downloads lentos")
    ap.add_argument("--reqlog", default="/tmp/mockromm_requests.log")
    ap.add_argument("--portfile")
    a = ap.parse_args()
    srv = ThreadingHTTPServer(("127.0.0.1", a.port), Handler)
    srv.mode, srv.flaky, srv.flaky_done, srv.norange, srv.reqlog, srv.delay = a.mode, a.flaky, False, a.norange, a.reqlog, a.delay
    if a.portfile:
        open(a.portfile, "w").write(str(srv.server_address[1]))
    srv.serve_forever()

if __name__ == "__main__":
    main()
