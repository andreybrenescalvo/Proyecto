#!/usr/bin/env python3
"""Genera las texturas del juego (color + relieve) y las guarda en assets/textures/.

Todas se repiten sin costuras (el ruido se arma con FFT, que es periódico por naturaleza)
y son propias: no hay que dar créditos ni pagar licencias para publicar el juego.

Uso:  python3 tools/generate_textures.py
Necesita numpy y Pillow. Es determinista: siempre genera las mismas imágenes.

Las que se pueden teñir (revestimiento, estuco, pintura, empapelados, baldosas, alfombra,
tela) son casi blancas: el color lo pone cada estilo de casa en el juego.
"""
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

N = 512
OUT = Path(__file__).resolve().parent.parent / "assets" / "textures"


# ------------------------------------------------------------------ utilidades

def rng(seed):
    return np.random.default_rng(seed)


def fnoise(seed, beta=2.0, size=N, aniso=(1.0, 1.0)):
    """Ruido fractal periódico en [0, 1]. beta alto = manchas grandes y suaves.
    aniso = (alto, ancho) de las vetas: (1, 0.05) son vetas largas a lo ancho (horizontales)."""
    r = rng(seed)
    white = r.standard_normal((size, size))
    fy = np.fft.fftfreq(size)[:, None] / aniso[0]
    fx = np.fft.fftfreq(size)[None, :] / aniso[1]
    f = np.sqrt(fx * fx + fy * fy)
    f[0, 0] = 1.0
    spec = np.fft.fft2(white) / f ** (beta / 2.0)
    spec[0, 0] = 0.0
    n = np.real(np.fft.ifft2(spec))
    n -= n.min()
    return n / max(n.max(), 1e-9)


def blur(a, sigma):
    """Desenfoque gaussiano periódico (por FFT)."""
    size = a.shape[0]
    fy = np.fft.fftfreq(size)[:, None]
    fx = np.fft.fftfreq(size)[None, :]
    g = np.exp(-2.0 * (np.pi * sigma) ** 2 * (fx * fx + fy * fy))
    if a.ndim == 3:
        return np.stack([np.real(np.fft.ifft2(np.fft.fft2(a[..., c]) * g)) for c in range(a.shape[2])], -1)
    return np.real(np.fft.ifft2(np.fft.fft2(a) * g))


def mix(c0, c1, t):
    c0 = np.array(c0, float)
    c1 = np.array(c1, float)
    return c0 + (c1 - c0) * t[..., None]


def normal_from_height(h, strength):
    dx = (np.roll(h, -1, 1) - np.roll(h, 1, 1)) * 0.5 * strength
    dy = (np.roll(h, -1, 0) - np.roll(h, 1, 0)) * 0.5 * strength
    n = np.stack([-dx, dy, np.ones_like(h)], -1)   # convención OpenGL (Godot)
    n /= np.linalg.norm(n, axis=-1, keepdims=True)
    return (n * 0.5 + 0.5) * 255.0


def save(name, color, height, strength=4.0):
    OUT.mkdir(parents=True, exist_ok=True)
    rgb = np.clip(color, 0, 255).astype(np.uint8)
    Image.fromarray(rgb, "RGB").save(OUT / f"{name}.jpg", quality=90)
    nrm = np.clip(normal_from_height(height, strength), 0, 255).astype(np.uint8)
    Image.fromarray(nrm, "RGB").save(OUT / f"{name}_n.jpg", quality=93)
    print("textura:", name)


def grid():
    y, x = np.mgrid[0:N, 0:N].astype(float)
    return x, y


def periodic_dist(ax, ay, px, py):
    dx = np.abs(ax - px)
    dy = np.abs(ay - py)
    dx = np.minimum(dx, N - dx)
    dy = np.minimum(dy, N - dy)
    return np.sqrt(dx * dx + dy * dy)


def voronoi(seed, count):
    """Celdas periódicas: devuelve (índice de celda, F1, F2)."""
    r = rng(seed)
    pts = r.uniform(0, N, (count, 2))
    x, y = grid()
    d = np.stack([periodic_dist(x, y, p[0], p[1]) for p in pts], 0)
    order = np.argsort(d, 0)
    f = np.take_along_axis(d, order[:2], 0)
    return order[0], f[0], f[1]


# ------------------------------------------------------------------ exteriores

def brick():
    """Ladrillo rojo con junta de mortero. La textura mide 1 m."""
    x, y = grid()
    rows, per_row, mortar = 14, 4, 5
    rh = N / rows
    bw = N / per_row
    row = (y // rh).astype(int)
    xo = (x + (row % 2) * bw * 0.5) % N
    col = (xo // bw).astype(int)
    lx = xo - col * bw
    ly = y - row * rh
    edge = np.minimum.reduce([lx, bw - lx, ly, rh - ly])
    is_brick = edge > mortar * 0.5
    r = rng(1)
    tint = r.uniform(0.75, 1.15, (rows, per_row + 1))
    hue = r.uniform(-0.08, 0.08, (rows, per_row + 1))
    t = tint[row, col]
    h = hue[row, col]
    speck = fnoise(2, 0.6)
    blotch = fnoise(3, 2.5)
    base = np.stack([150 * t * (1 + h), 62 * t * (1 - h), 45 * t], -1)
    base *= (0.8 + 0.35 * blotch)[..., None]
    base *= (0.88 + 0.24 * speck)[..., None]
    mort = mix((168, 160, 150), (128, 122, 116), fnoise(4, 1.0))
    color = np.where(is_brick[..., None], base, mort)
    height = np.clip(edge / 4.0, 0, 1) * (0.85 + 0.15 * speck)
    save("brick", color, height, 6.0)


def siding():
    """Revestimiento de madera horizontal (tablas solapadas). 8 tablas por metro."""
    x, y = grid()
    boards = 8
    bh = N / boards
    ly = (y % bh) / bh
    grain = fnoise(10, 1.6, aniso=(1.0, 0.08))
    paint = fnoise(11, 2.2)
    shade = 0.78 + 0.22 * ly                     # cada tabla es más oscura arriba (la sombra de la de arriba)
    lip = np.where(ly > 0.93, 0.62, 1.0)         # borde inferior: sombra marcada
    v = (232 * shade * lip * (0.94 + 0.06 * grain) * (0.95 + 0.05 * paint))
    color = np.stack([v, v * 0.985, v * 0.96], -1)
    height = ly * 0.9 + 0.1 * grain
    save("siding", color, height, 5.0)


def stucco():
    """Estuco / revoque rugoso (para teñir)."""
    a = fnoise(20, 1.2)
    b = fnoise(21, 2.6)
    v = 215 + 30 * (b - 0.5) + 22 * (a - 0.5)
    color = np.stack([v, v * 0.98, v * 0.95], -1)
    save("stucco", color, a * 0.7 + b * 0.3, 3.0)


def stone():
    """Piedra encastrada (zócalo de la casa, chimenea, caminitos)."""
    idx, f1, f2 = voronoi(30, 34)
    r = rng(31)
    tones = r.uniform(0.7, 1.15, 34)
    warm = r.uniform(-0.06, 0.06, 34)
    edge = f2 - f1
    is_stone = edge > 5
    t = tones[idx]
    w = warm[idx]
    rough = fnoise(32, 1.0)
    base = np.stack([150 * t * (1 + w), 142 * t, 130 * t * (1 - w)], -1) * (0.8 + 0.3 * rough)[..., None]
    mort = np.full_like(base, 80.0)
    color = np.where(is_stone[..., None], base, mort)
    height = np.clip(edge / 14.0, 0, 1) ** 0.5 * (0.8 + 0.2 * rough)
    save("stone", color, height, 6.0)


def shingles():
    """Tejas asfálticas (para teñir). Una textura = 1 m: 6 hileras."""
    x, y = grid()
    rows, tabs = 6, 5
    rh = N / rows
    tw = N / tabs
    row = (y // rh).astype(int)
    xo = (x + (row % 2) * tw * 0.5) % N
    col = (xo // tw).astype(int)
    lx = xo - col * tw
    ly = (y % rh) / rh
    r = rng(40)
    tone = r.uniform(0.72, 1.1, (rows, tabs + 1))[row, col]
    gran = fnoise(41, 0.3)
    gap = (lx < 3) | (lx > tw - 3)
    shade = 0.7 + 0.3 * ly
    v = 165 * tone * shade * (0.8 + 0.4 * gran)
    v = np.where(gap & (ly > 0.35), v * 0.45, v)
    color = np.stack([v, v * 0.98, v * 0.96], -1)
    height = ly * 0.8 + 0.2 * gran - np.where(gap & (ly > 0.35), 0.4, 0)
    save("shingles", color, height, 5.0)


def clay_tiles():
    """Tejas coloniales de arcilla (onduladas)."""
    x, y = grid()
    rows, waves = 5, 6
    rh = N / rows
    ly = (y % rh) / rh
    row = (y // rh).astype(int)
    wave = np.sin((x / N) * waves * 2 * np.pi + row * np.pi) * 0.5 + 0.5
    r = rng(50)
    col = ((x / N) * waves * 2 + row).astype(int) % (waves * 2)
    tone = r.uniform(0.78, 1.12, (rows, waves * 2))[row, col]
    dirt = fnoise(51, 2.0)
    shade = (0.55 + 0.45 * wave) * (0.75 + 0.25 * ly)
    base = np.stack([190 * tone, 92 * tone, 58 * tone], -1) * shade[..., None]
    base *= (0.8 + 0.3 * dirt)[..., None]
    height = wave * 0.7 + ly * 0.5
    save("clay_tiles", base, height, 6.0)


def grass():
    """Pasto con manchas y briznas."""
    a = fnoise(60, 2.6)
    b = fnoise(61, 0.8)
    img = Image.new("L", (N, N), 0)
    d = ImageDraw.Draw(img)
    r = rng(62)
    for _ in range(4500):
        px, py = r.uniform(0, N, 2)
        ang = r.uniform(-0.5, 0.5)
        ln = r.uniform(4, 11)
        val = int(r.uniform(90, 255))
        for ox in (-N, 0, N):
            for oy in (-N, 0, N):
                d.line([(px + ox, py + oy), (px + ox + np.sin(ang) * ln, py + oy - np.cos(ang) * ln)], fill=val, width=1)
    blades = np.asarray(img, float) / 255.0
    t = np.clip(0.35 * a + 0.35 * b + 0.45 * blades, 0, 1)
    color = mix((38, 62, 26), (96, 132, 54), t)
    dry = np.clip((fnoise(63, 3.0) - 0.62) * 3.0, 0, 1)
    color = color * (1 - dry[..., None] * 0.5) + np.array([120, 112, 60]) * dry[..., None] * 0.5
    save("grass", color, t, 3.0)


def asphalt():
    a = fnoise(70, 0.4)
    b = fnoise(71, 2.4)
    r = rng(72)
    pebble = (r.random((N, N)) > 0.985).astype(float)
    pebble = np.clip(blur(pebble, 0.8) * 6, 0, 1)
    v = 52 + 26 * (a - 0.5) + 18 * (b - 0.5) + 40 * pebble
    color = np.stack([v, v, v * 1.03], -1)
    save("asphalt", color, a * 0.6 + pebble * 0.4, 3.0)


def concrete():
    """Vereda de hormigón: dos losas por textura (cada una de 1 m)."""
    x, y = grid()
    a = fnoise(80, 1.1)
    b = fnoise(81, 2.8)
    joint = (np.abs((x % (N / 2)) - 0) < 2) | (np.abs((y % (N / 2)) - 0) < 2)
    v = 168 + 24 * (a - 0.5) + 30 * (b - 0.5)
    v = np.where(joint, v * 0.55, v)
    color = np.stack([v, v * 0.99, v * 0.96], -1)
    height = a * 0.4 + 0.6 - np.where(joint, 0.6, 0)
    save("concrete", color, height, 4.0)


def bark():
    x, y = grid()
    g = fnoise(90, 1.8, aniso=(0.06, 1.0))
    c = fnoise(91, 0.8)
    t = np.clip(g * 0.8 + c * 0.3, 0, 1)
    color = mix((40, 30, 22), (110, 88, 66), t)
    save("bark", color, t, 6.0)


def leaves():
    """Follaje (cercos vivos, copas de árboles): muchas hojitas superpuestas."""
    r = rng(95)
    img = Image.new("RGB", (N, N), (14, 26, 12))
    d = ImageDraw.Draw(img)
    for _ in range(5200):
        px, py = r.uniform(0, N, 2)
        ln = r.uniform(5, 11)
        wd = ln * r.uniform(0.35, 0.55)
        ang = r.uniform(0, np.pi)
        g = r.uniform(0.45, 1.0)
        col = (int(40 * g + r.uniform(0, 15)), int(95 * g + r.uniform(0, 20)), int(32 * g))
        ca, sa = np.cos(ang), np.sin(ang)
        pts = [(ln * ca, ln * sa), (-wd * sa, wd * ca), (-ln * ca, -ln * sa), (wd * sa, -wd * ca)]
        for ox in (-N, 0, N):
            for oy in (-N, 0, N):
                d.polygon([(px + ox + x, py + oy + y) for x, y in pts], fill=col)
    color = np.asarray(img.filter(ImageFilter.GaussianBlur(0.6)), float)
    shade = fnoise(96, 2.2)
    color *= (0.6 + 0.5 * shade)[..., None]
    height = color.mean(-1) / 255.0
    save("leaves", color, height, 5.0)


# ------------------------------------------------------------------ interiores

def wood_floor():
    """Piso de tablas de madera: 6 tablas por textura (de 1,5 m), cortadas en distintos largos."""
    x, y = grid()
    planks = 6
    ph = N / planks
    row = (y // ph).astype(int)
    r = rng(100)
    cut = r.uniform(0, N, planks)
    seg = ((x + cut[row]) % N >= N / 2).astype(int)
    pid = row * 2 + seg
    tone = r.uniform(0.75, 1.15, planks * 2)[pid]
    lx = (x + cut[row]) % (N / 2)
    ly = y % ph
    gap = (ly < 1.5) | (lx < 1.5)
    grain = fnoise(101, 1.5, aniso=(1.0, 0.05))
    rings = np.sin((y + grain * 60) * 0.35 + pid * 3.0) * 0.5 + 0.5
    t = np.clip(0.55 * grain + 0.45 * rings, 0, 1)
    base = mix((122, 78, 44), (176, 122, 74), t) * tone[..., None]
    color = np.where(gap[..., None], base * 0.35, base)
    height = 0.8 + 0.2 * t - np.where(gap, 0.8, 0)
    save("wood_floor", color, height, 4.0)


def wood():
    """Madera de muebles (veta horizontal)."""
    x, y = grid()
    grain = fnoise(110, 1.6, aniso=(1.0, 0.06))
    rings = np.sin((y + grain * 90) * 0.12) * 0.5 + 0.5
    t = np.clip(0.5 * grain + 0.5 * rings, 0, 1)
    color = mix((150, 104, 64), (206, 160, 112), t)
    save("wood", color, t, 2.0)


def door_wood():
    """Madera con veta vertical (puertas, cercas)."""
    x, y = grid()
    grain = fnoise(115, 1.6, aniso=(0.06, 1.0))
    rings = np.sin((x + grain * 90) * 0.14) * 0.5 + 0.5
    t = np.clip(0.5 * grain + 0.5 * rings, 0, 1)
    color = mix((160, 112, 70), (214, 170, 120), t)
    save("door_wood", color, t, 2.0)


def tiles(name, count, grout, seed):
    """Baldosas cuadradas (para teñir)."""
    x, y = grid()
    s = N / count
    lx = x % s
    ly = y % s
    cid = (y // s).astype(int) * count + (x // s).astype(int)
    r = rng(seed)
    tone = r.uniform(0.92, 1.04, count * count)[cid]
    edge = np.minimum.reduce([lx, s - lx, ly, s - ly])
    is_tile = edge > grout * 0.5
    a = fnoise(seed + 1, 2.4)
    v = 236 * tone * (0.97 + 0.05 * a)
    v = np.where(is_tile, v, 150)
    color = np.stack([v, v, v * 0.98], -1)
    height = np.clip(edge / 3.0, 0, 1)
    save(name, color, height, 5.0)


def carpet():
    a = fnoise(130, 0.2)
    b = fnoise(131, 2.2)
    v = 200 + 40 * (a - 0.5) + 18 * (b - 0.5)
    color = np.stack([v, v, v], -1)
    save("carpet", color, a, 2.5)


def paint():
    """Pared pintada (revoque fino, para teñir)."""
    a = fnoise(140, 1.0)
    b = fnoise(141, 2.8)
    v = 236 + 8 * (a - 0.5) + 10 * (b - 0.5)
    color = np.stack([v, v, v], -1)
    save("paint", color, a * 0.5 + b * 0.5, 1.2)


def wallpaper_stripes():
    x, y = grid()
    period = N / 8
    lx = x % period
    stripe = np.where(lx < period * 0.5, 1.0, 0.86)
    line = np.where(np.abs(lx - period * 0.5) < 1.5, 0.75, 1.0)
    paper = fnoise(150, 0.8)
    v = 238 * stripe * line * (0.97 + 0.04 * paper)
    color = np.stack([v, v * 0.99, v * 0.96], -1)
    save("wallpaper_stripes", color, paper * 0.3 + stripe * 0.2, 1.5)


def wallpaper_damask():
    """Empapelado con un motivo floral repetido (para teñir)."""
    img = Image.new("L", (N, N), 255)
    d = ImageDraw.Draw(img)
    cell = N // 4
    for gy in range(5):
        for gx in range(5):
            cx = gx * cell + (cell // 2 if gy % 2 else 0)
            cy = gy * cell
            for ox in (-N, 0, N):
                for oy in (-N, 0, N):
                    px, py = cx + ox, cy + oy
                    d.ellipse([px - 14, py - 30, px + 14, py + 30], outline=205, width=4)
                    d.ellipse([px - 30, py - 12, px + 30, py + 12], outline=205, width=4)
                    d.ellipse([px - 6, py - 6, px + 6, py + 6], fill=200)
                    for k in range(4):
                        a = k * np.pi / 2 + np.pi / 4
                        qx, qy = px + np.cos(a) * 42, py + np.sin(a) * 42
                        d.ellipse([qx - 5, qy - 5, qx + 5, qy + 5], fill=215)
    motif = np.asarray(img.filter(ImageFilter.GaussianBlur(0.8)), float) / 255.0
    paper = fnoise(160, 0.8)
    v = 236 * motif * (0.97 + 0.04 * paper)
    color = np.stack([v, v * 0.98, v * 0.95], -1)
    save("wallpaper_damask", color, 1.0 - motif, 2.0)


def fabric():
    """Tela tejida (sillones, frazadas, cortinas; para teñir)."""
    x, y = grid()
    warp = np.sin(x * 2 * np.pi / 6.0) * 0.5 + 0.5
    weft = np.sin(y * 2 * np.pi / 6.0) * 0.5 + 0.5
    weave = np.where(((x // 6 + y // 6) % 2) == 0, warp, weft)
    a = fnoise(170, 1.4)
    v = 210 * (0.82 + 0.18 * weave) * (0.92 + 0.12 * a)
    color = np.stack([v, v, v], -1)
    save("fabric", color, weave * 0.6 + a * 0.4, 2.0)


def metal():
    x, y = grid()
    streak = fnoise(180, 1.4, aniso=(1.0, 0.02))
    a = fnoise(181, 2.6)
    v = 175 + 30 * (streak - 0.5) + 14 * (a - 0.5)
    color = np.stack([v, v * 1.01, v * 1.03], -1)
    save("metal", color, streak, 1.0)


def marble():
    x, y = grid()
    a = fnoise(190, 2.4)
    b = fnoise(191, 1.4)
    wave = np.abs(np.sin((x / N * 2 + y / N + (a - 0.5) * 2.5) * np.pi * 2))
    veins = np.clip(1 - wave * 7, 0, 1) * (0.6 + 0.4 * b)
    v = 232 - 70 * veins + 10 * (b - 0.5)
    color = np.stack([v, v, v * 1.01], -1)
    save("marble", color, 1 - veins * 0.3, 1.0)


def plastic():
    a = fnoise(200, 2.0)
    v = 220 + 10 * (a - 0.5)
    color = np.stack([v, v, v], -1)
    save("plastic", color, a, 0.5)


if __name__ == "__main__":
    for f in (brick, siding, stucco, stone, shingles, clay_tiles, grass, asphalt, concrete, bark, leaves,
              wood_floor, wood, door_wood, carpet, paint, wallpaper_stripes, wallpaper_damask, fabric,
              metal, marble, plastic):
        f()
    tiles("tiles", 4, 5, 120)
    tiles("tiles_small", 10, 3, 125)
    print("listo:", OUT)
