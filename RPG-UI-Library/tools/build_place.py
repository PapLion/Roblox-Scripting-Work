"""Build the Vellum gallery place from src/ and optionally serve it for live sync.

    python tools/build_place.py                 -> place/Vellum_RPG_UI_Library.rbxlx
    python tools/build_place.py --serve [port]  -> http://127.0.0.1:<port>/manifest.json (default 34873)

Mapping (same convention as the PIVOT project):
    src/<Service>/...           top-level folders are services
    Foo/                        Folder (or, if Foo.module.luau exists next to it, the children of that module)
    Foo.module.luau             ModuleScript
    Foo.client.luau             LocalScript
    Foo.server.luau             Script

The manifest is what tools/sync.luau (run through the Studio command bar / MCP) applies to an open
place: every script is created or updated in place, and scripts that no longer exist in src/ under a
managed root are removed. The roots are listed in MANAGED.
"""
from __future__ import annotations

import hashlib
import json
import sys
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from xml.sax.saxutils import escape

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "src"
OUT = ROOT / "place" / "Vellum_RPG_UI_Library.rbxlx"
MANAGED = ["ReplicatedStorage/Vellum", "ReplicatedStorage/VellumGallery", "StarterPlayer/StarterPlayerScripts/VellumGallery"]

SUFFIX = {".module.luau": "ModuleScript", ".client.luau": "LocalScript", ".server.luau": "Script"}


def classify(p: Path):
    for suf, cls in SUFFIX.items():
        if p.name.endswith(suf):
            return p.name[: -len(suf)], cls
    return None, None


def walk(directory: Path, parent: str):
    """Yield dicts {path, name, class, source} in parent-before-child order."""
    items = sorted(directory.iterdir(), key=lambda p: (p.is_dir(), p.name))
    scripts = {}
    for p in items:
        if p.is_file():
            name, cls = classify(p)
            if cls:
                path = f"{parent}/{name}"
                scripts[name] = path
                yield {"path": path, "name": name, "class": cls, "source": p.read_text(encoding="utf-8").replace("\r\n", "\n")}
    for p in items:
        if p.is_dir():
            if p.name in scripts:
                yield from walk(p, scripts[p.name])
            else:
                path = f"{parent}/{p.name}"
                yield {"path": path, "name": p.name, "class": "Folder"}
                yield from walk(p, path)


def manifest():
    entries = []
    for service in sorted(SRC.iterdir()):
        if service.is_dir():
            entries.extend(walk(service, service.name))
    digest = hashlib.sha256(json.dumps(entries, sort_keys=True).encode()).hexdigest()[:12]
    return {"managed": MANAGED, "hash": digest, "entries": entries}


def build():
    m = manifest()
    ref = iter(range(1, 1_000_000))
    children: dict[str, list] = {}
    for e in m["entries"]:
        children.setdefault(e["path"].rsplit("/", 1)[0], []).append(e)

    def item(e, depth):
        pad = "  " * depth
        props = [f'<string name="Name">{escape(e["name"])}</string>']
        if "source" in e:
            props.append(f'<ProtectedString name="Source"><![CDATA[{e["source"]}]]></ProtectedString>')
        inner = "".join(item(c, depth + 1) for c in children.get(e["path"], []))
        return f'{pad}<Item class="{e["class"]}" referent="RBX{next(ref)}"><Properties>{"".join(props)}</Properties>\n{inner}{pad}</Item>\n'

    def service(cls, extra="", kids=""):
        return f'<Item class="{cls}" referent="RBX{next(ref)}"><Properties><string name="Name">{cls}</string>{extra}</Properties>\n{kids}</Item>\n'

    body = []
    starter_player_kids = ""
    for svc in sorted({e["path"].split("/")[0] for e in m["entries"]}):
        kids = "".join(item(c, 1) for c in children.get(svc, []))
        if svc == "StarterPlayer":
            # StarterPlayerScripts is a nested service-like container
            sps = "".join(item(c, 2) for c in children.get("StarterPlayer/StarterPlayerScripts", []))
            starter_player_kids = f'  <Item class="StarterPlayerScripts" referent="RBX{next(ref)}"><Properties><string name="Name">StarterPlayerScripts</string></Properties>\n{sps}  </Item>\n'
            continue
        body.append(service(svc, kids=kids))
    body.append(service("StarterPlayer", kids=starter_player_kids))
    # No avatar, no world: the place opens straight into the UI gallery.
    body.append(service("Players", extra='<bool name="CharacterAutoLoads">false</bool>'))
    body.append(service("Lighting", extra='<Color3 name="Ambient"><R>0.5</R><G>0.5</G><B>0.5</B></Color3>'))
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text('<roblox version="4">\n' + "".join(body) + "</roblox>\n", encoding="utf-8")
    n = sum(1 for e in m["entries"] if "source" in e)
    print(f"built {OUT.relative_to(ROOT)}: {n} scripts, hash {m['hash']}")


def serve(port: int):
    class H(BaseHTTPRequestHandler):
        def do_GET(self):
            if self.path.startswith("/sync.luau"):
                body = (ROOT / "tools" / "sync.luau").read_bytes()
            elif self.path.startswith("/f/"):
                target = (ROOT / self.path[3:].split("?")[0]).resolve()
                if ROOT not in target.parents or not target.is_file():
                    self.send_response(404)
                    self.end_headers()
                    return
                body = target.read_bytes()
            else:
                body = json.dumps(manifest()).encode()
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

        def log_message(self, *a):
            pass

    print(f"serving manifest on http://127.0.0.1:{port}/manifest.json")
    ThreadingHTTPServer(("127.0.0.1", port), H).serve_forever()


if __name__ == "__main__":
    if "--serve" in sys.argv:
        i = sys.argv.index("--serve")
        serve(int(sys.argv[i + 1]) if len(sys.argv) > i + 1 else 34873)
    else:
        build()
