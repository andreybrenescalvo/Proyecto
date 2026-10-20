"""Base para armar personajes por código: formas (distancias con signo), mallas, UV y texturas.

Todo en metros, pose T de la Universal Animation Library: +Y arriba, +Z adelante, +X a la izquierda
del personaje.
"""
import math
import numpy as np

# ---------------------------------------------------------------- formas

def sphere(c, r):
    c = np.asarray(c, float)
    return lambda P: np.linalg.norm(P - c, axis=1) - r

def ellipsoid(c, r, rot=None):
    """Elipsoide (distancia aproximada, buena cerca de la superficie). rot: matriz 3x3 (columnas =
    ejes propios en el mundo)."""
    c = np.asarray(c, float)
    r = np.asarray(r, float)
    def f(P):
        q = P - c
        if rot is not None:
            q = q @ rot
        k0 = np.linalg.norm(q / r, axis=1)
        k1 = np.linalg.norm(q / (r * r), axis=1)
        return k0 * (k0 - 1.0) / np.maximum(k1, 1e-9)
    return f

def round_cone_t(a, b, ra, rb):
    """Cápsula de radio variable; devuelve (distancia, t a lo largo)."""
    a = np.asarray(a, float)
    b = np.asarray(b, float)
    ba = b - a
    l2 = ba @ ba
    def f(P):
        pa = P - a
        tr = pa @ ba / l2
        t = np.clip(tr, 0.0, 1.0)
        r = ra + (rb - ra) * t
        return np.linalg.norm(pa - t[:, None] * ba, axis=1) - r, tr
    return f

def round_cone(a, b, ra, rb):
    g = round_cone_t(a, b, ra, rb)
    return lambda P: g(P)[0]

def capsule(a, b, r):
    return round_cone(a, b, r, r)

def box(c, half, rot=None, rad=0.0):
    c = np.asarray(c, float)
    half = np.asarray(half, float)
    def f(P):
        q = P - c
        if rot is not None:
            q = q @ rot
        d = np.abs(q) - (half - rad)
        return np.linalg.norm(np.maximum(d, 0.0), axis=1) + np.minimum(d.max(1), 0.0) - rad
    return f

def torus(c, axis, R, r):
    """Anillo alrededor de `axis` (unitario) con radio mayor R y grosor r."""
    c = np.asarray(c, float)
    axis = np.asarray(axis, float) / np.linalg.norm(axis)
    def f(P):
        q = P - c
        h = q @ axis
        radial = np.linalg.norm(q - np.outer(h, axis), axis=1)
        return np.sqrt((radial - R) ** 2 + h ** 2) - r
    return f

def plane(p, n):
    """Semiespacio: negativo del lado contrario a la normal."""
    p = np.asarray(p, float)
    n = np.asarray(n, float) / np.linalg.norm(n)
    return lambda P: (P - p) @ n

def smin_v(a, b, k):
    if k <= 0:
        return np.minimum(a, b)
    h = np.clip(0.5 + 0.5 * (b - a) / k, 0.0, 1.0)
    return b * (1 - h) + a * h - k * h * (1 - h)

def smax_v(a, b, k):
    return -smin_v(-a, -b, k)

def union(*fs, k=0.0):
    def f(P):
        d = fs[0](P)
        for g in fs[1:]:
            d = smin_v(d, g(P), k)
        return d
    return f

def union_k(pairs):
    """Unión con suavizado por pieza: [(f, k), ...]."""
    def f(P):
        d = pairs[0][0](P)
        for g, k in pairs[1:]:
            d = smin_v(d, g(P), k)
        return d
    return f

def intersect(a, b, k=0.0):
    return lambda P: smax_v(a(P), b(P), k)

def subtract(a, b, k=0.0):
    return lambda P: smax_v(a(P), -b(P), k)

def offset(a, t):
    return lambda P: a(P) - t

def shell(a, t_out, t_in):
    """Cáscara entre a-t_in y a-t_out (t_out > t_in)."""
    return lambda P: np.maximum(a(P) - t_out, -(a(P) - t_in))

def smoothstep(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0.0, 1.0)
    return t * t * (3 - 2 * t)

def rot_y(deg):
    a = math.radians(deg)
    return np.array([[math.cos(a), 0, math.sin(a)], [0, 1, 0], [-math.sin(a), 0, math.cos(a)]])

def rot_x(deg):
    a = math.radians(deg)
    return np.array([[1, 0, 0], [0, math.cos(a), -math.sin(a)], [0, math.sin(a), math.cos(a)]])

def rot_z(deg):
    a = math.radians(deg)
    return np.array([[math.cos(a), -math.sin(a), 0], [math.sin(a), math.cos(a), 0], [0, 0, 1]])

def eval_chunks(f, P, chunk=300000):
    out = np.empty(len(P))
    for i in range(0, len(P), chunk):
        out[i:i + chunk] = f(P[i:i + chunk])
    return out

def grad(f, V, eps=0.0008):
    g = np.zeros_like(V)
    for a in range(3):
        o = np.zeros(3)
        o[a] = eps
        g[:, a] = eval_chunks(f, V + o) - eval_chunks(f, V - o)
    return g / (np.linalg.norm(g, axis=1, keepdims=True) + 1e-12)

# ---------------------------------------------------------------- malla (surface nets)

def surface_nets(f, lo, hi, cell):
    lo = np.asarray(lo, float)
    hi = np.asarray(hi, float)
    n = np.ceil((hi - lo) / cell).astype(int) + 1
    xs = [lo[i] + np.arange(n[i]) * cell for i in range(3)]
    G = np.stack(np.meshgrid(*xs, indexing="ij"), -1).reshape(-1, 3)
    D = eval_chunks(f, G).reshape(n)
    return surface_nets_grid(D, lo, cell)

def grid_sampler(D, lo, cell):
    """Distancia por interpolación de una grilla ya calculada (para alisar y sacar normales)."""
    lo = np.asarray(lo, float)
    n = np.array(D.shape)
    def f(P):
        q = (P - lo) / cell
        i0 = np.clip(np.floor(q).astype(int), 0, n - 2)
        t = np.clip(q - i0, 0, 1)
        out = 0.0
        for dx in (0, 1):
            for dy in (0, 1):
                for dz in (0, 1):
                    w = (t[:, 0] if dx else 1 - t[:, 0]) * (t[:, 1] if dy else 1 - t[:, 1]) * (t[:, 2] if dz else 1 - t[:, 2])
                    out = out + w * D[i0[:, 0] + dx, i0[:, 1] + dy, i0[:, 2] + dz]
        return out
    return f

def surface_nets_grid(D, lo, cell):
    n = np.array(D.shape)
    inside = D < 0
    cnt = np.zeros((n[0] - 1, n[1] - 1, n[2] - 1), np.int32)
    for dx in (0, 1):
        for dy in (0, 1):
            for dz in (0, 1):
                cnt += inside[dx:n[0] - 1 + dx, dy:n[1] - 1 + dy, dz:n[2] - 1 + dz]
    active = (cnt > 0) & (cnt < 8)
    idx = -np.ones(active.shape, np.int64)
    ai = np.argwhere(active)
    if len(ai) == 0:
        return np.zeros((0, 3)), np.zeros((0, 3), np.int64)
    idx[active] = np.arange(len(ai))
    edges = [((0, 0, 0), (1, 0, 0)), ((0, 1, 0), (1, 1, 0)), ((0, 0, 1), (1, 0, 1)), ((0, 1, 1), (1, 1, 1)),
             ((0, 0, 0), (0, 1, 0)), ((1, 0, 0), (1, 1, 0)), ((0, 0, 1), (0, 1, 1)), ((1, 0, 1), (1, 1, 1)),
             ((0, 0, 0), (0, 0, 1)), ((1, 0, 0), (1, 0, 1)), ((0, 1, 0), (0, 1, 1)), ((1, 1, 0), (1, 1, 1))]
    i, j, k = ai[:, 0], ai[:, 1], ai[:, 2]
    acc = np.zeros((len(ai), 3))
    num = np.zeros(len(ai))
    for a, b in edges:
        da = D[i + a[0], j + a[1], k + a[2]]
        db = D[i + b[0], j + b[1], k + b[2]]
        cross = (da < 0) != (db < 0)
        t = np.where(cross, da / np.where(cross, da - db, 1.0), 0.0)
        pa = np.stack([i + a[0], j + a[1], k + a[2]], 1).astype(float)
        pb = np.stack([i + b[0], j + b[1], k + b[2]], 1).astype(float)
        acc += (pa + (pb - pa) * t[:, None]) * cross[:, None]
        num += cross
    verts = lo + acc / num[:, None] * cell
    quads = []
    for axis in range(3):
        u, w = [a for a in range(3) if a != axis]
        sl0 = [slice(None)] * 3
        sl1 = [slice(None)] * 3
        sl0[axis] = slice(0, n[axis] - 1)
        sl1[axis] = slice(1, n[axis])
        cross = inside[tuple(sl0)] != inside[tuple(sl1)]
        e = np.argwhere(cross)
        ok = (e[:, u] >= 1) & (e[:, w] >= 1) & (e[:, u] < n[u] - 1) & (e[:, w] < n[w] - 1)
        e = e[ok]
        cells = []
        for du, dw in ((0, 0), (1, 0), (1, 1), (0, 1)):
            q = e.copy()
            q[:, u] -= du
            q[:, w] -= dw
            cells.append(idx[q[:, 0], q[:, 1], q[:, 2]])
        cells = np.stack(cells, 1)
        cells = cells[(cells >= 0).all(1)]
        quads.append(cells)
    quads = np.concatenate(quads)
    tris = np.concatenate([quads[:, [0, 1, 2]], quads[:, [0, 2, 3]]])
    return verts, tris

def relax(V, T, f, iters=2):
    for _ in range(iters):
        acc = np.zeros_like(V)
        cnt = np.zeros(len(V))
        for a, b in ((0, 1), (1, 2), (2, 0)):
            np.add.at(acc, T[:, a], V[T[:, b]])
            np.add.at(cnt, T[:, a], 1)
            np.add.at(acc, T[:, b], V[T[:, a]])
            np.add.at(cnt, T[:, b], 1)
        V = V * 0.5 + (acc / np.maximum(cnt, 1)[:, None]) * 0.5
        n = grad(f, V)
        V = V - n * eval_chunks(f, V)[:, None]
    return V

def orient(V, T, N):
    fn = np.cross(V[T[:, 1]] - V[T[:, 0]], V[T[:, 2]] - V[T[:, 0]])
    flip = (fn * (N[T[:, 0]] + N[T[:, 1]] + N[T[:, 2]])).sum(1) < 0
    T = T.copy()
    T[flip] = T[flip][:, ::-1]
    return T

def mesh_from_sdf(f, lo, hi, cell, relax_iters=2):
    V, T = surface_nets(f, lo, hi, cell)
    if len(V) == 0:
        return V, T, V
    V = relax(V, T, f, relax_iters)
    N = grad(f, V)
    T = orient(V, T, N)
    return V, T, N

def drop_small_pieces(V, T, N, min_tris=60):
    """Saca pedacitos sueltos (restos de recortes)."""
    parent = np.arange(len(V))
    def find(x):
        while parent[x] != x:
            parent[x] = parent[parent[x]]
            x = parent[x]
        return x
    for a, b in ((0, 1), (1, 2)):
        for u, v in zip(T[:, a], T[:, b]):
            ru, rv = find(u), find(v)
            if ru != rv:
                parent[ru] = rv
    roots = np.array([find(i) for i in range(len(V))])
    tri_root = roots[T[:, 0]]
    ids, counts = np.unique(tri_root, return_counts=True)
    keep_roots = set(ids[counts >= min_tris])
    keep_t = np.array([r in keep_roots for r in tri_root])
    T = T[keep_t]
    used = np.unique(T)
    remap = -np.ones(len(V), np.int64)
    remap[used] = np.arange(len(used))
    return V[used], remap[T], N[used]

# ---------------------------------------------------------------- UV y texturas

def split_by_islands(V, T, N, tri_island, uv_of):
    """Duplica los vértices que comparten triángulos de islas distintas. uv_of(P, isla) -> uv."""
    key = T * 64 + tri_island[:, None]
    uniq, inv = np.unique(key.reshape(-1), return_inverse=True)
    orig = uniq // 64
    isl = uniq % 64
    V2, N2 = V[orig], N[orig]
    UV = np.zeros((len(orig), 2))
    for i in np.unique(isl):
        s = isl == i
        UV[s] = uv_of(V2[s], i)
    T2 = inv.reshape(-1, 3)
    return V2, T2, N2, UV, orig

def fix_wrap(V, T, N, UV, orig, island_u_ranges):
    """Triángulos que cruzan la costura (u da la vuelta): duplica vértices con u corrido una vuelta."""
    newV, newN, newUV, newO = [V], [N], [UV], [orig]
    T = T.copy()
    base = len(V)
    extra = []
    for tri_i in range(len(T)):
        t = T[tri_i]
        u = UV[t, 0]
        for (u0, u1) in island_u_ranges:
            inside = (u >= u0 - 1e-6) & (u <= u1 + 1e-6)
            if inside.all() and (u.max() - u.min()) > (u1 - u0) * 0.5:
                w = u1 - u0
                for k in range(3):
                    if u[k] < u0 + w * 0.5:
                        extra.append((t[k], UV[t[k], 0] + w, UV[t[k], 1]))
                        T[tri_i, k] = base + len(extra) - 1
                break
    if extra:
        ids = np.array([e[0] for e in extra])
        newV.append(V[ids])
        newN.append(N[ids])
        newUV.append(np.array([[e[1], e[2]] for e in extra]))
        newO.append(orig[ids])
    return np.concatenate(newV), T, np.concatenate(newN), np.concatenate(newUV), np.concatenate(newO)

def raster(UV, T, attrs, size):
    """Para cada texel, los atributos interpolados del triángulo que lo cubre."""
    H = W = size
    out = {k: np.zeros((H, W, v.shape[1]), np.float32) for k, v in attrs.items()}
    cover = np.zeros((H, W), bool)
    P = np.stack([UV[:, 0] * W, UV[:, 1] * H], 1)
    tri = P[T]
    xmin = np.clip(np.floor(tri[:, :, 0].min(1)), 0, W - 1).astype(int)
    xmax = np.clip(np.ceil(tri[:, :, 0].max(1)), 0, W - 1).astype(int)
    ymin = np.clip(np.floor(tri[:, :, 1].min(1)), 0, H - 1).astype(int)
    ymax = np.clip(np.ceil(tri[:, :, 1].max(1)), 0, H - 1).astype(int)
    for ti in range(len(T)):
        if xmax[ti] < xmin[ti] or ymax[ti] < ymin[ti]:
            continue
        a, b, c = tri[ti]
        d = (b[1] - c[1]) * (a[0] - c[0]) + (c[0] - b[0]) * (a[1] - c[1])
        if abs(d) < 1e-12:
            continue
        xs, ys = np.meshgrid(np.arange(xmin[ti], xmax[ti] + 1) + 0.5, np.arange(ymin[ti], ymax[ti] + 1) + 0.5)
        l1 = ((b[1] - c[1]) * (xs - c[0]) + (c[0] - b[0]) * (ys - c[1])) / d
        l2 = ((c[1] - a[1]) * (xs - c[0]) + (a[0] - c[0]) * (ys - c[1])) / d
        l3 = 1 - l1 - l2
        m = (l1 >= -0.02) & (l2 >= -0.02) & (l3 >= -0.02)
        if not m.any():
            continue
        yy, xx = np.nonzero(m)
        yy = yy + ymin[ti]
        xx = xx + xmin[ti]
        t = T[ti]
        for k, v in attrs.items():
            out[k][yy, xx] = l1[m][:, None] * v[t[0]] + l2[m][:, None] * v[t[1]] + l3[m][:, None] * v[t[2]]
        cover[yy, xx] = True
    return out, cover

def dilate(img, cover, n=8):
    img = img.copy()
    cov = cover.copy()
    for _ in range(n):
        acc = np.zeros_like(img)
        cnt = np.zeros(cov.shape, np.float32)
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            acc += np.roll(np.roll(img * cov[..., None], dy, 0), dx, 1)
            cnt += np.roll(np.roll(cov, dy, 0), dx, 1)
        new = (~cov) & (cnt > 0)
        img[new] = acc[new] / cnt[new][:, None]
        cov = cov | new
    return img

def value_noise3(P, scale, seed=0):
    """Ruido suave en 3D (por posición): para manchas, fibras y variaciones de color."""
    rng = np.random.default_rng(seed)
    perm = rng.permutation(4096)
    q = P / scale
    i0 = np.floor(q).astype(np.int64)
    fr = q - i0
    w = fr * fr * (3 - 2 * fr)
    def h(ix, iy, iz):
        return (perm[(ix * 73856093 ^ iy * 19349663 ^ iz * 83492791) % 4096] / 4095.0)
    out = 0.0
    for dx in (0, 1):
        for dy in (0, 1):
            for dz in (0, 1):
                wt = (w[..., 0] if dx else 1 - w[..., 0]) * (w[..., 1] if dy else 1 - w[..., 1]) * (w[..., 2] if dz else 1 - w[..., 2])
                out = out + wt * h(i0[..., 0] + dx, i0[..., 1] + dy, i0[..., 2] + dz)
    return out

def fbm3(P, scale, octaves=3, seed=0):
    out = 0.0
    amp = 1.0
    tot = 0.0
    for o in range(octaves):
        out = out + amp * value_noise3(P, scale / (2 ** o), seed + o * 17)
        tot += amp
        amp *= 0.5
    return out / tot

# ---------------------------------------------------------------- oclusión (sombra de los rincones)

def ambient_occlusion(f_scene, V, N, step=0.006, steps=5, k=0.9):
    occ = np.zeros(len(V))
    w = 1.0
    for i in range(1, steps + 1):
        d = eval_chunks(f_scene, V + N * (i * step))
        occ += w * np.clip(i * step - d, 0, None) / (i * step)
        w *= 0.5
    return np.clip(1.0 - k * occ, 0.35, 1.0)

def tangents(V, N, UV, T):
    t = np.zeros_like(V)
    p0, p1, p2 = V[T[:, 0]], V[T[:, 1]], V[T[:, 2]]
    w0, w1, w2 = UV[T[:, 0]], UV[T[:, 1]], UV[T[:, 2]]
    e1, e2 = p1 - p0, p2 - p0
    d1, d2 = w1 - w0, w2 - w0
    r = d1[:, 0] * d2[:, 1] - d2[:, 0] * d1[:, 1]
    r = np.where(np.abs(r) < 1e-12, 1e-12, r)
    tan = (e1 * d2[:, 1:2] - e2 * d1[:, 1:2]) / r[:, None]
    for k in range(3):
        np.add.at(t, T[:, k], tan)
    t = t - N * (t * N).sum(1, keepdims=True)
    t /= np.linalg.norm(t, axis=1, keepdims=True) + 1e-12
    return np.hstack([t, np.ones((len(t), 1))])

# ---------------------------------------------------------------- UV automática (atlas por caras)

def _tri_adjacency(T):
    """Pares de triángulos vecinos (comparten una arista)."""
    e = np.concatenate([T[:, [0, 1]], T[:, [1, 2]], T[:, [2, 0]]])
    tid = np.tile(np.arange(len(T)), 3)
    e = np.sort(e, 1)
    key = e[:, 0] * (T.max() + 1) + e[:, 1]
    order = np.argsort(key)
    ks = key[order]
    same = ks[1:] == ks[:-1]
    a = tid[order][:-1][same]
    b = tid[order][1:][same]
    return a, b

def atlas_uv(V, T, N, texels_per_m, size, pad=3):
    """Despliega la malla en un atlas: cada triángulo va a la cara del cubo hacia donde mira
    (±X, ±Y, ±Z), se juntan en islas y se acomodan en la textura. Devuelve V, T, N, UV, orig
    (los vértices se duplican en los bordes de las islas)."""
    fn = np.cross(V[T[:, 1]] - V[T[:, 0]], V[T[:, 2]] - V[T[:, 0]])
    fn /= np.linalg.norm(fn, axis=1, keepdims=True) + 1e-12
    axis = np.argmax(np.abs(fn), 1) * 2 + (np.take_along_axis(fn, np.argmax(np.abs(fn), 1)[:, None], 1)[:, 0] < 0)
    a, b = _tri_adjacency(T)
    # Suavizar: cada triángulo toma la dirección más votada entre él y sus vecinos.
    for _ in range(3):
        votes = np.zeros((len(T), 6))
        np.add.at(votes, (np.arange(len(T)), axis), 1.5)
        np.add.at(votes, (a, axis[b]), 1)
        np.add.at(votes, (b, axis[a]), 1)
        # No votar por una dirección contraria a la normal propia.
        dirs = np.array([[1, 0, 0], [-1, 0, 0], [0, 1, 0], [0, -1, 0], [0, 0, 1], [0, 0, -1]], float)
        ok = (fn @ dirs.T) > 0.15
        votes[~ok] = -1
        axis = np.argmax(votes, 1)
    # Islas: componentes conexas con la misma dirección.
    parent = np.arange(len(T))
    def find(x):
        r = x
        while parent[r] != r:
            r = parent[r]
        while parent[x] != r:
            parent[x], x = r, parent[x]
        return r
    same = axis[a] == axis[b]
    for x, y in zip(a[same], b[same]):
        rx, ry = find(x), find(y)
        if rx != ry:
            parent[rx] = ry
    root = np.array([find(i) for i in range(len(T))])
    _, island = np.unique(root, return_inverse=True)
    # Vértices por isla.
    key = T.astype(np.int64) * (island.max() + 1) + island[:, None]
    uniq, inv = np.unique(key.reshape(-1), return_inverse=True)
    orig = uniq // (island.max() + 1)
    isl_v = uniq % (island.max() + 1)
    T2 = inv.reshape(-1, 3)
    # Proyección según la dirección de la isla.
    ax_of_island = np.zeros(island.max() + 1, np.int64)
    ax_of_island[island] = axis
    proj = {0: (2, 1, -1), 1: (2, 1, 1), 2: (0, 2, 1), 3: (0, 2, -1), 4: (0, 1, 1), 5: (0, 1, -1)}
    P2 = np.zeros((len(orig), 2))
    for ax in range(6):
        s = ax_of_island[isl_v] == ax
        i0, i1, sg = proj[ax]
        P2[s, 0] = V[orig[s], i0] * sg
        P2[s, 1] = -V[orig[s], i1]
    # Acomodar las islas en filas (de la más alta a la más baja).
    n_isl = island.max() + 1
    mins = np.full((n_isl, 2), np.inf)
    maxs = np.full((n_isl, 2), -np.inf)
    np.minimum.at(mins, isl_v, P2)
    np.maximum.at(maxs, isl_v, P2)
    dims = (maxs - mins)
    scale = texels_per_m
    for _ in range(12):
        wpx = np.ceil(dims * scale) + pad * 2
        order = np.argsort(-wpx[:, 1])
        x = y = row_h = 0
        pos = np.zeros((n_isl, 2))
        fits = True
        for i in order:
            w_, h_ = wpx[i]
            if x + w_ > size:
                x = 0
                y += row_h
                row_h = 0
            pos[i] = (x, y)
            x += w_
            row_h = max(row_h, h_)
            if y + row_h > size:
                fits = False
                break
        if fits:
            break
        scale *= 0.88
    UV = ((P2 - mins[isl_v]) * scale + pos[isl_v] + pad) / size
    return V[orig], T2, N[orig], UV, orig, scale
