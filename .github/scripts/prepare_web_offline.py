"""Bundle the app's offline dependencies and stamp the service worker."""

import hashlib
import json
import struct
from pathlib import Path
from urllib.parse import quote
from urllib.request import urlopen

BUILD = Path("build/web")
FONT_SOURCE = (
    "https://raw.githubusercontent.com/google/fonts/"
    "295d98a7a0c17c68f1341eaeea354e7960ea70d3/ofl/notosansjp/"
)
FONT_HASH = "c2f3b4d463500a2ddcd3849cded1fceeb9fd6d1c32e6cbecd568453ba50fc68f"


def download(url, path, checksum=None):
    with urlopen(url, timeout=30) as response:
        data = response.read()
    if checksum and hashlib.sha256(data).hexdigest() != checksum:
        raise ValueError(f"Unexpected checksum for {path.name}")
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(data)


def download_fonts():
    font_path = "fonts/NotoSansJP.ttf"
    assets = BUILD / "assets"
    download(FONT_SOURCE + "NotoSansJP%5Bwght%5D.ttf", assets / font_path, FONT_HASH)
    download(FONT_SOURCE + "OFL.txt", assets / "fonts/OFL-NotoSansJP.txt")

    # CanvasKit loads these fallback faces separately from FontManifest.json.
    fallback = assets / "font-fallback"
    roboto = "roboto/v32/KFOmCnqEu92Fr1Me4GZLCzYlKw.woff2"
    emoji = "notocoloremoji/v39/Yq6P-KqIXTD0t4D9z1ESnKM3-HpFabsE4tq3luCC7p-aXxcn.4.woff2"
    download(
        "https://fonts.gstatic.com/s/" + roboto,
        fallback / roboto,
        "35b02ca266b79eb4996590f15817425a1ce9ebf48f84471843233ff614656bf2",
    )
    download(
        "https://fonts.gstatic.com/s/" + emoji,
        fallback / emoji,
        "f7848ab453b11441c20792f91c202ee98bcdcc223609e8cda6930d5f947c3d68",
    )
    download(
        "https://raw.githubusercontent.com/googlefonts/roboto/main/LICENSE",
        fallback / "roboto/LICENSE.txt",
    )
    download(
        "https://raw.githubusercontent.com/googlefonts/noto-emoji/main/LICENSE",
        fallback / "notocoloremoji/LICENSE.txt",
    )

    bootstrap = BUILD / "flutter_bootstrap.js"
    bootstrap.write_text(
        bootstrap.read_text(encoding="utf-8").replace(
            "// __OFFLINE_FONT_FALLBACK__",
            "fontFallbackBaseUrl: new URL('assets/font-fallback/', document.baseURI).href,",
        ),
        encoding="utf-8",
    )

    manifest_path = BUILD / "assets/FontManifest.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    manifest = [face for face in manifest if face["family"] != "OfflineNotoSansJP"]
    manifest.append({"family": "OfflineNotoSansJP", "fonts": [{"asset": font_path}]})
    manifest_path.write_text(json.dumps(manifest), encoding="utf-8")


def prepare_icon():
    # Reuse the 256x256 PNG entry in the existing Windows app icon.
    icon = Path("windows/runner/resources/app_icon.ico").read_bytes()
    count = struct.unpack_from("<H", icon, 4)[0]
    for index in range(count):
        entry = 6 + index * 16
        if icon[entry : entry + 2] != b"\x00\x00":
            continue
        size, offset = struct.unpack_from("<II", icon, entry + 8)
        png = icon[offset : offset + size]
        if png.startswith(b"\x89PNG\r\n\x1a\n"):
            (BUILD / "app-icon.png").write_bytes(png)
            return
    raise ValueError("The desktop icon is missing its 256x256 PNG entry")


def prepare_worker():
    paths = [
        "app-icon.png",
        "canvaskit/canvaskit.js",
        "canvaskit/canvaskit.wasm",
        "flutter_bootstrap.js",
        "index.html",
        "main.dart.js",
        "manifest.json",
        "version.json",
        *(p.relative_to(BUILD).as_posix() for p in (BUILD / "assets").rglob("*") if p.is_file()),
    ]
    template = Path(__file__).with_name("offline_service_worker.js").read_text(encoding="utf-8")
    digest = hashlib.sha256(template.encode())
    for path in sorted(paths):
        digest.update(path.encode())
        digest.update(hashlib.sha256((BUILD / path).read_bytes()).digest())
    source = template.replace("__BUILD_HASH__", digest.hexdigest()).replace(
        "/*__OFFLINE_FILES__*/ []", json.dumps([quote(p) for p in sorted(paths)])
    )
    (BUILD / "offline_service_worker.js").write_text(source, encoding="utf-8")


if __name__ == "__main__":
    download_fonts()
    prepare_icon()
    prepare_worker()
