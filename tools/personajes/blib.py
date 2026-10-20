"""Ayudas para armar personajes en Blender (bpy) a partir del cuerpo base de Quaternius (CC0).

Coordenadas de Blender: Z arriba, el personaje mira hacia -Y, +X es su izquierda.
"""
import math, os, sys
import bpy, bmesh
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.normpath(os.path.join(HERE, "..", ".."))
FUENTES = os.environ.get("MUDANCEROS_FUENTES", os.path.join(HERE, "fuentes"))
OUT = os.path.join(REPO, "assets", "characters")
UBC = FUENTES + "/Universal Base Characters[Standard]"
UAL = FUENTES + "/Universal Animation Library[Standard]/Unreal-Godot/UAL1_Standard.glb"
BASE = UBC + "/Base Characters/Godot - UE/"
HAIR = UBC + "/Hairstyles/Rigged to Head Bone/glTF (Godot -Unreal)/"
sys.path.insert(0, HERE)
import core  # noqa: E402  (ruido, rasterizado y demás, solo numpy)


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def import_gltf(path):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=path, merge_vertices=True)
    new = [o for o in bpy.data.objects if o not in before]
    keep = []
    for o in new:
        if o.type == "MESH" and o.name.startswith("Icosphere"):
            bpy.data.objects.remove(o, do_unlink=True)
        else:
            keep.append(o)
    return keep


def import_base(kind="male"):
    f = "Superhero_Male_FullBody.gltf" if kind == "male" else "Superhero_Female_FullBody.gltf"
    objs = import_gltf(BASE + f)
    out = {}
    for o in objs:
        if o.type == "ARMATURE":
            out["arm"] = o
        elif o.name.startswith("Eyebrows"):
            out["brows"] = o
        elif o.name.startswith("Eyes"):
            out["eyes"] = o
        elif o.type == "MESH":
            out["body"] = o
    return out


def co(o):
    a = np.zeros(len(o.data.vertices) * 3)
    o.data.vertices.foreach_get("co", a)
    return a.reshape(-1, 3)


def set_co(o, arr):
    o.data.vertices.foreach_set("co", np.ascontiguousarray(arr, dtype=np.float64).reshape(-1))
    o.data.update()


def faces(o):
    o.data.calc_loop_triangles()
    t = np.zeros(len(o.data.loop_triangles) * 3, np.int64)
    o.data.loop_triangles.foreach_get("vertices", t)
    return t.reshape(-1, 3)


def edges(o):
    e = np.zeros(len(o.data.edges) * 2, np.int64)
    o.data.edges.foreach_get("vertices", e)
    return e.reshape(-1, 2)


def group_weights(o, prefixes, side=None):
    """Suma de los pesos de los grupos de vértices cuyo nombre empieza con algún prefijo."""
    idx = [g.index for g in o.vertex_groups if any(g.name.startswith(p) for p in prefixes)
           and (side is None or g.name.endswith("_" + side))]
    w = np.zeros(len(o.data.vertices))
    if not idx:
        return w
    idx = set(idx)
    for v in o.data.vertices:
        for g in v.groups:
            if g.group in idx:
                w[v.index] += g.weight
    return w


def bone_head(arm, name):
    return np.array(arm.matrix_world @ arm.data.bones[name].head_local)


def taubin(V, E, mask, iters=10, lam=0.5, mu=-0.53):
    """Suavizado que no achica (Taubin), solo donde mask > 0 (con esa fuerza)."""
    n = len(V)
    deg = np.bincount(E.reshape(-1), minlength=n).astype(float)
    m = mask[:, None]
    for _ in range(iters):
        for f in (lam, mu):
            acc = np.zeros_like(V)
            np.add.at(acc, E[:, 0], V[E[:, 1]])
            np.add.at(acc, E[:, 1], V[E[:, 0]])
            avg = acc / np.maximum(deg, 1)[:, None]
            V = V + f * m * (avg - V)
    return V


def select_only(objs):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]


def export(path, objs):
    select_only(objs)
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLTF_SEPARATE", use_selection=True,
                              export_animations=False, export_skins=True, export_morph=True,
                              export_yup=True, export_apply=False, export_texcoords=True, export_normals=True)


# ---------------------------------------------------------------- texturas pintadas por posición

def loop_tris(o, uv_index=0):
    """Triángulos con sus UV por esquina (en la convención de imagen: fila 0 arriba)."""
    me = o.data
    me.calc_loop_triangles()
    n = len(me.loop_triangles)
    tv = np.zeros(n * 3, np.int64)
    tl = np.zeros(n * 3, np.int64)
    me.loop_triangles.foreach_get("vertices", tv)
    me.loop_triangles.foreach_get("loops", tl)
    uv = np.zeros(len(me.loops) * 2)
    me.uv_layers[uv_index].data.foreach_get("uv", uv)
    uv = uv.reshape(-1, 2)[tl]
    uv[:, 1] = 1.0 - uv[:, 1]
    return tv.reshape(-1, 3), uv.reshape(-1, 3, 2)


def paint_texture(o, size, paint_fn, extra=None, uv_index=0, dilate=8):
    """Pinta una textura recorriendo cada texel: paint_fn(P, N, attrs) -> colores (n, 3)."""
    tv, tuv = loop_tris(o, uv_index)
    V = co(o)
    Nv = np.zeros(len(o.data.vertices) * 3)
    o.data.vertices.foreach_get("normal", Nv)
    Nv = Nv.reshape(-1, 3)
    corners = tv.reshape(-1)
    attrs = {"P": V[corners], "N": Nv[corners]}
    for k, arr in (extra or {}).items():
        attrs[k] = arr[corners] if arr.ndim == 2 else arr[corners][:, None]
    T = np.arange(len(corners)).reshape(-1, 3)
    att, cover = core.raster(tuv.reshape(-1, 2), T, attrs, size)
    img = np.zeros((size, size, 3), np.float32)
    sel = {k: v[cover] for k, v in att.items()}
    img[cover] = paint_fn(sel["P"], sel["N"], sel)
    return core.dilate(img, cover, dilate), cover


def load_image_np(path, size=None):
    from PIL import Image
    im = Image.open(path).convert("RGB")
    if size:
        im = im.resize((size, size), Image.LANCZOS)
    return np.asarray(im, np.float32) / 255.0


def sample_image(img, uv):
    """Muestra una imagen (fila 0 arriba) en coordenadas uv (0..1, fila 0 arriba)."""
    h, w = img.shape[:2]
    x = np.clip((uv[:, 0] * w).astype(int), 0, w - 1)
    y = np.clip((uv[:, 1] * h).astype(int), 0, h - 1)
    return img[y, x]


def save_png(img, path):
    from PIL import Image
    Image.fromarray((np.clip(img, 0, 1) * 255).astype(np.uint8)).save(path)


def shrink_png(path, size):
    from PIL import Image
    im = Image.open(path)
    if im.size[0] > size:
        im.resize((size, size), Image.LANCZOS).save(path)


def simple_material(name, tex_path=None, color=(1, 1, 1), rough=0.8, normal_path=None, metal=0.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Metallic"].default_value = metal
    if tex_path:
        img = bpy.data.images.load(tex_path)
        tn = nt.nodes.new("ShaderNodeTexImage")
        tn.image = img
        nt.links.new(tn.outputs["Color"], bsdf.inputs["Base Color"])
    if normal_path:
        img = bpy.data.images.load(normal_path)
        img.colorspace_settings.name = "Non-Color"
        tn = nt.nodes.new("ShaderNodeTexImage")
        tn.image = img
        nm = nt.nodes.new("ShaderNodeNormalMap")
        nt.links.new(tn.outputs["Color"], nm.inputs["Color"])
        nt.links.new(nm.outputs["Normal"], bsdf.inputs["Normal"])
    return m


def set_material(o, mat):
    o.data.materials.clear()
    o.data.materials.append(mat)


# ---------------------------------------------------------------- prendas

def link(o):
    if o.name not in bpy.context.scene.collection.objects:
        bpy.context.scene.collection.objects.link(o)


def duplicate(o, name):
    d = o.copy()
    d.data = o.data.copy()
    d.name = name
    d.data.name = name
    link(d)
    return d


def bisect_keep(o, cuts):
    """Corta la malla con planos [(punto, normal), ...] y borra lo que queda del lado de la normal."""
    bm = bmesh.new()
    bm.from_mesh(o.data)
    for p, n in cuts:
        geom = bm.verts[:] + bm.edges[:] + bm.faces[:]
        bmesh.ops.bisect_plane(bm, geom=geom, plane_co=p, plane_no=n, clear_outer=True)
    bm.to_mesh(o.data)
    bm.free()
    o.data.update()


def delete_verts(o, mask):
    bm = bmesh.new()
    bm.from_mesh(o.data)
    bm.verts.ensure_lookup_table()
    bmesh.ops.delete(bm, geom=[bm.verts[i] for i in np.nonzero(mask)[0]], context="VERTS")
    bm.to_mesh(o.data)
    bm.free()
    o.data.update()


def keep_largest_parts(o, min_verts=30):
    """Saca pedacitos sueltos que quedan de los cortes."""
    bm = bmesh.new()
    bm.from_mesh(o.data)
    seen = set()
    drop = []
    for v in bm.verts:
        if v in seen:
            continue
        stack = [v]
        comp = []
        seen.add(v)
        while stack:
            x = stack.pop()
            comp.append(x)
            for e in x.link_edges:
                y = e.other_vert(x)
                if y not in seen:
                    seen.add(y)
                    stack.append(y)
        if len(comp) < min_verts:
            drop += comp
    if drop:
        bmesh.ops.delete(bm, geom=drop, context="VERTS")
    bm.to_mesh(o.data)
    bm.free()


def vertex_normals(o):
    o.data.update()
    n = np.zeros(len(o.data.vertices) * 3)
    o.data.vertices.foreach_get("normal", n)
    return n.reshape(-1, 3)


def boundary_mask(o):
    bm = bmesh.new()
    bm.from_mesh(o.data)
    m = np.zeros(len(bm.verts), bool)
    for e in bm.edges:
        if e.is_boundary:
            m[e.verts[0].index] = m[e.verts[1].index] = True
    bm.free()
    return m


def ring_distance(o, sources, max_steps=12):
    """Distancia en aristas desde los vértices `sources` (para dobladillos y bandas)."""
    E = edges(o)
    n = len(o.data.vertices)
    d = np.full(n, max_steps + 1)
    d[sources] = 0
    for step in range(1, max_steps + 1):
        a, b = E[:, 0], E[:, 1]
        na = np.minimum(d[a], d[b] + 1)
        nb = np.minimum(d[b], d[a] + 1)
        d2 = d.copy()
        np.minimum.at(d2, a, na)
        np.minimum.at(d2, b, nb)
        if (d2 == d).all():
            break
        d = d2
    return d


def add_modifier(o, kind, **kw):
    m = o.modifiers.new(kind.lower(), kind)
    for k, v in kw.items():
        setattr(m, k, v)
    return m


def apply_modifiers(o):
    select_only([o])
    for m in list(o.modifiers):
        if m.type == "ARMATURE":
            continue
        bpy.ops.object.modifier_apply(modifier=m.name)


def move_armature_last(o):
    """El modificador de esqueleto va al final (para que la ropa se mueva con el cuerpo)."""
    arm = [m for m in o.modifiers if m.type == "ARMATURE"]
    if arm:
        select_only([o])
        bpy.ops.object.modifier_move_to_index(modifier=arm[0].name, index=len(o.modifiers) - 1)


def smart_uv(o, angle=66.0, margin=0.004):
    select_only([o])
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(angle), island_margin=margin, area_weight=1.0)
    bpy.ops.object.mode_set(mode="OBJECT")
    # Una sola capa de UV (las del cuerpo copiado sobran).
    me = o.data
    while len(me.uv_layers) > 1:
        me.uv_layers.remove(me.uv_layers[-1] if me.uv_layers.active_index == 0 else me.uv_layers[0])


def bake_ao(objs, target, size=1024, samples=24, distance=0.08):
    """Sombra de los rincones de `target` (con lo que tiene alrededor) a una imagen (numpy)."""
    scn = bpy.context.scene
    scn.render.engine = "CYCLES"
    scn.cycles.device = "CPU"
    scn.cycles.samples = samples
    scn.world = scn.world or bpy.data.worlds.new("Mundo")
    scn.world.light_settings.distance = distance
    img = bpy.data.images.new("ao_" + target.name, size, size, float_buffer=False)
    mat = bpy.data.materials.new("bake_" + target.name)
    mat.use_nodes = True
    tn = mat.node_tree.nodes.new("ShaderNodeTexImage")
    tn.image = img
    mat.node_tree.nodes.active = tn
    old = list(target.data.materials)
    target.data.materials.clear()
    target.data.materials.append(mat)
    select_only([target])
    bpy.ops.object.bake(type="AO", margin=6, use_selected_to_active=False)
    target.data.materials.clear()
    for m in old:
        target.data.materials.append(m)
    px = np.array(img.pixels[:], np.float32).reshape(size, size, 4)[::-1, :, 0]
    return px


def boolean_cut(o, cutter_fn):
    """Corta con un volumen (lo que queda adentro se borra). cutter_fn() crea y devuelve el cortador."""
    cutter = cutter_fn()
    m = o.modifiers.new("corte", "BOOLEAN")
    m.operation = "DIFFERENCE"
    m.object = cutter
    m.solver = "EXACT"
    m.use_hole_tolerant = True
    select_only([o])
    bpy.ops.object.modifier_move_to_index(modifier=m.name, index=0)
    bpy.ops.object.modifier_apply(modifier=m.name)
    bpy.data.objects.remove(cutter, do_unlink=True)


def elliptic_cylinder(center, rx, ry, depth, tilt_deg=0.0):
    bpy.ops.mesh.primitive_cylinder_add(vertices=64, radius=1.0, depth=depth, location=center)
    c = bpy.context.active_object
    c.scale = (rx, ry, 1.0)
    c.rotation_euler = (math.radians(tilt_deg), 0, 0)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    return c


def smooth_boundary(o, select_fn, iters=8, k=0.5):
    """Alisa los bordes abiertos (los que cumplen select_fn) a lo largo del borde mismo."""
    bm = bmesh.new()
    bm.from_mesh(o.data)
    bm.verts.ensure_lookup_table()
    nb = {}
    for e in bm.edges:
        if e.is_boundary:
            a, b = e.verts[0].index, e.verts[1].index
            nb.setdefault(a, []).append(b)
            nb.setdefault(b, []).append(a)
    bm.free()
    V = co(o)
    ids = [i for i in nb if len(nb[i]) == 2 and select_fn(V[i:i + 1])[0]]
    if not ids:
        return
    ids = np.array(ids)
    na = np.array([nb[i][0] for i in ids])
    nbb = np.array([nb[i][1] for i in ids])
    for _ in range(iters):
        V[ids] = V[ids] * (1 - k) + (V[na] + V[nbb]) * 0.5 * k
    set_co(o, V)


def eye_level(b):
    E = co(b["eyes"])
    return float(E[:, 2].mean()), float(E[:, 1].mean())
