"""Baja los paquetes gratuitos (CC0) de Quaternius que usa la herramienta de personajes:
Universal Base Characters y Universal Animation Library, a tools/personajes/fuentes/.

Uso: python3 tools/personajes/descargar_fuentes.py   (necesita acceso a itch.io)
"""
import http.cookiejar, io, json, os, re, urllib.parse, urllib.request, zipfile

HERE = os.path.dirname(os.path.abspath(__file__))
DEST = os.path.join(HERE, "fuentes")
PACKS = ["universal-base-characters", "universal-animation-library"]


def bajar(slug):
    jar = http.cookiejar.CookieJar()
    op = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(jar))
    base = f"https://quaternius.itch.io/{slug}"
    page = op.open(base).read().decode()
    token = re.search(r'csrf_token" value="([^"]+)', page).group(1)
    data = urllib.parse.urlencode({"csrf_token": token}).encode()
    dl = json.load(op.open(base + "/download_url", data))["url"]
    page = op.open(dl).read().decode()
    upload = re.search(r'data-upload_id="(\d+)"', page).group(1)
    info = json.load(op.open(f"{base}/file/{upload}?source=view_game&as_props=1&after_download_lightbox=true", data))
    print("bajando", slug, "...")
    blob = op.open(info["url"]).read()
    zipfile.ZipFile(io.BytesIO(blob)).extractall(DEST)


if __name__ == "__main__":
    os.makedirs(DEST, exist_ok=True)
    for s in PACKS:
        bajar(s)
    print("listo:", DEST)
