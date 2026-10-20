"""Piel propia: la cara conserva el detalle del modelo base (párpados, labios), el cuerpo queda
parejo (sin músculos pintados) y todo en el tono del personaje, con pecas, rubor y barba de días."""
from blib import *

SKIN_DEFAULT = {"tone": (0.84, 0.62, 0.5), "freckles": 0.0, "stubble": 0.0, "blush": 0.4, "age": 0.0}


def face_landmarks(b):
    eyes = co(b["eyes"])
    left = eyes[eyes[:, 0] > 0].mean(0)
    right = eyes[eyes[:, 0] < 0].mean(0)
    V = co(b["body"])
    wh = group_weights(b["body"], ["Head"])
    head = V[wh > 0.9]
    mid = head[np.abs(head[:, 0]) < 0.01]
    nose = mid[np.argmin(mid[:, 1])]
    return {"eye_l": left, "eye_r": right, "nose": nose, "mouth": nose + np.array([0, 0.012, -0.034]),
            "center": (left + right) * 0.5}


def skin_texture(b, opts, out_png, out_nrm, size=1024, src_tex="T_Superhero_Male_Dark.png", src_nrm="T_Superhero_Male_Normal.png"):
    o = {**SKIN_DEFAULT, **opts}
    body = b["body"]
    wh = group_weights(body, ["Head"])
    wn = group_weights(body, ["neck"])
    lm = face_landmarks(b)
    orig = load_image_np(BASE + src_tex, size)
    orig_n = load_image_np(BASE + src_nrm, size)
    tone = np.array(o["tone"])
    # Tono medio de la piel en la textura original (en la cara), para recolorear.
    tv, tuv = loop_tris(body)
    face_uv = tuv.reshape(-1, 2)[(wh[tv.reshape(-1)] > 0.95)]
    ref = sample_image(orig, face_uv).mean(0)
    rng = np.random.default_rng(5)
    freckles = []
    for _ in range(int(160 * o["freckles"])):
        s = rng.choice([1, -1])
        freckles.append((rng.normal(s * 0.028, 0.016), rng.normal(0.012, 0.012), rng.uniform(0.0008, 0.0016), rng.uniform(0.72, 0.86)))
    nrm_out = {}

    def paint(P, N, A):
        uv = A["uv"]
        face = np.clip((A["wh"][:, 0] - 0.55) / 0.35, 0, 1)
        src = sample_image(orig, uv)
        recol = src / ref * tone
        flat = tone * (0.97 + 0.06 * core.fbm3(P, 0.03, 3, 2))[:, None]
        col = recol * face[:, None] + flat * (1 - face[:, None])
        # Alrededor de la nariz no queda nada más oscuro que la piel en sombra (saca piercings o
        # manchas que trae la textura original).
        near_nose = np.linalg.norm(P - lm["nose"], axis=1) < 0.03
        col[near_nose] = np.maximum(col[near_nose], flat[near_nose] * 0.78)
        # Coordenadas de la cara (x lateral, z alto, adelante = -y).
        q = P - lm["center"]
        front = (-q[:, 1]) > 0.0
        # Rubor en las mejillas y la nariz.
        bl = 0
        for s in (1, -1):
            bl = bl + np.exp(-(((q[:, 0] - s * 0.04) / 0.018) ** 2 + ((q[:, 2] + 0.03) / 0.015) ** 2))
        bl = bl * o["blush"] * 0.3 * front * face
        col = col * (1 - bl[:, None] * np.array([0.0, 0.35, 0.38]))
        for fx, fz, r, k in freckles:
            d2 = ((q[:, 0] - fx) ** 2 + (q[:, 2] - (fz - 0.03)) ** 2) / (r * r)
            m = (d2 < 1) & front & (face > 0.5)
            a = (1 - d2[m]) ** 0.7
            col[m] *= 1 - a[:, None] * (1 - np.array([k, k * 0.9, k * 0.84]))
        if o["stubble"] > 0:
            mz = lm["mouth"][2]
            # Zona de la barba: debajo de los pómulos, por la mandíbula y el bigote; bordes suaves.
            cheek_line = lm["nose"][2] - 0.005 - 0.25 * np.abs(q[:, 0])
            amt = core.smoothstep(cheek_line + 0.01, cheek_line - 0.015, P[:, 2])
            amt *= core.smoothstep(lm["center"][2] - 0.16, lm["center"][2] - 0.12, P[:, 2])
            amt *= core.smoothstep(-0.07, -0.02, -q[:, 1]) * face
            lips = np.exp(-(((P[:, 2] - mz) / 0.007) ** 2 + (q[:, 0] / 0.02) ** 2))
            amt *= (1 - lips) * (1 - core.smoothstep(0.045, 0.06, np.abs(q[:, 0])) * (P[:, 2] > mz - 0.01))
            dots = (core.fbm3(P, 0.0009, 1, 3) > 0.58).astype(float)
            k = o["stubble"] * amt * (0.12 + 0.28 * dots)
            col *= (1 - k)[:, None]
        if o["age"] > 0:
            fore = (q[:, 2] > 0.035) & (q[:, 2] < 0.065) & (np.abs(q[:, 0]) < 0.04) & front
            line = np.abs(np.sin(q[:, 2] / 0.006 * math.pi)) < 0.13
            col[fore & line] *= 1 - 0.16 * o["age"]
        return np.clip(col, 0, 1)

    me = body.data
    tvf = tv.reshape(-1)
    uv_attr = tuv.reshape(-1, 2)
    T = np.arange(len(tvf)).reshape(-1, 3)
    V = co(body)
    Nv = np.zeros(len(me.vertices) * 3)
    me.vertices.foreach_get("normal", Nv)
    Nv = Nv.reshape(-1, 3)
    att, cover = core.raster(uv_attr, T, {"P": V[tvf], "N": Nv[tvf], "uv": uv_attr, "wh": wh[tvf][:, None]}, size)
    img = np.zeros((size, size, 3), np.float32)
    sel = {k: v[cover] for k, v in att.items()}
    img[cover] = paint(sel["P"], sel["N"], sel)
    img = core.dilate(img, cover, 8)
    filled = core.dilate(cover[..., None].repeat(3, 2).astype(np.float32), cover, 8)[..., 0] > 0
    img[~filled] = img[cover].mean(0)
    save_png(img, out_png)
    # Relieve: el de la cara se queda; el resto, liso.
    nimg = np.tile(np.array([0.5, 0.5, 1.0], np.float32), (size, size, 1))
    face = np.zeros((size, size), np.float32)
    face[cover] = np.clip((att["wh"][cover][:, 0] - 0.55) / 0.35, 0, 1)
    face = core.dilate(face[..., None].repeat(3, 2), cover, 8)[..., 0]
    nimg = orig_n * face[..., None] + nimg * (1 - face[..., None])
    save_png(nimg, out_nrm)
    return lm
