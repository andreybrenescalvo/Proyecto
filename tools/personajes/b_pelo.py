"""Pelo, cejas, bigote y color de ojos.

Los peinados base son de Quaternius (CC0, vienen pegados al hueso de la cabeza); se acomodan a la
cabeza agrandada, se tiñen y, si hay sombrero, se recortan por debajo del borde. Los rulos y el
bigote los hacemos nosotros con formas suaves.
"""
from blib import *
import b_ropa
from b_ropa import OUT


def attach_to(o, b):
    """Pega una malla importada a nuestro esqueleto (mismos nombres de huesos)."""
    old_parent = o.parent
    o.parent = b["arm"]
    for m in list(o.modifiers):
        if m.type == "ARMATURE":
            m.object = b["arm"]
    if not any(m.type == "ARMATURE" for m in o.modifiers):
        m = o.modifiers.new("esqueleto", "ARMATURE")
        m.object = b["arm"]


def tint_texture(src, color, name, gamma=1.0):
    img = load_image_np(src)
    lum = img.mean(2, keepdims=True) ** gamma
    out = OUT + "/" + name + ".png"
    save_png(np.clip(lum / max(lum.mean(), 1e-3) * np.array(color) * 0.9, 0, 1), out)
    shrink_png(out, 512)
    return out


def head_scale_info(b):
    piv = bone_head(b["arm"], "Head") + np.array([0, 0, -0.03])
    return piv, b.get("head_scale", 1.0)


def hair(b, style, color, name, hat_line=None):
    """Peinado de Quaternius: style = Buzzed, SimpleParted, Long, Buns, BuzzedFemale, Beard."""
    objs = import_gltf(HAIR + "Hair_" + style + ".gltf")
    mesh = [o for o in objs if o.type == "MESH"][0]
    arms = [o.name for o in objs if o.type == "ARMATURE"]
    attach_to(mesh, b)
    for n in arms:
        if n in bpy.data.objects:
            bpy.data.objects.remove(bpy.data.objects[n], do_unlink=True)
    mesh.name = name
    piv, s = head_scale_info(b)
    V = co(mesh)
    set_co(mesh, piv + (V - piv) * s)
    if hat_line is not None:
        V = co(mesh)
        delete_verts(mesh, hat_line(V))
        keep_largest_parts(mesh, 20)
    tex = "T_Hair_2_BaseColor.png" if style in ("Long", "Buns") else "T_Hair_1_BaseColor.png"
    src = HAIR + tex
    set_material(mesh, simple_material(name, tint_texture(src, color, name), rough=0.6))
    return mesh


def brows(b, color, name, thick=1.0):
    o = b["brows"]
    o.name = name
    if thick != 1.0:
        V = co(o)
        for sgn in (1, -1):
            sel = np.sign(V[:, 0]) == sgn
            c = V[sel].mean(0)
            V[sel] = c + (V[sel] - c) * np.array([1.05, thick, thick])
        set_co(o, V)
    set_material(o, simple_material(name, tint_texture(BASE + "T_Hair_1_BaseColor.png", color, name), rough=0.8))


def eye_color(b, color, name):
    img = load_image_np(BASE + "T_Eye_Brown.png")
    # El iris es lo más saturado; se cambia su tono conservando el dibujo.
    mx = img.max(2)
    mn = img.min(2)
    sat = (mx - mn) / np.maximum(mx, 1e-3)
    lum = img.mean(2, keepdims=True)
    iris = np.clip((sat - 0.18) / 0.2, 0, 1)[..., None]
    new = (lum / max(float(lum[iris[..., 0] > 0.5].mean()) if (iris > 0.5).any() else 0.3, 1e-3)) ** 1.3 * np.array(color) * 0.6
    out = img * (1 - iris) + np.clip(new, 0, 1) * iris
    path = OUT + "/" + name + ".png"
    save_png(out, path)
    set_material(b["eyes"], simple_material(name, path, rough=0.15))


# ---------------------------------------------------------------- piezas propias (formas suaves)

def sdf_piece(b, name, f, lo, hi, cell, color_fn, rough=0.8, size=512, bone="Head"):
    """Malla hecha con formas suaves (core), pegada a un hueso, con textura pintada."""
    V, T, N = core.mesh_from_sdf(f, lo, hi, cell, 2)
    V, T, N = core.drop_small_pieces(V, T, N, 30)
    me = bpy.data.meshes.new(name)
    # core trabaja en Y arriba, Z adelante (como glTF); pasamos a Blender (Z arriba, -Y adelante).
    Vb = np.stack([V[:, 0], -V[:, 2], V[:, 1]], 1)
    me.from_pydata(Vb.tolist(), [], T.tolist())
    me.update()
    o = bpy.data.objects.new(name, me)
    link(o)
    vg = o.vertex_groups.new(name=bone)
    vg.add(list(range(len(Vb))), 1.0, "REPLACE")
    o.parent = b["arm"]
    m = o.modifiers.new("esqueleto", "ARMATURE")
    m.object = b["arm"]
    for p in me.polygons:
        p.use_smooth = True
    smart_uv(o)
    tv, tuv = loop_tris(o)
    Vo = co(o)
    No = vertex_normals(o)
    tvf = tv.reshape(-1)
    uv = tuv.reshape(-1, 2)
    TT = np.arange(len(tvf)).reshape(-1, 3)
    att, cover = core.raster(uv, TT, {"P": Vo[tvf], "N": No[tvf]}, size)
    img = np.zeros((size, size, 3), np.float32)
    img[cover] = color_fn(att["P"][cover], att["N"][cover])
    img = core.dilate(img, cover, 8)
    path = OUT + "/" + name + ".png"
    save_png(img, path)
    set_material(o, simple_material(name, path, rough=rough))
    return o


def to_core(p):
    """Punto de Blender a coordenadas de core (Y arriba, Z adelante)."""
    return np.array([p[0], p[2], -p[1]])


def walrus_mustache(b, color, name):
    from b_piel import face_landmarks
    lm = face_landmarks(b)
    nose = to_core(lm["nose"])
    mouth = to_core(lm["mouth"])
    parts = []
    for s in (1, -1):
        for k in range(5):
            t = k / 4
            a = np.array([s * (0.003 + 0.028 * t), nose[1] - 0.012 - 0.012 * t * t, nose[2] - 0.012 - 0.016 * t])
            parts.append(core.ellipsoid(a, np.array([0.011, 0.0075 + 0.002 * (1 - t), 0.008])))
    f = core.union(*parts, k=0.006)
    lo = nose + np.array([-0.06, -0.05, -0.05])
    hi = nose + np.array([0.06, 0.01, 0.02])

    def col(P, N):
        strands = core.fbm3(P * np.array([0.3, 1.0, 1.0]), 0.0012, 2, 3)
        return np.tile(np.array(color), (len(P), 1)) * (0.75 + 0.45 * strands)[:, None]
    return sdf_piece(b, name, f, lo, hi, 0.0016, col, rough=0.85)


def curly_hair(b, color, name, hat_line=None, n=520, r=(0.0085, 0.0125), cell=0.0022):
    """Rulos: muchas bolitas sobre el cuero cabelludo (se calcula en una grilla, bolita por bolita)."""
    ez, ey = eye_level(b)
    body = b["body"]
    V = co(body)
    wh = group_weights(body, ["Head"])
    N = vertex_normals(body)
    t = np.clip((V[:, 1] - (ey - 0.03)) / 0.18, 0, 1)
    line = ez + 0.035 + (-0.075 - 0.035) * (0.5 - 0.5 * np.cos(t * math.pi))
    sel = (wh > 0.9) & (V[:, 2] > line)
    rng = np.random.default_rng(4)
    idx = np.nonzero(sel)[0]
    pick = idx[rng.choice(len(idx), min(n, len(idx)), replace=False)]
    C = np.array([to_core(V[i] + N[i] * 0.006) for i in pick])
    R = rng.uniform(r[0], r[1], len(C))
    lo = C.min(0) - 0.03
    hi = C.max(0) + 0.03
    dims = np.ceil((hi - lo) / cell).astype(int) + 1
    D = np.full(dims, 0.05)
    ax = [lo[i] + np.arange(dims[i]) * cell for i in range(3)]
    for c, rr in zip(C, R):
        i0 = np.maximum(((c - rr - 0.006 - lo) / cell).astype(int), 0)
        i1 = np.minimum(((c + rr + 0.006 - lo) / cell).astype(int) + 2, dims)
        X, Y, Z = np.meshgrid(ax[0][i0[0]:i1[0]], ax[1][i0[1]:i1[1]], ax[2][i0[2]:i1[2]], indexing="ij")
        d = np.sqrt((X - c[0]) ** 2 + (Y - c[1]) ** 2 + (Z - c[2]) ** 2) - rr
        sub = D[i0[0]:i1[0], i0[1]:i1[1], i0[2]:i1[2]]
        D[i0[0]:i1[0], i0[1]:i1[1], i0[2]:i1[2]] = core.smin_v(sub, d, 0.003)
    f = core.grid_sampler(D, lo, cell)
    Vh, Th = core.surface_nets_grid(D, lo, cell)
    Vh = core.relax(Vh, Th, f, 1)
    Nh = core.grad(f, Vh, 0.0015)
    Th = core.orient(Vh, Th, Nh)
    Vh, Th, Nh = core.drop_small_pieces(Vh, Th, Nh, 30)
    me = bpy.data.meshes.new(name)
    Vb = np.stack([Vh[:, 0], -Vh[:, 2], Vh[:, 1]], 1)
    me.from_pydata(Vb.tolist(), [], Th.tolist())
    me.update()
    o = bpy.data.objects.new(name, me)
    link(o)
    vg = o.vertex_groups.new(name="Head")
    vg.add(list(range(len(Vb))), 1.0, "REPLACE")
    o.parent = b["arm"]
    m = o.modifiers.new("esqueleto", "ARMATURE")
    m.object = b["arm"]
    for p in me.polygons:
        p.use_smooth = True
    if hat_line is not None:
        delete_verts(o, hat_line(co(o)))
    add_modifier(o, "DECIMATE", ratio=0.3)
    apply_modifiers(o)
    smart_uv(o)
    tv, tuv = loop_tris(o)
    Vo = co(o)
    tvf = tv.reshape(-1)
    uv = tuv.reshape(-1, 2)
    TT = np.arange(len(tvf)).reshape(-1, 3)
    att, cover = core.raster(uv, TT, {"P": Vo[tvf]}, 512)
    img = np.zeros((512, 512, 3), np.float32)
    P = att["P"][cover]
    # Hebras finas y algo de sombra entre rulos.
    nrm = core.fbm3(P, 0.0016, 2, 7)
    img[cover] = np.array(color) * (0.65 + 0.55 * nrm)[:, None]
    img = core.dilate(img, cover, 8)
    path = OUT + "/" + name + ".png"
    save_png(img, path)
    set_material(o, simple_material(name, path, rough=0.7))
    return o
