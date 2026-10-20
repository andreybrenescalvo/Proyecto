"""Arma un personaje en Blender: cuerpo con proporciones propias, piel, pelo, ropa en capas y
sombrero, y lo exporta a glTF. Uso: python b_armar.py receta [receta ...]"""
import sys, time
import os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from blib import *
from b_cuerpo import restyle, BODY
from b_piel import skin_texture
import b_ropa
import b_pelo

NARANJA = (0.86, 0.42, 0.12)

RECETAS = {
    "mudancero": {
        "base": "male", "body": {}, "skin": {"tone": (0.84, 0.62, 0.5)},
        "ojos": (0.36, 0.22, 0.1), "cejas": ((0.14, 0.09, 0.06), 1.0),
        "pelo": ("SimpleParted", (0.16, 0.1, 0.06)), "sombrero": None,
        "ropa": [("remera", {"color": NARANJA}), ("jean", {}),
                 ("zapatillas", {"color": (0.2, 0.2, 0.22), "accent": NARANJA})],
    },
    "mudancera": {
        "base": "female", "body": {}, "skin": {"tone": (0.62, 0.42, 0.31), "blush": 0.2},
        "ojos": (0.3, 0.22, 0.1), "cejas": ((0.06, 0.045, 0.035), 1.0),
        "pelo": ("Long", (0.07, 0.05, 0.04)), "sombrero": None,
        "ropa": [("camisa", {"pattern": "cuadros", "color": (0.62, 0.12, 0.1), "color2": (0.1, 0.1, 0.12), "sleeve": 0.5,
                             "buttons": (0.15, 0.12, 0.1)}),
                 ("jean", {"color": (0.12, 0.13, 0.16)}),
                 ("zapatillas", {"color": (0.9, 0.9, 0.9), "accent": (0.9, 0.74, 0.16)})],
    },
    "mudancero2": {
        "base": "male", "body": {"shoulders": 0.9, "belly": 0.03}, "skin": {"tone": (0.93, 0.74, 0.62), "freckles": 1.0, "blush": 0.6},
        "ojos": (0.25, 0.45, 0.25), "cejas": ((0.5, 0.22, 0.08), 1.0),
        "pelo": ("rulos", (0.55, 0.22, 0.07)), "sombrero": None,
        "ropa": [("remera", {"color": (0.24, 0.55, 0.3)}), ("jean", {"color": (0.35, 0.45, 0.6)}),
                 ("zapatillas", {"color": (0.92, 0.92, 0.9), "accent": (0.24, 0.55, 0.3)})],
    },
    "ramon": {
        "base": "male", "body": {"belly": 0.1, "waist": 1.14, "shoulders": 0.92, "chest": 0.92},
        "skin": {"tone": (0.86, 0.66, 0.57), "age": 1.0, "blush": 0.7},
        "ojos": (0.42, 0.52, 0.66), "cejas": ((0.82, 0.82, 0.8), 1.6),
        "pelo": ("Buzzed", (0.85, 0.85, 0.83)),
        "sombrero": None,
        "ropa": [("camisa", {"pattern": "rayas", "color": (0.45, 0.62, 0.82), "color2": (0.85, 0.87, 0.9), "sleeve": 1.0,
                             "v_depth": 0.12, "piping": (0.15, 0.22, 0.42), "buttons": (0.95, 0.95, 0.95)}),
                 ("pantalon_pijama", {"color": (0.45, 0.62, 0.82), "color2": (0.85, 0.87, 0.9)}),
                 ("pantuflas", {"color": (0.45, 0.13, 0.12)})],
    },
}

# Catálogo: la misma cabeza con cada sombrero y cada peinado.
_BASE_CAT = {"base": "male", "body": {}, "skin": {"tone": (0.84, 0.62, 0.5), "stubble": 0.3}, "ojos": (0.36, 0.22, 0.1),
             "cejas": ((0.14, 0.09, 0.06), 1.0), "solo_cabeza": True, "ropa": []}
for _n, _hat in (("lana", ("gorro_lana", {"color": (0.14, 0.14, 0.16)})), ("gorra", ("gorra", {"color": (0.2, 0.35, 0.6), "logo": "MT"})),
                 ("casco", ("casco_obra", {})), ("piluso", ("piluso", {})), ("dormir", ("gorro_dormir", {}))):
    RECETAS["cat_" + _n] = {**_BASE_CAT, "pelo": ("SimpleParted", (0.16, 0.1, 0.06)), "sombrero": _hat}
for _n, _p in (("raya", ("SimpleParted", (0.16, 0.1, 0.06))), ("rapado", ("Buzzed", (0.1, 0.07, 0.05))), ("rulos", ("rulos", (0.12, 0.08, 0.05))),
               ("barba", ("Beard", (0.2, 0.12, 0.07)))):
    RECETAS["cat_pelo_" + _n] = {**_BASE_CAT, "pelo": _p, "sombrero": None}
RECETAS["cat_pelo_largo"] = {**_BASE_CAT, "base": "female", "skin": {"tone": (0.88, 0.68, 0.56), "freckles": 0.7},
                             "pelo": ("Long", (0.45, 0.25, 0.1)), "sombrero": None}
RECETAS["cat_pelo_rodete"] = {**_BASE_CAT, "base": "female", "skin": {"tone": (0.62, 0.42, 0.31)},
                              "pelo": ("Buns", (0.06, 0.045, 0.035)), "sombrero": None}

# Línea del borde de cada sombrero (para recortar el pelo que quedaría adentro).
HAT_LINES = {"gorro_lana": (0.03, -0.065), "gorra": (0.045, -0.03), "gorro_dormir": (0.04, -0.06), "casco_obra": (0.045, -0.025),
             "piluso": (0.04, -0.04)}


def armar(nombre):
    t0 = time.time()
    r = RECETAS[nombre]
    reset()
    b = import_base(r["base"])
    restyle(b, {**BODY, **r["body"]})
    out = b_ropa.OUT
    os.makedirs(out, exist_ok=True)
    src = ("T_Superhero_Male_Dark.png", "T_Superhero_Male_Normal.png") if r["base"] == "male" else ("T_Superhero_Female_Dark_BaseColor.png", "T_Superhero_Female_Normal.png")
    skin_texture(b, r["skin"], out + f"/{nombre}_piel.png", out + f"/{nombre}_piel_n.png", src_tex=src[0], src_nrm=src[1])
    set_material(b["body"], simple_material(nombre + "_piel", out + f"/{nombre}_piel.png", rough=0.55, normal_path=out + f"/{nombre}_piel_n.png"))
    b["body"].name = nombre + "_cuerpo"
    b_pelo.eye_color(b, r["ojos"], nombre + "_ojos")
    b["eyes"].name = nombre + "_ojos"
    b_pelo.brows(b, r["cejas"][0], nombre + "_cejas", r["cejas"][1])
    head = bone_head(b["arm"], "Head")
    piezas = []
    hat = r.get("sombrero")
    hat_line = None
    if hat:
        fz, bz = HAT_LINES[hat[0]]
        ez, ey = eye_level(b)
        def hat_line(V, fz=fz, bz=bz, ez=ez, ey=ey):
            t = np.clip((V[:, 1] - (ey - 0.03)) / 0.18, 0, 1)
            return V[:, 2] > ez + fz + (bz - fz) * (0.5 - 0.5 * np.cos(t * math.pi))
    pelo = r.get("pelo")
    if pelo:
        style, color = pelo[0], pelo[1]
        cut = hat_line
        if len(pelo) > 2 and pelo[2] == "pelado":
            ez0 = eye_level(b)[0]
            def cut(V):
                bald = V[:, 2] > ez0 + 0.02
                return bald | (hat_line(V) if hat_line else False)
        if style == "rulos":
            piezas.append(b_pelo.curly_hair(b, color, nombre + "_pelo", cut))
        else:
            piezas.append(b_pelo.hair(b, style, color, nombre + "_pelo", cut))
    if r.get("bigote"):
        piezas.append(b_pelo.walrus_mustache(b, r["bigote"], nombre + "_bigote"))
    ropa = [] if r.get("solo_cabeza") else r["ropa"]
    for kind, opts in ropa + ([hat] if hat else []):
        t = time.time()
        g = getattr(b_ropa, kind)(b, {**opts, "name": f"{nombre}_{kind}"}, piezas)
        piezas.append(g)
        print(f"  {kind}: {len(g.data.vertices)} vértices ({time.time() - t:.1f} s)")
    export(out + f"/{nombre}.gltf", [b["arm"], b["body"], b["eyes"], b["brows"]] + piezas)
    print(f"listo {nombre} ({time.time() - t0:.1f} s)")


if __name__ == "__main__":
    for n in sys.argv[1:]:
        armar(n)
