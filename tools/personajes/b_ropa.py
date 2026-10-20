"""Ropa en capas, modelada sobre el cuerpo: cada prenda es una malla aparte que sale del cuerpo
(así ya trae los pesos de los huesos y calza justo), cortada con planos limpios, separada del
cuerpo, alisada (la tela no marca músculos), con dobladillos y grosor de tela.
"""
from blib import *
from mathutils.bvhtree import BVHTree


def body_bvh(body):
    V = co(body)
    T = faces(body)
    return BVHTree.FromPolygons([tuple(v) for v in V], [tuple(t) for t in T])


def push_out(o, bvh, min_gap, rounds=3):
    """Que ningún punto de la prenda quede adentro del cuerpo ni demasiado pegado (empuja por la
    normal de la prenda, con tope, y alisa un poco después para no dejar picos)."""
    E = edges(o)
    free = (~boundary_mask(o)).astype(float)
    for _ in range(rounds):
        V = co(o)
        N = vertex_normals(o)
        moved = np.zeros(len(V), bool)
        for i in range(len(V)):
            loc, nrm, idx, dist = bvh.find_nearest(V[i])
            if loc is None:
                continue
            side = float(np.dot(np.array(V[i]) - np.array(loc), np.array(nrm)))
            if side < min_gap:
                push = min(min_gap - side, 0.015)
                dirv = N[i] if float(np.dot(N[i], np.array(nrm))) > 0.2 else np.array(nrm)
                V[i] = V[i] + dirv * push
                moved[i] = True
        V = taubin(V, E, free * 0.6, iters=2)
        set_co(o, V)


def start_garment(b, name):
    g = duplicate(b["body"], name)
    for m in list(g.modifiers):
        if m.type != "ARMATURE":
            g.modifiers.remove(m)
    return g


def neck_hole(g, center_y, rx, ry, z_front, z_back, z_min):
    """Abre el cuello: borra lo que queda adentro de un óvalo alrededor del cuello y acomoda el
    borde sobre el óvalo (con el frente más bajo, como una remera)."""
    V = co(g)
    x, y, z = V[:, 0], V[:, 1], V[:, 2]
    t = np.clip((y - (center_y - ry)) / (2 * ry), 0, 1)        # 0 adelante (-y), 1 atrás
    zc = z_front + (z_back - z_front) * t
    inside = ((x / rx) ** 2 + ((y - center_y) / ry) ** 2 < 1.0) & (z > z_min)
    above = z > zc + 0.0
    delete_verts(g, (inside & above) | (z > z_back + 0.06))
    keep_largest_parts(g)
    # Borde: llevarlo al óvalo.
    V = co(g)
    near_neck = (V[:, 0] / rx) ** 2 + ((V[:, 1] - center_y) / ry) ** 2 < 2.2
    bnd = boundary_mask(g) & (V[:, 2] > z_min) & near_neck
    ang = np.arctan2((V[bnd, 1] - center_y) / ry, V[bnd, 0] / rx)
    V[bnd, 0] = np.cos(ang) * rx
    V[bnd, 1] = center_y + np.sin(ang) * ry
    tt = np.clip((V[bnd, 1] - (center_y - ry)) / (2 * ry), 0, 1)
    V[bnd, 2] = z_front + (z_back - z_front) * (0.5 - 0.5 * np.cos(tt * math.pi))
    set_co(g, V)


def neck_open(g, cy, rx, ry, z_front, z_back):
    V = co(g)
    x, y, z = V[:, 0], V[:, 1], V[:, 2]
    t = np.clip((y - (cy - ry)) / (2 * ry), 0, 1)
    zc = z_front + (z_back - z_front) * (0.5 - 0.5 * np.cos(t * math.pi))
    inside = ((x / rx) ** 2 + ((y - cy) / ry) ** 2) < 1.0
    delete_verts(g, inside & (z > zc))
    keep_largest_parts(g, 200)
    near = lambda P: ((P[:, 0] / (rx * 1.5)) ** 2 + ((P[:, 1] - cy) / (ry * 1.5)) ** 2) < 1.0
    smooth_boundary(g, near, 12, 0.5)


def ease_and_smooth(g, ease_fn, smooth_iters=20, fold_amp=0.0015, seed=0):
    """Separar del cuerpo (holgura), alisar (sin músculos) y unos pliegues suaves."""
    V = co(g)
    N = vertex_normals(g)
    V = V + N * ease_fn(V)[:, None]
    E = edges(g)
    bnd = boundary_mask(g)
    mask = (~bnd).astype(float)
    V = taubin(V, E, mask, iters=smooth_iters)
    set_co(g, V)
    N = vertex_normals(g)
    folds = (core.fbm3(V, 0.07, 3, seed) - 0.5) * 2 * fold_amp
    V = V + N * folds[:, None]
    set_co(g, V)


def hem_bulge(g, select_fn, amount=0.0018, rings=2):
    """Dobladillo: engrosa un poco las primeras vueltas desde el borde."""
    V = co(g)
    bnd = np.nonzero(boundary_mask(g) & select_fn(V))[0]
    if len(bnd) == 0:
        return
    d = ring_distance(g, bnd, rings + 1)
    N = vertex_normals(g)
    k = np.clip(1.0 - d / (rings + 1), 0, 1) ** 0.7
    V = V + N * (amount * k)[:, None]
    set_co(g, V)


def finish_garment(b, g, others, thickness=0.0025, subdiv=1, size=1024, paint=None, rough=0.85, name=None,
                   normal_fn=None, ao=True, decimate=0.5):
    """Grosor de tela, alisado final, UV, sombra de rincones y textura pintada."""
    add_modifier(g, "SOLIDIFY", thickness=thickness, offset=-1.0, use_rim=True, use_even_offset=True)
    if subdiv:
        add_modifier(g, "SUBSURF", levels=subdiv, render_levels=subdiv)
    if decimate < 1.0:
        add_modifier(g, "DECIMATE", ratio=decimate)
    apply_modifiers(g)
    move_armature_last(g)
    smart_uv(g)
    name = name or g.name
    ao_img = bake_ao([b["body"]] + others + [g], g, size=size) if ao else np.ones((size, size), np.float32)

    def p(P, N, A):
        col = paint(P, N, A)
        aov = sample_image(ao_img[..., None].repeat(3, 2), A["uv"])[:, 0]
        return np.clip(col * (0.35 + 0.65 * aov)[:, None], 0, 1)

    tv, tuv = loop_tris(g)
    V = co(g)
    N = vertex_normals(g)
    tvf = tv.reshape(-1)
    uv = tuv.reshape(-1, 2)
    T = np.arange(len(tvf)).reshape(-1, 3)
    att, cover = core.raster(uv, T, {"P": V[tvf], "N": N[tvf], "uv": uv}, size)
    img = np.zeros((size, size, 3), np.float32)
    sel = {k: v[cover] for k, v in att.items()}
    img[cover] = p(sel["P"], sel["N"], sel)
    img = core.dilate(img, cover, 10)
    img[~core.dilate(cover[..., None].repeat(3, 2).astype(np.float32), cover, 10)[..., 0].astype(bool)] = img[cover].mean(0)
    out = OUT + "/" + name + ".png"
    save_png(img, out)
    nrm_path = None
    if normal_fn is not None:
        h = np.zeros((size, size), np.float32)
        h[cover] = normal_fn(sel["P"], sel["N"], sel)
        h = core.dilate(h[..., None].repeat(3, 2), cover, 4)[..., 0]
        gx = np.roll(h, -1, 1) - np.roll(h, 1, 1)
        gy = np.roll(h, -1, 0) - np.roll(h, 1, 0)
        n = np.stack([-gx, gy, np.ones_like(h) * 0.5], -1)
        n /= np.linalg.norm(n, axis=-1, keepdims=True)
        nrm_path = OUT + "/" + name + "_n.png"
        save_png(n * 0.5 + 0.5, nrm_path)
        shrink_png(nrm_path, 512)
    set_material(g, simple_material(name, out, rough=rough, normal_path=nrm_path))
    return g



# ---------------------------------------------------------------- remera

def remera(b, opts, others):
    arm = b["arm"]
    g = start_garment(b, opts.get("name", "remera"))
    pel = bone_head(arm, "pelvis")
    hem_z = pel[2] + 0.025
    ua = bone_head(arm, "upperarm_l")
    la = bone_head(arm, "lowerarm_l")
    hand = bone_head(arm, "hand_l")
    long_sleeve = opts.get("sleeve", 0.45) > 0.9
    sl = opts.get("sleeve", 0.45)
    sleeve_x = ua[0] + (la[0] - ua[0]) * sl * 2 if not long_sleeve else hand[0] - 0.025
    cuts = [((0, 0, hem_z), (0, 0, -1)), ((sleeve_x, 0, 0), (1, 0, 0)), ((-sleeve_x, 0, 0), (-1, 0, 0))]
    bisect_keep(g, cuts)
    keep_largest_parts(g)
    neck = bone_head(arm, "neck_01")
    # Cuello: un óvalo alrededor del cuello, más bajo adelante; el borde se alisa a lo largo.
    bisect_keep(g, [((0, 0, neck[2] + 0.04), (0, 0, 1))])
    neck_open(g, neck[1] - 0.015, opts.get("neck_rx", 0.07), opts.get("neck_ry", 0.07), neck[2] - 0.085, neck[2] - 0.025)
    loose = opts.get("loose", 0.009)
    def ease(V):
        belly = np.exp(-((V[:, 2] - 1.02) / 0.15) ** 2) * (np.abs(V[:, 0]) < 0.2) * 0.005
        sleeve = (np.abs(V[:, 0]) > 0.24) * 0.004
        hang = np.clip((1.12 - V[:, 2]) / 0.12, 0, 1) * 0.009
        return loose + belly + sleeve + hang
    ease_and_smooth(g, ease, 22, 0.0016, seed=3)
    bvh = body_bvh(b["body"])
    push_out(g, bvh, 0.006)
    hem_bulge(g, lambda V: np.ones(len(V), bool), 0.0016, 2)
    color = np.array(opts.get("color", (0.85, 0.42, 0.12)))

    def paint(P, N, A):
        x, y, z = P[:, 0], P[:, 1], P[:, 2]
        col = np.tile(color, (len(P), 1)) * (0.94 + 0.08 * core.fbm3(P, 0.004, 2, 7) + 0.04 * core.fbm3(P, 0.08, 2, 8))[:, None]
        # Costuras: a los costados, en los hombros y los dobladillos (con puntadas).
        torso = np.abs(x) < ua[0] - 0.01
        th = np.arctan2(-(y - 0.01), np.abs(x))
        rr = np.hypot(np.abs(x), y - 0.01)
        side = torso & (np.abs(th) * rr < 0.0014) & (z < ua[2] - 0.06)
        top = (np.abs(x) > 0.08) & (N[:, 2] > 0.6) & (np.abs(y - 0.012) < 0.0014)
        col[side | top] *= 0.8
        def stitches(dist, along):
            return (np.abs(dist) < 0.0009) & (np.sin(along / 0.004 * math.pi) > 0.1)
        st = stitches(z - (hem_z + 0.016), x * 3 + y) | stitches(np.abs(x) - (sleeve_x - 0.016), z * 3 + y)
        col[st] *= 0.72
        # Cuello acanalado.
        rib = (z > neck[2] - 0.095) & (np.hypot(x / 0.066, (y - neck[1] + 0.012) / 0.058) < 1.35)
        col[rib] *= (0.88 + 0.1 * (np.sin(np.arctan2(y - neck[1], x) * 90) > 0))[rib, None]
        # Logo en el pecho: una caja de mudanza y "MUDANZAS TRUCHAS".
        if opts.get("logo", True):
            lc = np.array([0.085, 0, ua[2] - 0.07])
            front = y < -0.03
            u = (x - lc[0]) / 0.045
            v = (z - lc[2]) / 0.045
            disc = front & (u * u + v * v < 1)
            col[disc] = (0.95, 0.93, 0.86)
            box = disc & (np.abs(u) < 0.48) & (v > -0.42) & (v < 0.3)
            col[box] = (0.55, 0.34, 0.18)
            tape = box & (np.abs(u) < 0.07)
            col[tape] = (0.85, 0.75, 0.5)
            lid = disc & (np.abs(u) < 0.55) & (v >= 0.3) & (v < 0.42)
            col[lid] = (0.45, 0.27, 0.14)
            ring = front & (np.abs(np.sqrt(u * u + v * v) - 1) < 0.07)
            col[ring] = color * 0.55
        return col

    def height(P, N, A):
        return core.fbm3(P, 0.002, 1, 9) * 0.6

    return finish_garment(b, g, others, 0.0025, 1, 1024, paint, 0.9, normal_fn=height)


# ---------------------------------------------------------------- jean

def jean(b, opts, others):
    arm = b["arm"]
    g = start_garment(b, opts.get("name", "jean"))
    pel = bone_head(arm, "pelvis")
    foot = bone_head(arm, "foot_l")
    calf = bone_head(arm, "calf_l")
    top_z = pel[2] + 0.07
    cuff_z = foot[2] + 0.035
    hand = bone_head(arm, "hand_l")
    bisect_keep(g, [((0, 0, top_z), (0, 0, 1)), ((0, 0, cuff_z), (0, 0, -1))])
    # Sacar los brazos y manos que quedaron a la altura de la cintura.
    V = co(g)
    wa = group_weights(g, ["upperarm", "lowerarm", "hand", "index", "middle", "ring", "pinky", "thumb"])
    delete_verts(g, wa > 0.3)
    keep_largest_parts(g, 200)
    loose = opts.get("loose", 0.008)
    def ease(V):
        flare = np.clip((calf[2] + 0.1 - V[:, 2]) / 0.45, 0, 1) * 0.012
        seat = np.exp(-((V[:, 2] - pel[2] + 0.05) / 0.1) ** 2) * (V[:, 1] > 0) * 0.004
        return loose + flare + seat
    ease_and_smooth(g, ease, 20, 0.0014, seed=5)
    push_out(g, body_bvh(b["body"]), 0.005)
    V = co(g)
    # Pliegues en la rodilla y abajo (el jean se junta en el tobillo).
    N = vertex_normals(g)
    knee = np.exp(-((V[:, 2] - calf[2]) / 0.05) ** 2) * (V[:, 1] > -0.2)
    ank = np.exp(-((V[:, 2] - cuff_z - 0.06) / 0.06) ** 2)
    rip = np.sin(V[:, 2] / 0.018 * math.pi + core.fbm3(V, 0.03, 2, 1) * 4)
    V = V + N * ((knee * 0.0012 + ank * 0.002) * rip)[:, None]
    set_co(g, V)
    hem_bulge(g, lambda V: V[:, 2] > top_z - 0.01, 0.0022, 3)       # pretina
    hem_bulge(g, lambda V: V[:, 2] < cuff_z + 0.01, 0.0035, 3)      # botamanga doblada
    color = np.array(opts.get("color", (0.17, 0.25, 0.42)))
    stitch_c = np.array([0.82, 0.55, 0.22])
    th, ca, fo = bone_head(arm, "thigh_l"), bone_head(arm, "calf_l"), bone_head(arm, "foot_l")

    def leg_center(z):
        """Centro de la pierna (x positivo, y) a cada altura."""
        t1 = np.clip((th[2] - z) / (th[2] - ca[2]), 0, 1)
        t2 = np.clip((ca[2] - z) / (ca[2] - fo[2]), 0, 1)
        cx = np.where(z > ca[2], th[0] + (ca[0] - th[0]) * t1, ca[0] + (fo[0] - ca[0]) * t2)
        cy = np.where(z > ca[2], th[1] + (ca[1] - th[1]) * t1, ca[1] + (fo[1] - ca[1]) * t2)
        return cx, cy

    def paint(P, N, A):
        x, y, z = P[:, 0], P[:, 1], P[:, 2]
        cx, cy = leg_center(z)
        # Tela: hilos verticales (ruido estirado) y desgaste (más claro en muslos, rodillas y cola).
        col = np.tile(color, (len(P), 1)) * (0.9 + 0.1 * core.fbm3(P * np.array([1, 1, 0.12]), 0.0035, 2, 4)
                                             + 0.06 * core.fbm3(P, 0.03, 2, 5))[:, None]
        fade = np.exp(-((z - 0.75) / 0.12) ** 2) * (y < 0) * 0.25 + np.exp(-((z - calf[2]) / 0.05) ** 2) * (y < 0) * 0.2
        fade += np.exp(-((z - pel[2] + 0.06) / 0.08) ** 2) * (y > 0.04) * 0.2
        col = col + (np.array([0.55, 0.62, 0.75]) - col) * (fade * (0.6 + 0.4 * core.fbm3(P, 0.02, 2, 6)))[:, None]
        def stitch_line(mask, along):
            return mask & (np.sin(along / 0.0035 * math.pi) > 0.15)
        # Costura de afuera (al costado de cada pierna) y de adentro: por el ángulo alrededor de la pierna.
        ang = np.arctan2(y - cy, np.abs(x) - cx)
        rr = np.hypot(y - cy, np.abs(x) - cx)
        arc_out = np.abs(ang) * rr
        arc_in = (math.pi - np.abs(ang)) * rr
        legs = z < pel[2] + 0.02
        side = legs & (arc_out < 0.0022)
        inner = (z < pel[2] - 0.09) & (arc_in < 0.0022)
        col[side | inner] *= 0.8
        col[stitch_line(legs & (np.abs(arc_out - 0.0032) < 0.0007), z)] = stitch_c
        col[stitch_line((z < pel[2] - 0.09) & (np.abs(arc_in - 0.0032) < 0.0007), z)] = stitch_c
        # Pretina y botamanga con puntadas.
        col[stitch_line(np.abs(z - (top_z - 0.004)) < 0.0008, x * 2 + y)] = stitch_c
        col[stitch_line(np.abs(z - (top_z - 0.036)) < 0.0008, x * 2 + y)] = stitch_c
        col[stitch_line(np.abs(z - (cuff_z + 0.03)) < 0.0008, x * 2 + y)] = stitch_c
        # Bragueta (la J) y el botón.
        fly = (y < -0.05) & (z < top_z - 0.04) & (z > pel[2] - 0.12)
        jline = fly & (np.abs(x - 0.03) < 0.0009) | (fly & (np.abs(np.hypot(x - 0.012, z - (pel[2] - 0.1)) - 0.018) < 0.0009) & (z < pel[2] - 0.1))
        col[stitch_line(jline, z + x)] = stitch_c
        btn = (y < -0.06) & (np.hypot(x, z - (top_z - 0.02)) < 0.008)
        col[btn] = (0.62, 0.45, 0.25)
        # Bolsillos de adelante (la curva) y de atrás (el contorno).
        for s in (1, -1):
            fp = (y < -0.02) & (np.abs(np.hypot(x - s * 0.15, z - (top_z + 0.0)) - 0.075) < 0.001) & (z < top_z - 0.035)
            col[stitch_line(fp, z + x)] = stitch_c
            bp_c = np.array([s * 0.075, pel[2] - 0.045])
            u = (x - bp_c[0]) / 0.06
            v = (z - bp_c[1]) / 0.07
            pocket = (y > 0.04) & (np.abs(u) < 1) & (v < 1) & (v > -1 + 0.6 * (1 - np.abs(u)) ** 0) & (v > -1)
            edge = pocket & ((np.abs(u) > 0.93) | (v > 0.9) | (v < -0.92 + 0.0))
            col[stitch_line(edge, x + z)] = stitch_c
            col[pocket] *= 0.97
        return col

    def height(P, N, A):
        return core.fbm3(P * np.array([1, 1, 0.12]), 0.0035, 2, 4)

    g = finish_garment(b, g, others, 0.003, 1, 1024, paint, 0.92, normal_fn=height)
    return g


# ---------------------------------------------------------------- zapatillas

def zapatillas(b, opts, others):
    arm = b["arm"]
    color = np.array(opts.get("color", (0.85, 0.85, 0.85)))
    accent = np.array(opts.get("accent", (0.9, 0.35, 0.15)))
    sole_c = np.array(opts.get("sole", (0.95, 0.95, 0.93)))
    g = start_garment(b, opts.get("name", "zapatillas"))
    foot = bone_head(arm, "foot_l")
    top = foot[2] + 0.03
    bisect_keep(g, [((0, 0, top), (0, 0, 1))])
    keep_largest_parts(g, 80)
    def ease(V):
        return 0.006 + np.clip((0.04 - V[:, 2]) / 0.04, 0, 1) * 0.008
    ease_and_smooth(g, ease, 30, 0.0, seed=1)
    V = co(g)
    # Planta plana y apoyada en el piso; la suela es la franja de abajo.
    V[:, 2] = np.maximum(V[:, 2], 0.0)
    low = V[:, 2] < 0.025
    set_co(g, V)
    hem_bulge(g, lambda V: V[:, 2] > top - 0.01, 0.004, 3)     # el acolchado del tobillo
    ball = bone_head(arm, "ball_l")

    def paint(P, N, A):
        x, y, z = P[:, 0], P[:, 1], P[:, 2]
        col = np.tile(color, (len(P), 1)) * (0.95 + 0.06 * core.fbm3(P, 0.003, 2, 2))[:, None]
        fwd = -y
        # Puntera y talón de otro tono.
        toe = fwd > (-ball[1] + 0.02)
        col[toe] = color * 0.92 + accent * 0.08
        heel = fwd < (-foot[1] - 0.06)
        col[heel & (z > 0.03)] = accent
        # Una franja propia al costado (un rayo).
        s = np.sign(x)
        outer = (x * s > 0.09 + 0.0)
        ang = (fwd - (-foot[1] + 0.0)) * 8
        stripe = (np.abs(z - (0.045 + 0.02 * np.sin(ang))) < 0.006) & (fwd > -foot[1] - 0.04) & (fwd < -ball[1] + 0.01) & (np.abs(N[:, 0]) > 0.5)
        col[stripe] = accent
        # Cordones arriba y ojales.
        laces = (N[:, 2] > 0.55) & (fwd > -foot[1] - 0.0) & (fwd < -ball[1] - 0.005) & (np.abs(x - np.sign(x) * 0.09) < 0.02)
        lace_band = laces & (np.sin((fwd) / 0.011 * math.pi) > 0.2)
        col[laces] = color * 0.8
        col[lace_band] = (0.97, 0.97, 0.97)
        # Suela: blanca con una línea gris y el piso de goma.
        col[z < 0.028] = sole_c
        col[(z < 0.03) & (z > 0.026)] = sole_c * 0.7
        col[z < 0.007] = (0.35, 0.3, 0.26)
        return col

    def height(P, N, A):
        z = P[:, 2]
        tread = (np.sin(P[:, 1] / 0.004 * math.pi) > 0) * (z < 0.007)
        return 0.5 + 0.4 * tread

    return finish_garment(b, g, others, 0.004, 1, 512, paint, 0.6, normal_fn=height)


# ---------------------------------------------------------------- gorros (salen de la cabeza: calzan justo)

def head_piece(b, name, brim_front, brim_back, ease_v, crown=0.0):
    """Gorro que sale de la cabeza. brim_front / brim_back: altura del borde adelante y en la nuca,
    medida desde la altura de los ojos."""
    arm = b["arm"]
    g = start_garment(b, name)
    wh = group_weights(g, ["Head"])
    head = bone_head(arm, "Head")
    ez, ey = eye_level(b)
    V = co(g)
    # Línea del borde: más alta en la frente, más baja en la nuca.
    t = np.clip((V[:, 1] - (ey - 0.03)) / 0.18, 0, 1)
    line = ez + brim_front + (brim_back - brim_front) * (0.5 - 0.5 * np.cos(t * math.pi))
    delete_verts(g, (wh < 0.5) | (V[:, 2] < line))
    keep_largest_parts(g, 100)
    smooth_boundary(g, lambda P: np.ones(len(P), bool), 16, 0.5)
    V = co(g)
    N = vertex_normals(g)
    top = np.clip((V[:, 2] - ez) / 0.12, 0, 1)
    V = V + N * (ease_v + crown * top)[:, None]
    set_co(g, V)
    E = edges(g)
    V = taubin(V, E, (~boundary_mask(g)).astype(float), iters=12)
    set_co(g, V)
    return g


def gorro_lana(b, opts, others):
    g = head_piece(b, opts.get("name", "gorro_lana"), 0.035, -0.06, 0.014, crown=0.012)
    hem_bulge(g, lambda V: np.ones(len(V), bool), 0.005, 5)       # el borde doblado
    color = np.array(opts.get("color", (0.15, 0.15, 0.17)))
    head = bone_head(b["arm"], "Head")

    def paint(P, N, A):
        x, y, z = P[:, 0], P[:, 1], P[:, 2]
        ang = np.arctan2(y - head[1], x)
        rib = np.sin(ang * 60) > 0
        col = np.tile(color, (len(P), 1)) * np.where(rib, 1.0, 0.82)[:, None]
        col *= (0.92 + 0.12 * core.fbm3(P, 0.002, 1, 3))[:, None]
        return col

    def height(P, N, A):
        ang = np.arctan2(P[:, 1] - head[1], P[:, 0])
        return 0.5 + 0.5 * np.sin(ang * 60)

    return finish_garment(b, g, others, 0.004, 1, 512, paint, 0.95, normal_fn=height)


# ---------------------------------------------------------------- utilidades para piezas agregadas

def new_mesh_object(name, verts, faces_, b, bone_weights=None):
    me = bpy.data.meshes.new(name)
    me.from_pydata([tuple(v) for v in verts], [], [tuple(f) for f in faces_])
    me.update()
    o = bpy.data.objects.new(name, me)
    link(o)
    o.parent = b["arm"]
    m = o.modifiers.new("esqueleto", "ARMATURE")
    m.object = b["arm"]
    for p in me.polygons:
        p.use_smooth = True
    if bone_weights:
        for bone, w in bone_weights.items():
            vg = o.vertex_groups.new(name=bone)
            vg.add(list(range(len(verts))), w, "REPLACE")
    return o


def copy_weights_nearest(src, dst):
    """Copia los pesos de huesos del vértice más cercano de `src` a cada vértice de `dst`."""
    from mathutils.kdtree import KDTree
    Vs = co(src)
    kd = KDTree(len(Vs))
    for i, v in enumerate(Vs):
        kd.insert(v, i)
    kd.balance()
    groups = {g.index: g.name for g in src.vertex_groups}
    for g in list(dst.vertex_groups):
        dst.vertex_groups.remove(g)
    dg = {}
    for i, v in enumerate(co(dst)):
        _, j, _ = kd.find(v)
        for ge in src.data.vertices[j].groups:
            name = groups[ge.group]
            if name not in dg:
                dg[name] = dst.vertex_groups.new(name=name)
            dg[name].add([i], ge.weight, "REPLACE")


def join_into(target, others):
    select_only([target] + others)
    bpy.context.view_layer.objects.active = target
    bpy.ops.object.join()
    return target


def extrude_boundary(o, move_fn, select_fn=None):
    """Extruye los bordes abiertos y mueve los vértices nuevos con move_fn(co) -> co nuevo."""
    bm = bmesh.new()
    bm.from_mesh(o.data)
    edges_ = [e for e in bm.edges if e.is_boundary and (select_fn is None or all(select_fn(np.array(v.co)) for v in e.verts))]
    ret = bmesh.ops.extrude_edge_only(bm, edges=edges_)
    for v in ret["geom"]:
        if isinstance(v, bmesh.types.BMVert):
            v.co = move_fn(np.array(v.co))
    bm.to_mesh(o.data)
    bm.free()
    o.data.update()


def grid_strip(name, rows_pts, b, weights):
    """Superficie a partir de filas de puntos (cada fila, la misma cantidad)."""
    R = len(rows_pts)
    C = len(rows_pts[0])
    verts = [p for row in rows_pts for p in row]
    faces_ = []
    for r in range(R - 1):
        for c in range(C - 1):
            a = r * C + c
            faces_.append((a, a + 1, a + C + 1, a + C))
    return new_mesh_object(name, verts, faces_, b, weights)


def decal_text(text, w=256, h=128, color=(0, 0, 0)):
    from PIL import Image, ImageDraw, ImageFont
    im = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(im)
    font = None
    for f in ["/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"]:
        if os.path.exists(f):
            font = ImageFont.truetype(f, int(h * 0.62))
    d.text((w / 2, h / 2), text, fill=255, anchor="mm", font=font)
    return np.asarray(im, np.float32) / 255.0


# ---------------------------------------------------------------- más gorros

def _front_brim(g, head):
    V = co(g)
    bnd = boundary_mask(g)
    P = V[bnd & (V[:, 1] < head[1] - 0.02)]
    return P[np.argsort(P[:, 0])]


def gorra(b, opts, others):
    head = bone_head(b["arm"], "Head")
    g = head_piece(b, opts.get("name", "gorra"), 0.05, -0.025, 0.011, crown=0.006)
    hem_bulge(g, lambda V: np.ones(len(V), bool), 0.0018, 2)
    brim = _front_brim(g, head)
    brim = brim[np.abs(brim[:, 0]) < 0.09]
    xm = min(-brim[:, 0].min(), brim[:, 0].max()) * 0.92
    xs = np.linspace(-xm, xm, 17)
    by = np.interp(xs, brim[:, 0], brim[:, 1])
    bz = np.interp(xs, brim[:, 0], brim[:, 2])
    rows = []
    for k in range(6):
        v = k / 5
        depth = 0.075 * np.sqrt(np.clip(1 - (xs / (xm * 1.02)) ** 2, 0, 1)) * v
        rows.append([(x, yy - depth[i] - 0.002, zz - 0.008 * v * v - 0.002 - 0.008 * (xs[i] / xm) ** 2 * v)
                     for i, (x, yy, zz) in enumerate(zip(xs, by, bz))])
    visor = grid_strip(opts.get("name", "gorra") + "_visera", rows, b, {"Head": 1.0})
    for vg in list(g.vertex_groups):
        if vg.name != "Head":
            g.vertex_groups.remove(vg)
    g = join_into(g, [visor])
    color = np.array(opts.get("color", (0.85, 0.72, 0.18)))
    logo = decal_text(opts.get("logo", "MT"))

    def paint(P, N, A):
        x, y, z = P[:, 0], P[:, 1], P[:, 2]
        col = np.tile(color, (len(P), 1)) * (0.94 + 0.08 * core.fbm3(P, 0.003, 2, 4))[:, None]
        ang = np.arctan2(-(y - head[1]), x)
        crown = y > head[1] - 0.105
        seam = crown & (np.abs(((ang + math.pi) % (math.pi / 3)) - math.pi / 6) < 0.012) & (z > head[2] + 0.12)
        col[seam] *= 0.75
        top = np.hypot(x, y - head[1] - 0.005) < 0.008
        col[top & (z > head[2] + 0.2)] = color * 0.7
        # Logo al frente.
        u = (x + 0.035) / 0.07
        v = 1 - (z - (eye_level(b)[0] + 0.062)) / 0.035
        front = (y < head[1] - 0.06) & (u > 0) & (u < 1) & (v > 0) & (v < 1) & (N[:, 1] < -0.3)
        if front.any():
            lu = np.clip((u[front] * logo.shape[1]).astype(int), 0, logo.shape[1] - 1)
            lv = np.clip((v[front] * logo.shape[0]).astype(int), 0, logo.shape[0] - 1)
            a = logo[lv, lu][:, None]
            col[front] = col[front] * (1 - a) + np.array([0.95, 0.95, 0.93]) * a
        under = (y < head[1] - 0.08) & (N[:, 2] < -0.5)
        col[under] = color * 0.55
        return col

    return finish_garment(b, g, others, 0.0035, 1, 512, paint, 0.85)


def casco_obra(b, opts, others):
    head = bone_head(b["arm"], "Head")
    g = head_piece(b, opts.get("name", "casco"), 0.05, -0.02, 0.026, crown=0.016)
    V = co(g)
    set_co(g, taubin(V, edges(g), (~boundary_mask(g)).astype(float), iters=25))

    def out(p):
        d = np.array([p[0], p[1] - head[1], 0.0])
        d /= max(np.linalg.norm(d), 1e-6)
        w = 0.022 + 0.022 * max(0.0, -d[1])
        return p + d * w + np.array([0, 0, -0.007])
    extrude_boundary(g, out)
    color = np.array(opts.get("color", (0.95, 0.75, 0.1)))

    def paint(P, N, A):
        x, y, z = P[:, 0], P[:, 1], P[:, 2]
        col = np.tile(color, (len(P), 1)) * (0.97 + 0.04 * core.fbm3(P, 0.02, 2, 9))[:, None]
        ridge = (np.abs(x) < 0.012) & (z > head[2] + 0.14)
        col[ridge] = color * 1.08
        col[(np.abs(np.abs(x) - 0.012) < 0.0015) & (z > head[2] + 0.14)] = color * 0.7
        return np.clip(col, 0, 1)

    return finish_garment(b, g, others, 0.003, 1, 512, paint, 0.35)


def piluso(b, opts, others):
    head = bone_head(b["arm"], "Head")
    g = head_piece(b, opts.get("name", "piluso"), 0.045, -0.035, 0.016, crown=0.008)

    def out(p):
        d = np.array([p[0], p[1] - head[1], 0.0])
        d /= max(np.linalg.norm(d), 1e-6)
        return p + d * 0.04 + np.array([0, 0, -0.03])
    extrude_boundary(g, out)
    color = np.array(opts.get("color", (0.55, 0.6, 0.4)))

    def paint(P, N, A):
        z = P[:, 2]
        col = np.tile(color, (len(P), 1)) * (0.93 + 0.1 * core.fbm3(P, 0.003, 2, 2))[:, None]
        rings = (np.abs(np.sin((z - head[2]) / 0.006 * math.pi)) < 0.12) & (z < head[2] + 0.11)
        col[rings] *= 0.8
        return col

    return finish_garment(b, g, others, 0.003, 1, 512, paint, 0.9)


def gorro_dormir(b, opts, others):
    head = bone_head(b["arm"], "Head")
    name = opts.get("name", "gorro_dormir")
    g = head_piece(b, name, 0.045, -0.055, 0.012, crown=0.006)
    hem_bulge(g, lambda V: np.ones(len(V), bool), 0.007, 4)
    # La punta: anillos a lo largo de una curva que se cae para atrás.
    top = co(g)[np.argmax(co(g)[:, 2])]
    rings = []
    n = 16
    for k in range(10):
        t = k / 9
        c = top + np.array([0.015 * t, 0.03 * t + 0.13 * t * t, 0.07 * t - 0.2 * t * t]) + np.array([0, 0.012, -0.03])
        r = 0.068 * (1 - t) ** 0.8 + 0.009
        rings.append([tuple(c + np.array([math.cos(a) * r, math.sin(a) * r * 0.9, 0.0])) for a in np.linspace(0, 2 * math.pi, n, endpoint=False)])
    verts = [p for ring in rings for p in ring]
    faces_ = []
    for k in range(len(rings) - 1):
        for i in range(n):
            a = k * n + i
            b2 = k * n + (i + 1) % n
            faces_.append((a, b2, b2 + n, a + n))
    tip = new_mesh_object(name + "_punta", verts, faces_, b, {"Head": 1.0})
    select_only([tip])
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.normals_make_consistent(inside=False)
    bpy.ops.object.mode_set(mode="OBJECT")
    end = np.array(rings[-1]).mean(0)
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.024, location=tuple(end), segments=16, ring_count=10)
    pom = bpy.context.active_object
    pom.parent = b["arm"]
    vg = pom.vertex_groups.new(name="Head")
    vg.add(list(range(len(pom.data.vertices))), 1.0, "REPLACE")
    for vg2 in list(g.vertex_groups):
        if vg2.name != "Head":
            g.vertex_groups.remove(vg2)
    g = join_into(g, [tip, pom])
    color = np.array(opts.get("color", (0.45, 0.62, 0.82)))

    def paint(P, N, A):
        z = P[:, 2]
        col = np.tile(color, (len(P), 1)) * (0.92 + 0.12 * core.fbm3(P, 0.003, 2, 5))[:, None]
        brim = z < head[2] + 0.15
        col[brim] = np.array([0.9, 0.9, 0.92]) * (0.85 + 0.2 * core.fbm3(P[brim], 0.002, 2, 6))[:, None]
        pomm = np.linalg.norm(P - end, axis=1) < 0.03
        col[pomm] = np.array([0.93, 0.93, 0.95]) * (0.8 + 0.25 * core.fbm3(P[pomm], 0.002, 2, 7))[:, None]
        return col

    return finish_garment(b, g, others, 0.003, 1, 512, paint, 0.95)


# ---------------------------------------------------------------- camisa (con cuello, botones y bolsillo)

def camisa(b, opts, others):
    arm = b["arm"]
    name = opts.get("name", "camisa")
    g = start_garment(b, name)
    pel = bone_head(arm, "pelvis")
    hem_z = pel[2] + opts.get("hem", 0.0)
    ua, la, hand = bone_head(arm, "upperarm_l"), bone_head(arm, "lowerarm_l"), bone_head(arm, "hand_l")
    sl = opts.get("sleeve", 0.5)
    sleeve_x = ua[0] + (la[0] - ua[0]) * sl * 2 if sl < 0.95 else hand[0] - 0.03
    bisect_keep(g, [((0, 0, hem_z), (0, 0, -1)), ((sleeve_x, 0, 0), (1, 0, 0)), ((-sleeve_x, 0, 0), (-1, 0, 0))])
    keep_largest_parts(g)
    neck = bone_head(arm, "neck_01")
    bisect_keep(g, [((0, 0, neck[2] + 0.04), (0, 0, 1))])
    neck_open(g, neck[1] - 0.012, 0.072, 0.07, neck[2] - 0.075, neck[2] - 0.025)
    # Escote en V adelante.
    V = co(g)
    vz = neck[2] - opts.get("v_depth", 0.14)
    vcut = (V[:, 1] < neck[1] - 0.03) & (V[:, 2] > vz) & (np.abs(V[:, 0]) < (V[:, 2] - vz) * 0.45)
    delete_verts(g, vcut)
    keep_largest_parts(g, 200)
    smooth_boundary(g, lambda P: P[:, 2] > vz - 0.01, 10, 0.5)
    loose = opts.get("loose", 0.011)
    def ease(V):
        belly = np.exp(-((V[:, 2] - 1.02) / 0.15) ** 2) * (np.abs(V[:, 0]) < 0.2) * 0.006
        hang = np.clip((1.12 - V[:, 2]) / 0.12, 0, 1) * 0.01
        return loose + belly + hang + (np.abs(V[:, 0]) > 0.24) * 0.005
    ease_and_smooth(g, ease, 22, 0.0018, seed=11)
    push_out(g, body_bvh(b["body"]), 0.007)
    hem_bulge(g, lambda V: np.ones(len(V), bool), 0.0015, 2)
    # Solapas: las primeras vueltas desde el escote, copiadas encima y dobladas hacia afuera.
    V = co(g)
    bnd = np.nonzero(boundary_mask(g) & (V[:, 2] > vz - 0.01))[0]
    d = ring_distance(g, bnd, 4)
    collar = duplicate(g, name + "_cuello")
    delete_verts(collar, d > 3)
    keep_largest_parts(collar, 20)
    Vc = co(collar)
    Nc = vertex_normals(collar)
    set_co(collar, Vc + Nc * 0.004)
    # Bolsillo en el pecho (un parche encima).
    pocket = duplicate(g, name + "_bolsillo")
    Vp = co(pocket)
    pc = np.array([0.08, 0, ua[2] - 0.075])
    inside = (Vp[:, 1] < -0.04) & (np.abs(Vp[:, 0] - pc[0]) < 0.045) & (np.abs(Vp[:, 2] - pc[2]) < 0.05)
    delete_verts(pocket, ~inside)
    keep_largest_parts(pocket, 4)
    Vp = co(pocket)
    set_co(pocket, Vp + vertex_normals(pocket) * 0.0025)
    # Botones sobre la línea del frente.
    bvh_g = BVHTree.FromPolygons([tuple(v) for v in co(g)], [tuple(t) for t in faces(g)])
    btn = []
    for k in range(6):
        z = vz - 0.02 - k * 0.075
        if z < hem_z + 0.03:
            break
        hit = bvh_g.ray_cast((0.0, -0.5, z), (0, 1, 0))
        if hit[0] is None:
            continue
        p = np.array(hit[0])
        bpy.ops.mesh.primitive_cylinder_add(vertices=12, radius=0.0065, depth=0.003, location=tuple(p + np.array([0, -0.0035, 0])),
                                            rotation=(math.pi / 2, 0, 0))
        btn.append(bpy.context.active_object)
    for o in [collar, pocket] + btn:
        if o.type == "MESH" and o not in (collar, pocket):
            o.parent = b["arm"]
            mm = o.modifiers.new("esqueleto", "ARMATURE")
            mm.object = b["arm"]
        copy_weights_nearest(g, o)
    g = join_into(g, [collar, pocket] + btn)
    pattern = opts.get("pattern", "liso")
    color = np.array(opts.get("color", (0.75, 0.2, 0.15)))
    color2 = np.array(opts.get("color2", (0.12, 0.12, 0.14)))
    piping = np.array(opts.get("piping", color * 0.6))

    def paint(P, N, A):
        x, y, z = P[:, 0], P[:, 1], P[:, 2]
        base = np.tile(color, (len(P), 1))
        arm_ = np.abs(x) > ua[0] - 0.01
        if pattern == "cuadros":
            # Cuadros escoceses (franela): bandas en las dos direcciones.
            u = np.where(arm_, np.arctan2(y, z - ua[2]) * 0.05, x)
            v = np.where(arm_, np.abs(x), z)
            bu = (np.sin(u / 0.012 * math.pi) > 0.35).astype(float)
            bv = (np.sin(v / 0.012 * math.pi) > 0.35).astype(float)
            thin = ((np.abs(np.sin(u / 0.006 * math.pi)) < 0.08) | (np.abs(np.sin(v / 0.006 * math.pi)) < 0.08)).astype(float)
            k = np.clip(bu * 0.5 + bv * 0.5, 0, 1)
            base = base * (1 - k)[:, None] + color2 * k[:, None]
            base = base * (1 - thin * 0.25)[:, None] + np.array([0.9, 0.85, 0.6]) * (thin * 0.2)[:, None]
        elif pattern == "rayas":
            th = np.where(arm_, np.arctan2(y, z - ua[2]) * 0.05, np.arctan2(-(y - 0.01), x) * 0.17)
            st = (np.sin(th / 0.008 * math.pi) > 0.3)[:, None]
            base = np.where(st, color2, base)
        col = base * (0.94 + 0.08 * core.fbm3(P, 0.004, 2, 3))[:, None]
        # Tapeta de los botones, ribetes del cuello y de las mangas.
        placket = (np.abs(x) < 0.016) & (y < -0.04) & (z < vz)
        col[placket] *= 0.92
        col[(np.abs(np.abs(x) - 0.016) < 0.0012) & (y < -0.04) & (z < vz)] *= 0.7
        btnm = (np.abs(x) < 0.0075) & (y < -0.06) & (np.abs(((vz - 0.02 - z) % 0.075)) < 0.007) & (z < vz)
        col[btnm] = np.array(opts.get("buttons", (0.92, 0.9, 0.85)))
        cuff = arm_ & (np.abs(x) > sleeve_x - 0.02)
        col[cuff] = piping * 0.9 + col[cuff] * 0.1 if opts.get("piping") is not None else col[cuff] * 0.9
        pk = (y < -0.04) & (np.abs(x - pc[0]) < 0.045) & (np.abs(z - pc[2]) < 0.05)
        pk_edge = pk & ((np.abs(np.abs(x - pc[0]) - 0.043) < 0.0015) | (np.abs(z - (pc[2] + 0.048)) < 0.002))
        col[pk_edge] = piping if opts.get("piping") is not None else col[pk_edge] * 0.75
        return col

    return finish_garment(b, g, others, 0.0022, 1, 1024, paint, 0.88)


# ---------------------------------------------------------------- pijama (pantalón) y pantuflas

def pantalon_pijama(b, opts, others):
    arm = b["arm"]
    name = opts.get("name", "pantalon_pijama")
    g = start_garment(b, name)
    pel = bone_head(arm, "pelvis")
    foot = bone_head(arm, "foot_l")
    top_z = pel[2] + 0.08
    cuff_z = foot[2] + 0.02
    bisect_keep(g, [((0, 0, top_z), (0, 0, 1)), ((0, 0, cuff_z), (0, 0, -1))])
    wa = group_weights(g, ["upperarm", "lowerarm", "hand", "index", "middle", "ring", "pinky", "thumb"])
    delete_verts(g, wa > 0.3)
    keep_largest_parts(g, 200)
    def ease(V):
        return 0.013 + np.clip((0.6 - V[:, 2]) / 0.5, 0, 1) * 0.012
    ease_and_smooth(g, ease, 22, 0.0022, seed=21)
    push_out(g, body_bvh(b["body"]), 0.008)
    V = co(g)
    N = vertex_normals(g)
    gather = np.clip((V[:, 2] - (top_z - 0.04)) / 0.04, 0, 1)
    ang = np.arctan2(V[:, 1], V[:, 0])
    V = V + N * (gather * 0.002 * np.sin(ang * 70))[:, None]
    set_co(g, V)
    hem_bulge(g, lambda V: V[:, 2] > top_z - 0.01, 0.003, 4)
    hem_bulge(g, lambda V: V[:, 2] < cuff_z + 0.01, 0.002, 2)
    a, c2 = np.array(opts.get("color", (0.45, 0.62, 0.82))), np.array(opts.get("color2", (0.85, 0.87, 0.9)))
    th, ca, fo = bone_head(arm, "thigh_l"), bone_head(arm, "calf_l"), bone_head(arm, "foot_l")

    def paint(P, N, A):
        x, y, z = P[:, 0], P[:, 1], P[:, 2]
        cx = np.where(z > ca[2], th[0] + (ca[0] - th[0]) * np.clip((th[2] - z) / (th[2] - ca[2]), 0, 1), ca[0])
        ang = np.arctan2(y, np.abs(x) - cx)
        hips = z > pel[2] - 0.08
        u = np.where(hips, np.arctan2(-(y - 0.01), x) * 0.17, ang * 0.06)
        st = (np.sin(u / 0.008 * math.pi) > 0.3)[:, None]
        col = np.where(st, c2, a) * (0.94 + 0.08 * core.fbm3(P, 0.004, 2, 13))[:, None]
        col[z > top_z - 0.035] = a * 0.8
        col[z < cuff_z + 0.03] = a * 0.8
        return col

    return finish_garment(b, g, others, 0.0025, 1, 1024, paint, 0.9)


def pantuflas(b, opts, others):
    arm = b["arm"]
    name = opts.get("name", "pantuflas")
    g = start_garment(b, name)
    foot = bone_head(arm, "foot_l")
    top = foot[2] - 0.015
    bisect_keep(g, [((0, 0, top), (0, 0, 1))])
    keep_largest_parts(g, 60)
    ease_and_smooth(g, lambda V: 0.011 + np.clip((0.04 - V[:, 2]) / 0.04, 0, 1) * 0.008, 30, 0.0, seed=2)
    V = co(g)
    V[:, 2] = np.maximum(V[:, 2], 0.0)
    set_co(g, V)
    hem_bulge(g, lambda V: np.ones(len(V), bool), 0.008, 4)
    color = np.array(opts.get("color", (0.45, 0.13, 0.12)))

    def paint(P, N, A):
        z = P[:, 2]
        col = np.tile(color, (len(P), 1)) * (0.85 + 0.25 * core.fbm3(P, 0.0018, 2, 3))[:, None]
        fur = z > top - 0.02
        col[fur] = np.array([0.88, 0.84, 0.78]) * (0.75 + 0.35 * core.fbm3(P[fur], 0.0015, 2, 4))[:, None]
        col[z < 0.012] = np.array([0.25, 0.2, 0.17])
        return col

    return finish_garment(b, g, others, 0.004, 1, 512, paint, 0.98)
