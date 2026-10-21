class_name CityBuilder
extends RefCounted
## Arma la ciudad alrededor de la casa de Don Ramón: calles en cuadrícula que se conectan entre
## sí, tres barrios pegados (Villa Esperanza, Los Aromos y Las Lomas), la avenida con comercios,
## la plaza, la estación de servicio y, cruzando las vías del tren, la zona industrial con el
## Galpón 7: el depósito donde el reducidor compra lo robado.
##
## Todo sale de una semilla fija, así todas las computadoras arman la misma ciudad. Las piezas
## se juntan en pocas mallas (ver MeshBatch) para que ande bien también en la versión web.
##
## Vista desde arriba (x hacia la derecha, z hacia abajo):
##
##           x=-262      x=-184   x=-170        x=-60          x=50          x=160
##   z=-39      |           ‖       +-------------+--------------+-------------+
##              |           ‖       | Villa       |  Los Aromos  |  Las Lomas  |
##              |           ‖       | Esperanza   |              |             |
##   z=21  [G7]-+           ‖       +-------------+------[R]-----+-------------+  R = Don Ramón
##              |           ‖       | casas       |  casas       |  casas      |
##              |           ‖       | comercios   |  comercios   |  comercios  |
##   z=81  =====+===========‖=======+=============+==============+=====[E]=====+  avenida
##                          ‖       | comercios   |    plaza     |  comercios  |
##                          ‖       | casas       |              |  casas      |
##   z=141                  ‖       +-------------+--------------+-------------+
##                vías del tren           cancha de fútbol al norte
##
##   G7 = el Galpón 7 (zona industrial)   E = estación de servicio

# ---------------------------------------------------------------- trazado

const HALF := 3.4            # media calle (de la línea del medio al cordón)
const WALK := 2.0            # vereda
const AV_HALF := 5.0         # media avenida
const AV_WALK := 3.0         # vereda de la avenida
const STREETS_Z := [-39.0, 21.0, 81.0, 141.0]      # calles a lo largo de X
const STREETS_X := [-170.0, -60.0, 50.0, 160.0]    # calles a lo largo de Z
const AVENUE_Z := 81.0
const NAMES_Z := ["Calle Los Pinos", "Calle Los Aromos", "Avenida Central", "Calle Las Acacias"]
const NAMES_X := ["Calle del Ferrocarril", "Calle San José", "Calle Libertad", "Calle del Parque"]
const DISTRICTS := ["Villa Esperanza", "Los Aromos", "Las Lomas"]
const IND_X := -262.0        # calle de la zona industrial (a lo largo de Z)
const IND_Z0 := -48.0        # va desde la avenida hasta acá
const AVENUE_WEST := -330.0  # donde termina la avenida
const RAIL_X := -184.0
## Bordes del mundo (x, z, ancho, largo).
const MAP := Rect2(-345.0, -80.0, 545.0, 270.0)
## Lomos de burro de la calle Los Aromos (en X), y su tamaño: largo, alto y ancho (de cordón a cordón).
const SPEED_BUMPS_X := [-28.0, -44.0]
const SPEED_BUMP_SIZE := Vector3(1.5, 0.14, 6.8)

## El Galpón 7: el centro, el tamaño (x, z) y dónde hay que dejar el camión parado.
const WAREHOUSE := Vector3(-290.0, 0.0, 0.0)
const WAREHOUSE_SIZE := Vector2(24.0, 18.0)
const WAREHOUSE_ZONE := Rect2(-296.0, -5.0, 15.0, 10.0)
const WAREHOUSE_DOOR := Vector2(7.0, 5.2)      # ancho y alto del portón (en la pared de +X)
## La computadora del Flaco: el escritorio (contra la pared de -z) y dónde queda sentado el que la usa.
const COMPUTER_DESK := Vector3(-292.0, 0.0, -8.15)
const COMPUTER_SEAT := Vector3(-292.0, 0.0, -7.25)

static func in_warehouse_zone(p: Vector3) -> bool:
	return WAREHOUSE_ZONE.has_point(Vector2(p.x, p.z))

## Cerca del galpón (adentro o en la puerta): el que llegó a pie también cuenta.
static func at_warehouse(p: Vector3) -> bool:
	return Rect2(WAREHOUSE.x - 14.0, WAREHOUSE.z - 11.0, 34.0, 22.0).has_point(Vector2(p.x, p.z))

## Rectángulos (x/z) donde el camión pega un salto: los lomos de burro y el paso a nivel.
static func bump_rects() -> Array[Rect2]:
	var out: Array[Rect2] = []
	for x: float in SPEED_BUMPS_X:
		out.append(Rect2(x - SPEED_BUMP_SIZE.x * 0.5, 21.0 - SPEED_BUMP_SIZE.z * 0.5, SPEED_BUMP_SIZE.x, SPEED_BUMP_SIZE.z))
	out.append(Rect2(RAIL_X - 1.6, AVENUE_Z - AV_HALF, 3.2, AV_HALF * 2.0))
	return out

static func _half_z(z: float) -> float:
	return AV_HALF if z == AVENUE_Z else HALF

static func _walk_z(z: float) -> float:
	return AV_WALK if z == AVENUE_Z else WALK

# ---------------------------------------------------------------- materiales

static func _tex(name: String, tint := Color.WHITE, meters := 1.0, roughness := 0.85) -> StandardMaterial3D:
	return Mats.tex(name, tint, meters, true, roughness)

static var _glow_mats := {}

## Mancha de luz en el piso (se suma a lo que hay abajo): los faroles se ven prendidos de lejos
## sin gastar una luz de verdad cada uno.
static func _pool_mat(c: Color) -> StandardMaterial3D:
	var key := c.to_html()
	if _glow_mats.has(key):
		return _glow_mats[key]
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(0.45, Color(1, 1, 1, 0.35))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 64
	t.height = 64
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_texture = t
	m.albedo_color = c
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_glow_mats[key] = m
	return m

const LAMP_COLOR := Color(1.0, 0.72, 0.4)
const SODIUM := Color(1.0, 0.6, 0.25)

# ---------------------------------------------------------------- armado

static func build(root: Node3D) -> void:
	var city := Node3D.new()
	city.name = "Ciudad"
	root.add_child(city)
	var b := MeshBatch.new(city)
	var r := RandomNumberGenerator.new()
	r.seed = 20261021
	_shop_index = 0
	_ground(b, city)
	_streets(b, city)
	_blocks(b, city, r)
	_outskirts(b, city, r)
	_lamps(b, city)
	_parked_cars(b, r)
	_industrial(b, city, r)
	_warehouse(b, city)
	_world_edges(city)
	b.commit()

## Transformación de un lote: el frente (línea municipal) en `front`, mirando hacia `facing`.
static func _lot(front: Vector3, facing: Vector3) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, atan2(facing.x, facing.z)), front)

static func _at(t: Transform3D, pos: Vector3, rot_deg := Vector3.ZERO) -> Transform3D:
	return t * Transform3D(Basis.from_euler(rot_deg * (PI / 180.0)), pos)

static func _p(x: float, z: float, y := 0.0) -> Transform3D:
	return Transform3D(Basis(), Vector3(x, y, z))

## Caja plana grande, partida en pedazos (así cada pedazo se recorta por separado).
static func _flat(b: MeshBatch, x0: float, x1: float, z0: float, z1: float, top: float, thick: float, mat: Material,
		layer := MeshBatch.NORMAL) -> void:
	var c := MeshBatch.CHUNK
	var x := x0
	while x < x1 - 0.001:
		var xe := minf(x1, (floorf(x / c + 0.0001) + 1.0) * c)
		var z := z0
		while z < z1 - 0.001:
			var ze := minf(z1, (floorf(z / c + 0.0001) + 1.0) * c)
			b.box(Vector3(xe - x, thick, ze - z), _p((x + xe) * 0.5, (z + ze) * 0.5, top - thick * 0.5), mat, layer)
			z = ze
		x = xe

static func _label(root: Node3D, text: String, xform: Transform3D, size := 64, c := Color.WHITE, far := 70.0) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = size
	l.pixel_size = 0.006
	l.modulate = c
	l.outline_size = 8
	l.outline_modulate = Color(0, 0, 0, 0.8)
	l.transform = xform
	l.visibility_range_end = far
	l.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(l)
	return l

# ---------------------------------------------------------------- piso y calles

static func _ground(b: MeshBatch, root: Node3D) -> void:
	var m := 60.0
	_flat(b, MAP.position.x - m, MAP.end.x + m, MAP.position.y - m, MAP.end.y + m, 0.0, 0.5, _tex("grass", Color.WHITE, 3.0, 1.0))
	# Una sola colisión para todo el piso.
	var body := StaticBody3D.new()
	body.name = "Piso"
	body.collision_layer = Config.L_WORLD
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(MAP.size.x + m * 2.0, 1.0, MAP.size.y + m * 2.0)
	shape.shape = box
	shape.position = Vector3(MAP.get_center().x, -0.5, MAP.get_center().y)
	body.add_child(shape)
	root.add_child(body)

static func _streets(b: MeshBatch, root: Node3D) -> void:
	var asphalt := _tex("asphalt", Color.WHITE, 4.0, 0.95)
	var x_lo: float = STREETS_X[0]
	var x_hi: float = STREETS_X[-1]
	var z_lo: float = STREETS_Z[0]
	var z_hi: float = STREETS_Z[-1]
	# Calles a lo largo de X (la avenida sigue al oeste, hasta la zona industrial).
	for z: float in STREETS_Z:
		var h := _half_z(z)
		var x0 := (AVENUE_WEST if z == AVENUE_Z else x_lo - HALF)
		_flat(b, x0, x_hi + HALF, z - h, z + h, 0.02, 0.02, asphalt)
	for x: float in STREETS_X:
		_flat(b, x - HALF, x + HALF, z_lo - HALF, z_hi + HALF, 0.02, 0.02, asphalt)
	_flat(b, IND_X - HALF, IND_X + HALF, IND_Z0, AVENUE_Z - AV_HALF, 0.02, 0.02, asphalt)
	# Líneas del medio (cortadas en las esquinas) y sendas peatonales.
	var line := Mats.color(Color(0.85, 0.78, 0.45), 0.8)
	var white := Mats.color(Color(0.86, 0.86, 0.84), 0.8)
	for z: float in STREETS_Z:
		var x0 := (AVENUE_WEST if z == AVENUE_Z else x_lo)
		var x := x0 + 4.0
		while x < x_hi - 4.0:
			if not _near_any(x, STREETS_X + ([IND_X, RAIL_X] if z == AVENUE_Z else []), _half_z(z) + 6.0):
				if z == AVENUE_Z:
					for s in [-0.12, 0.12]:
						b.box(Vector3(3.0, 0.004, 0.1), _p(x, z + s, 0.024), line, MeshBatch.DETAIL)
					for s in [-2.5, 2.5]:
						b.box(Vector3(1.8, 0.004, 0.12), _p(x, z + s, 0.024), white, MeshBatch.DETAIL)
				else:
					b.box(Vector3(1.8, 0.004, 0.14), _p(x, z, 0.024), line, MeshBatch.DETAIL)
			x += 6.0
	for x: float in STREETS_X + [IND_X]:
		var z0 := (IND_Z0 if x == IND_X else z_lo)
		var z1 := (AVENUE_Z - AV_HALF if x == IND_X else z_hi)
		var z := z0 + 4.0
		while z < z1 - 4.0:
			if not _near_any(z, STREETS_Z, HALF + 6.0):
				b.box(Vector3(0.14, 0.004, 1.8), _p(x, z, 0.024), line, MeshBatch.DETAIL)
			z += 6.0
	for x: float in STREETS_X:
		for z: float in STREETS_Z:
			var hz := _half_z(z)
			for s in [-1.0, 1.0]:
				# Senda que cruza la calle en X (antes de la esquina, sobre la calle en Z)...
				if (z + s * (hz + 2.0)) > z_lo - 1.0 and (z + s * (hz + 2.0)) < z_hi + 1.0:
					for i in 6:
						b.box(Vector3(0.5, 0.004, 2.2), _p(x - HALF + 0.6 + i * 1.12, z + s * (hz + 1.6), 0.025), white, MeshBatch.DETAIL)
				# ...y la que cruza la calle en X (si la calle sigue de ese lado).
				var cx: float = x + s * (HALF + 1.6)
				if (cx < x_lo - HALF and z != AVENUE_Z) or cx > x_hi + HALF:
					continue
				var n := int(hz * 2.0 / 1.12)
				for i in n:
					b.box(Vector3(2.2, 0.004, 0.5), _p(x + s * (HALF + 1.6), z - hz + 0.6 + i * 1.12, 0.025), white, MeshBatch.DETAIL)
	# Lomos de burro de la calle Los Aromos: si se pasan rápido, lo de la caja salta y se golpea.
	for x: float in SPEED_BUMPS_X:
		_speed_bump(root, Vector3(x, 0.0, 21.0))
	_street_signs(b, root)

static func _near_any(v: float, list: Array, d: float) -> bool:
	for c: float in list:
		if absf(v - c) < d:
			return true
	return false

## Lomo de burro: un triángulo bajo y ancho de cordón a cordón, pintado de amarillo y negro.
static func _speed_bump(root: Node3D, p: Vector3) -> void:
	var prism := PrismMesh.new()
	prism.size = Vector3(SPEED_BUMP_SIZE.x, SPEED_BUMP_SIZE.y, SPEED_BUMP_SIZE.z)
	var body := StaticBody3D.new()
	body.collision_layer = Config.L_WORLD
	body.collision_mask = 0
	body.position = p + Vector3(0, SPEED_BUMP_SIZE.y * 0.5, 0)
	root.add_child(body)
	var shape := CollisionShape3D.new()
	shape.shape = prism.create_convex_shape()
	body.add_child(shape)
	var mi := MeshInstance3D.new()
	mi.mesh = prism
	mi.material_override = _tex("asphalt", Color(0.75, 0.75, 0.75), 2.0, 0.9)
	body.add_child(mi)
	var paint := Mats.color(Color(0.95, 0.78, 0.15), 0.7)
	var n := 7
	for i in n:
		var z := -SPEED_BUMP_SIZE.z * 0.5 + (i + 0.5) * SPEED_BUMP_SIZE.z / n
		var stripe := MeshInstance3D.new()
		var sm := PrismMesh.new()
		sm.size = Vector3(SPEED_BUMP_SIZE.x + 0.02, SPEED_BUMP_SIZE.y + 0.01, SPEED_BUMP_SIZE.z / n * 0.5)
		stripe.mesh = sm
		stripe.material_override = paint
		stripe.position = Vector3(0, 0.003, z)
		body.add_child(stripe)

## Carteles con el nombre de las calles en cada esquina.
static func _street_signs(b: MeshBatch, root: Node3D) -> void:
	var post := _tex("metal", Color(0.3, 0.3, 0.32), 1.0, 0.5)
	var green := Mats.color(Color(0.08, 0.32, 0.2), 0.6)
	for i in STREETS_X.size():
		for j in STREETS_Z.size():
			var x: float = STREETS_X[i]
			var z: float = STREETS_Z[j]
			var p := Vector3(x + HALF + 0.5, 0, z + _half_z(z) + 0.5)
			b.solid(Vector3(0.08, 2.9, 0.08), _p(p.x, p.z, 1.45), post)
			b.box(Vector3(1.6, 0.28, 0.04), _p(p.x + 0.8, p.z, 2.75), green)
			b.box(Vector3(0.04, 0.28, 1.6), _p(p.x, p.z + 0.8, 2.45), green)
			_label(root, NAMES_Z[j], Transform3D(Basis(), Vector3(p.x + 0.8, 2.75, p.z + 0.03)), 28, Color.WHITE, 40.0)
			_label(root, NAMES_Z[j], Transform3D(Basis(Vector3.UP, PI), Vector3(p.x + 0.8, 2.75, p.z - 0.03)), 28, Color.WHITE, 40.0)
			_label(root, NAMES_X[i], Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(p.x + 0.03, 2.45, p.z + 0.8)), 28, Color.WHITE, 40.0)
			_label(root, NAMES_X[i], Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(p.x - 0.03, 2.45, p.z + 0.8)), 28, Color.WHITE, 40.0)

# ---------------------------------------------------------------- manzanas

## Vereda con cordón a lo largo de un borde de manzana.
static func _sidewalk(b: MeshBatch, x0: float, x1: float, z0: float, z1: float) -> void:
	_flat(b, x0, x1, z0, z1, 0.03, 0.03, _tex("concrete", Color.WHITE, 2.0, 0.9))

static func _curb_x(b: MeshBatch, x0: float, x1: float, z: float) -> void:
	_flat(b, x0, x1, z - 0.09, z + 0.09, 0.05, 0.05, _tex("concrete", Color(0.8, 0.8, 0.8), 1.0), MeshBatch.DETAIL)

static func _curb_z(b: MeshBatch, x: float, z0: float, z1: float) -> void:
	_flat(b, x - 0.09, x + 0.09, z0, z1, 0.05, 0.05, _tex("concrete", Color(0.8, 0.8, 0.8), 1.0), MeshBatch.DETAIL)

## Las manzanas entre las calles: veredas alrededor y, adentro, casas o comercios según el barrio.
static func _blocks(b: MeshBatch, root: Node3D, r: RandomNumberGenerator) -> void:
	for i in STREETS_X.size() - 1:
		for j in STREETS_Z.size() - 1:
			var xa: float = STREETS_X[i] + HALF
			var xb: float = STREETS_X[i + 1] - HALF
			var za: float = STREETS_Z[j] + _half_z(STREETS_Z[j])
			var zb: float = STREETS_Z[j + 1] - _half_z(STREETS_Z[j + 1])
			var wa := _walk_z(STREETS_Z[j])
			var wb := _walk_z(STREETS_Z[j + 1])
			_sidewalk(b, xa, xb, za, za + wa)
			_sidewalk(b, xa, xb, zb - wb, zb)
			_sidewalk(b, xa, xa + WALK, za + wa, zb - wb)
			_sidewalk(b, xb - WALK, xb, za + wa, zb - wb)
			_curb_x(b, xa, xb, za)
			_curb_x(b, xa, xb, zb)
			_curb_z(b, xa, za, zb)
			_curb_z(b, xb, za, zb)
			# Adentro de la manzana (sin veredas).
			var ix0 := xa + WALK
			var ix1 := xb - WALK
			var iz0 := za + wa
			var iz1 := zb - wb
			var mid := (iz0 + iz1) * 0.5
			if i == 1 and j == 2:
				_plaza(b, root, r, Rect2(ix0, iz0, ix1 - ix0, iz1 - iz0))
				continue
			# Fila de abajo (mira a la calle de menor z) y fila de arriba (a la de mayor z).
			var low := "shops" if STREETS_Z[j] == AVENUE_Z else "houses"
			var high := "shops" if STREETS_Z[j + 1] == AVENUE_Z else "houses"
			_row(b, root, r, i, low, ix0, ix1, iz0, mid - iz0, Vector3(0, 0, -1))
			_row(b, root, r, i, high, ix0, ix1, iz1, iz1 - mid, Vector3(0, 0, 1))
			_street_trees(b, r, xa, xb, za + 0.6, low == "houses")
			_street_trees(b, r, xa, xb, zb - 0.6, high == "houses")

## Árboles de vereda, cada tanto, del lado del cordón.
static func _street_trees(b: MeshBatch, r: RandomNumberGenerator, x0: float, x1: float, z: float, residential: bool) -> void:
	var x := x0 + 6.0 + r.randf_range(0.0, 4.0)
	while x < x1 - 6.0:
		if absf(x + 1.0) > 16.0 or absf(z - 17.0) > 1.0:   # no frente a lo de Don Ramón (ahí para el camión)
			if residential or r.randf() < 0.5:
				_tree(b, Vector3(x, 0, z), r.randf_range(0.8, 1.1))
				b.box(Vector3(1.0, 0.05, 1.0), _p(x, z, 0.04), _tex("bark", Color(0.6, 0.5, 0.45), 1.0), MeshBatch.DETAIL)
		x += r.randf_range(11.0, 17.0)

## Una fila de lotes a lo largo de una calle en X. `front_z` es la línea municipal y `facing`
## hacia dónde está la calle. `district`: 0 Villa Esperanza, 1 Los Aromos, 2 Las Lomas.
static func _row(b: MeshBatch, root: Node3D, r: RandomNumberGenerator, district: int, kind: String,
		x0: float, x1: float, front_z: float, depth: float, facing: Vector3) -> void:
	if kind == "shops":
		_shop_row(b, root, r, district, x0, x1, front_z, depth, facing)
		return
	var widths := [11.0, 15.5, 22.0]
	# La casa de Don Ramón ocupa su lote (x de -12 a 12) en la calle Los Aromos.
	var spans := [[x0, x1]]
	if district == 1 and absf(front_z - 15.6) < 0.1 and facing.z > 0.0:
		spans = [[x0, -12.0], [12.0, x1]]
	for sp: Array in spans:
		var length: float = sp[1] - sp[0]
		var n := maxi(1, roundi(length / widths[district]))
		var w := length / n
		for k in n:
			var cx: float = sp[0] + (k + 0.5) * w
			var t := _lot(Vector3(cx, 0, front_z), facing)
			var seed := r.randi()
			match district:
				0:
					_house_obrero(b, root, t, w, depth, seed)
				1:
					_house_aromos(b, root, t, w, depth, seed)
				_:
					_house_lomas(b, root, t, w, depth, seed)

# ---------------------------------------------------------------- piezas sueltas

## Árbol: tronco y copa en dos o tres bloques.
static func _tree(b: MeshBatch, p: Vector3, big := 1.0) -> void:
	b.solid(Vector3(0.35, 2.2, 0.35) * Vector3(big, 1, big), _p(p.x, p.z, 1.1), _tex("bark", Color.WHITE, 1.0))
	var leaves := _tex("leaves", Color.WHITE, 1.5, 1.0)
	var t := Transform3D(Basis(), p)
	b.box(Vector3(2.6, 1.9, 2.6) * big, _at(t, Vector3(0, 3.0 * big, 0), Vector3(0, 20, 0)), leaves)
	b.box(Vector3(1.9, 1.4, 1.9) * big, _at(t, Vector3(0, 4.3 * big, 0), Vector3(0, 55, 0)), leaves)

static func _bush(b: MeshBatch, t: Transform3D, p: Vector3, size: Vector3) -> void:
	b.solid(size, _at(t, p + Vector3(0, size.y * 0.5, 0)), _tex("leaves", Color(0.9, 1.0, 0.9), 1.0, 1.0))

## Auto estacionado (de adorno, pero sólido). Mira hacia +Z de `t`.
static func _car(b: MeshBatch, t: Transform3D, c: Color) -> void:
	var paint := Mats.tex("metal", c, 2.0, true, 0.35)
	b.solid(Vector3(1.8, 0.7, 4.2), _at(t, Vector3(0, 0.6, 0)), paint)
	b.box(Vector3(1.6, 0.6, 2.2), _at(t, Vector3(0, 1.25, -0.2)), paint)
	var glass := Mats.color(Color(0.12, 0.15, 0.2), 0.1, 0.0, 0.3)
	b.box(Vector3(1.62, 0.45, 2.0), _at(t, Vector3(0, 1.28, -0.2)), glass)
	b.box(Vector3(1.5, 0.42, 0.05), _at(t, Vector3(0, 1.25, 0.92), Vector3(-30, 0, 0)), glass)
	var tire := Mats.color(Color(0.06, 0.06, 0.06), 0.9)
	for sz in [-1.35, 1.35]:
		for sx in [-0.9, 0.9]:
			b.cylinder(0.33, 0.25, _at(t, Vector3(sx, 0.33, sz), Vector3(0, 0, 90)), tire, 10, MeshBatch.DETAIL)
	var tail := Mats.color(Color(0.6, 0.05, 0.05), 0.4, 0.6)
	for sx in [-0.65, 0.65]:
		b.box(Vector3(0.3, 0.12, 0.04), _at(t, Vector3(sx, 0.75, -2.11)), tail, MeshBatch.DETAIL)

static func _car_color(r: RandomNumberGenerator) -> Color:
	var list := [Color(0.2, 0.3, 0.5), Color(0.75, 0.75, 0.72), Color(0.15, 0.15, 0.16), Color(0.55, 0.12, 0.12),
			Color(0.9, 0.9, 0.88), Color(0.25, 0.4, 0.3), Color(0.5, 0.45, 0.38), Color(0.6, 0.6, 0.62)]
	return list[r.randi() % list.size()]

## Farol de la calle. `facing` apunta desde el poste hacia la calle.
static func _street_lamp(b: MeshBatch, root: Node3D, p: Vector3, facing: Vector3, c := LAMP_COLOR, real := true) -> void:
	var t := _lot(p, facing)
	var dark := _tex("metal", Color(0.25, 0.25, 0.27), 1.0, 0.5)
	b.solid(Vector3(0.15, 4.5, 0.15), _at(t, Vector3(0, 2.25, 0)), dark)
	b.box(Vector3(0.12, 0.1, 0.9), _at(t, Vector3(0, 4.5, 0.4)), dark)
	b.box(Vector3(0.3, 0.12, 0.25), _at(t, Vector3(0, 4.42, 0.75)), Mats.color(c, 0.5, 3.0), MeshBatch.GLOW)
	b.plane(13.0, 13.0, _at(t, Vector3(0, 0.04, 1.2)), _pool_mat(Color(c.r, c.g, c.b, 0.32)))
	if real:
		var light := OmniLight3D.new()
		light.light_color = c
		light.light_energy = 1.6
		light.omni_range = 14.0
		light.distance_fade_enabled = true
		light.distance_fade_begin = 38.0
		light.distance_fade_length = 12.0
		light.transform = _at(t, Vector3(0, 4.2, 0.75))
		root.add_child(light)

## Faroles a lo largo de todas las calles, alternando de vereda.
static func _lamps(b: MeshBatch, root: Node3D) -> void:
	for z: float in STREETS_Z:
		var off := _half_z(z) + _walk_z(z) - 0.4
		var x0 := (AVENUE_WEST + 10.0 if z == AVENUE_Z else float(STREETS_X[0]) + 10.0)
		var x := x0
		var side := 1.0
		while x < float(STREETS_X[-1]) - 8.0:
			var crossing := _near_any(x, STREETS_X + [IND_X, RAIL_X], 9.0)
			# Frente a lo de Don Ramón ya hay uno (que no le dé en la ventana del dormitorio).
			if not crossing and not (z == 21.0 and absf(x) < 13.0):
				var real := x > -175.0 or z == AVENUE_Z
				_street_lamp(b, root, Vector3(x, 0, z + side * off), Vector3(0, 0, -side), LAMP_COLOR if x > -175.0 else SODIUM, real)
			x += 26.0
			side = -side
	for x: float in STREETS_X:
		var z := float(STREETS_Z[0]) + 14.0
		var side := 1.0
		while z < float(STREETS_Z[-1]) - 8.0:
			if not _near_any(z, STREETS_Z, 10.0):
				_street_lamp(b, root, Vector3(x + side * (HALF + WALK - 0.4), 0, z), Vector3(-side, 0, 0))
			z += 28.0
			side = -side
	_street_lamp(b, root, Vector3(-18.0, 0, 16.0), Vector3(0, 0, 1))
	_street_lamp(b, root, Vector3(14.0, 0, 16.0), Vector3(0, 0, 1))

## Autos estacionados junto al cordón (de un solo lado en las calles angostas, para que pase el camión).
static func _parked_cars(b: MeshBatch, r: RandomNumberGenerator) -> void:
	for z: float in STREETS_Z:
		var sides := [1.0, -1.0] if z == AVENUE_Z else [1.0]
		for s: float in sides:
			var x := float(STREETS_X[0]) + 12.0
			while x < float(STREETS_X[-1]) - 12.0:
				if not _near_any(x, STREETS_X, 13.0) and not (z == 21.0 and x > -50.0 and x < 30.0) and r.randf() < 0.42:
					var t := Transform3D(Basis(Vector3.UP, PI * 0.5 if s > 0.0 else -PI * 0.5), Vector3(x, 0, z + s * (_half_z(z) - 0.95)))
					_car(b, t, _car_color(r))
				x += r.randf_range(6.5, 11.0)
	for x: float in STREETS_X:
		var z := float(STREETS_Z[0]) + 12.0
		while z < float(STREETS_Z[-1]) - 12.0:
			if not _near_any(z, STREETS_Z, 13.0) and r.randf() < 0.35:
				_car(b, Transform3D(Basis(), Vector3(x + HALF - 0.95, 0, z)), _car_color(r))
			z += r.randf_range(7.0, 12.0)
	# Los de la calle de Don Ramón (como estaban).
	_car(b, Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(2.0, 0, 23.3)), Color(0.2, 0.3, 0.5))
	_car(b, Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(20.0, 0, 23.3)), Color(0.75, 0.75, 0.72))
	_car(b, Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(-24.0, 0, 23.3)), Color(0.15, 0.15, 0.16))

# ---------------------------------------------------------------- casas

const OBRERO_PAINTS := [Color(0.55, 0.78, 0.86), Color(0.95, 0.82, 0.45), Color(0.9, 0.6, 0.55), Color(0.6, 0.82, 0.62),
		Color(0.96, 0.94, 0.88), Color(0.86, 0.55, 0.35), Color(0.75, 0.68, 0.86), Color(0.98, 0.7, 0.5)]

## Ventana de frente (algunas con luz adentro), con marco y postigos.
static func _front_window(b: MeshBatch, t: Transform3D, x: float, y: float, z: float, lit: bool, trim: Material,
		shutter: Material, w := 1.1, h := 1.2) -> void:
	var glass := Mats.color(Color(1.0, 0.8, 0.5), 0.5, 1.6) if lit else Mats.color(Color(0.18, 0.24, 0.36), 0.1, 0.35)
	b.box(Vector3(w, h, 0.06), _at(t, Vector3(x, y, z + 0.03)), glass, MeshBatch.GLOW if lit else MeshBatch.NORMAL)
	b.box(Vector3(w + 0.14, 0.08, 0.1), _at(t, Vector3(x, y + h * 0.5 + 0.02, z + 0.05)), trim, MeshBatch.DETAIL)
	b.box(Vector3(w + 0.2, 0.06, 0.16), _at(t, Vector3(x, y - h * 0.5 - 0.03, z + 0.08)), trim, MeshBatch.DETAIL)
	if shutter:
		for s in [-1.0, 1.0]:
			b.box(Vector3(0.34, h + 0.05, 0.05), _at(t, Vector3(x + s * (w * 0.5 + 0.23), y, z + 0.04)), shutter, MeshBatch.DETAIL)

## Luz chica sobre la puerta: un foquito y su mancha en el piso (sin luz de verdad).
static func _porch_light(b: MeshBatch, t: Transform3D, p: Vector3, on: bool) -> void:
	b.box(Vector3(0.16, 0.22, 0.12), _at(t, p), Mats.color(Color(1.0, 0.8, 0.5), 0.5, 2.2 if on else 0.0), MeshBatch.GLOW)
	if on:
		b.plane(5.0, 5.0, _at(t, Vector3(p.x, 0.045, p.z + 1.6)), _pool_mat(Color(1.0, 0.75, 0.45, 0.4)))

## Casa de Los Aromos (como las de antes): revestimiento, techo a dos aguas, garaje en algunas.
static func _house_aromos(b: MeshBatch, root: Node3D, lot: Transform3D, lot_w: float, depth: float, seed: int) -> void:
	var r := RandomNumberGenerator.new()
	r.seed = seed
	var style := HouseBuilder.make_style(seed % 100000)
	var garage := lot_w >= 15.0 and r.randf() < 0.55
	var w := r.randf_range(8.5, minf(12.0, lot_w - (7.0 if garage else 3.0)))
	var d := r.randf_range(8.0, minf(10.0, depth - 9.0))
	var setback := r.randf_range(5.0, 7.0)
	var shift := (-2.2 if garage else 0.0) * (1.0 if r.randf() < 0.5 else -1.0)
	var t := _at(lot, Vector3(shift, 0, -setback - d * 0.5))
	var floors := 2 if r.randf() < 0.45 else 1
	var hh := 2.9 * floors
	var ext := HouseBuilder.style_material(style["ext"])
	var trim := HouseBuilder.style_material(style["trim"])
	var roof := HouseBuilder.style_material(style["roof"])
	b.solid(Vector3(w, hh, d), _at(t, Vector3(0, hh * 0.5, 0)), ext)
	b.box(Vector3(w + 0.04, 0.5, d + 0.04), _at(t, Vector3(0, 0.25, 0)), HouseBuilder.style_material(style["found"]))
	b.roof(Vector3(w + 1.0, r.randf_range(2.0, 3.0), d + 1.2), _at(t, Vector3(0, hh, 0)), roof)
	for s in [-1.0, 1.0]:
		b.box(Vector3(w + 1.0, 0.18, 0.06), _at(t, Vector3(0, hh - 0.02, s * (d * 0.5 + 0.62))), trim, MeshBatch.DETAIL)
	var front := d * 0.5
	var door_x := r.randf_range(-w * 0.25, w * 0.25)
	b.box(Vector3(1.0, 2.1, 0.08), _at(t, Vector3(door_x, 1.05, front + 0.04)), Mats.tex("door_wood", style["front_door"], 1.0, true, 0.5))
	b.box(Vector3(2.2, 0.12, 1.2), _at(t, Vector3(door_x, 2.6, front + 0.6), Vector3(-8, 0, 0)), roof)
	_porch_light(b, t, Vector3(door_x + 0.8, 2.2, front + 0.08), r.randf() < 0.6)
	var shutter := HouseBuilder.style_material(style["shutter"])
	for fl in floors:
		for wx in [-w * 0.36, -w * 0.15, w * 0.15, w * 0.36]:
			if fl == 0 and absf(wx - door_x) < 1.5:
				continue
			_front_window(b, t, wx, 1.5 + fl * 2.9, front, r.randf() < 0.3, trim, shutter)
	if r.randf() < 0.5:
		b.box(Vector3(0.7, 2.0, 0.7), _at(t, Vector3(w * 0.3, hh + 1.6, -d * 0.15)), _tex("brick", Color(0.85, 0.8, 0.78), 1.0))
	for s in [-1.0, 1.0]:
		_bush(b, t, Vector3(s * w * 0.3, 0, front + 0.6), Vector3(w * 0.25, 0.8, 0.8))
	# Garaje al costado, con entrada de autos hasta la vereda.
	var concrete := _tex("concrete", Color(0.9, 0.9, 0.9), 2.0)
	if garage:
		var gx := shift + (w * 0.5 + 2.1) * (-signf(shift))
		var gt := _at(lot, Vector3(gx, 0, -setback - d * 0.4))
		b.solid(Vector3(4.0, 2.7, d * 0.8), _at(gt, Vector3(0, 1.35, 0)), ext)
		b.box(Vector3(4.2, 0.15, d * 0.8 + 0.3), _at(gt, Vector3(0, 2.75, 0)), roof)
		b.box(Vector3(3.0, 2.2, 0.06), _at(gt, Vector3(0, 1.1, d * 0.4 + 0.03)), Mats.tex("siding", Color(0.9, 0.9, 0.88), 0.6, true, 0.5))
		b.box(Vector3(3.2, 0.03, setback + d * 0.1), _at(lot, Vector3(gx, 0.03, -(setback + d * 0.1) * 0.5)), concrete)
		if r.randf() < 0.6:
			_car(b, _at(lot, Vector3(gx, 0, -setback * 0.45), Vector3(0, 180, 0)), _car_color(r))
	else:
		b.box(Vector3(1.2, 0.03, setback), _at(lot, Vector3(shift + door_x, 0.03, -setback * 0.5)), _tex("stone", Color(0.9, 0.9, 0.9), 1.0))
	# Cerco: ligustro bajo o cerca blanca, con paso para el camino.
	_front_fence(b, lot, lot_w, r, [shift + door_x] + ([shift + (w * 0.5 + 2.1) * (-signf(shift))] if garage else []), r.randi() % 3)
	if r.randf() < 0.55:
		_tree(b, (lot * Vector3(r.randf_range(-lot_w * 0.35, lot_w * 0.35), 0, -setback * 0.5)), r.randf_range(0.9, 1.15))
	# Buzón y tacho.
	var mx := shift + door_x + 1.3
	b.solid(Vector3(0.1, 1.0, 0.1), _at(lot, Vector3(mx, 0.5, -0.4)), _tex("door_wood", Color(0.7, 0.6, 0.5), 1.0))
	b.box(Vector3(0.45, 0.25, 0.25), _at(lot, Vector3(mx, 1.1, -0.4)), _tex("metal", Color(0.2, 0.25, 0.35), 1.0, 0.4), MeshBatch.DETAIL)

## Cerco del frente: 0 ligustro, 1 cerca de madera, 2 nada. `gaps`: dónde dejar paso (x local).
static func _front_fence(b: MeshBatch, lot: Transform3D, lot_w: float, r: RandomNumberGenerator, gaps: Array, kind: int) -> void:
	if kind == 2:
		return
	var segs := _gaps(-lot_w * 0.5 + 0.3, lot_w * 0.5 - 0.3, gaps, 1.9)
	for s: Array in segs:
		var a: float = s[0]
		var c: float = s[1]
		if c - a < 0.4:
			continue
		if kind == 0:
			_bush(b, lot, Vector3((a + c) * 0.5, 0, -0.5), Vector3(c - a, 0.9, 0.6))
		else:
			var wood := _tex("door_wood", Color(0.95, 0.94, 0.9), 1.0, 0.8)
			b.solid(Vector3(c - a, 0.08, 0.06), _at(lot, Vector3((a + c) * 0.5, 0.75, -0.4)), wood)
			b.box(Vector3(c - a, 0.08, 0.06), _at(lot, Vector3((a + c) * 0.5, 0.35, -0.4)), wood, MeshBatch.DETAIL)
			var x := a + 0.1
			while x < c:
				b.box(Vector3(0.09, 0.95, 0.04), _at(lot, Vector3(x, 0.48, -0.36)), wood, MeshBatch.DETAIL)
				x += 0.3

## Parte el tramo [a, b] dejando huecos de `width` alrededor de cada x de `gaps`.
static func _gaps(a: float, c: float, gaps: Array, width: float) -> Array:
	var cuts := gaps.duplicate()
	cuts.sort()
	var out := []
	var x := a
	for g: float in cuts:
		if g - width * 0.5 > x:
			out.append([x, g - width * 0.5])
		x = maxf(x, g + width * 0.5)
	if x < c:
		out.append([x, c])
	return out

## Casa de Villa Esperanza: lote angosto, techo plano con tanque de agua, pared con reja al frente.
static func _house_obrero(b: MeshBatch, root: Node3D, lot: Transform3D, lot_w: float, depth: float, seed: int) -> void:
	var r := RandomNumberGenerator.new()
	r.seed = seed
	var w := lot_w - r.randf_range(0.6, 1.6)
	var d := r.randf_range(8.0, minf(11.0, depth - 6.0))
	var setback := r.randf_range(2.5, 4.0)
	var t := _at(lot, Vector3(0, 0, -setback - d * 0.5))
	var floors := 2 if r.randf() < 0.3 else 1
	var hh := 2.8 * floors
	var paint_c: Color = OBRERO_PAINTS[r.randi() % OBRERO_PAINTS.size()]
	var tex_name: String = ["paint", "stucco", "brick"][r.randi() % 3]
	var ext := _tex(tex_name, paint_c if tex_name != "brick" else Color(1, 1, 1), 2.0 if tex_name != "brick" else 1.0, 0.9)
	var trim := _tex("paint", Color(0.95, 0.95, 0.93), 1.0, 0.6)
	var concrete := _tex("concrete", Color(0.75, 0.75, 0.75), 2.0)
	b.solid(Vector3(w, hh, d), _at(t, Vector3(0, hh * 0.5, 0)), ext)
	# Techo plano: losa, parapeto y tanque de agua.
	b.box(Vector3(w + 0.1, 0.2, d + 0.1), _at(t, Vector3(0, hh + 0.1, 0)), concrete)
	b.box(Vector3(w + 0.1, 0.5, 0.15), _at(t, Vector3(0, hh + 0.45, d * 0.5)), ext)
	if r.randf() < 0.75:
		var tank := _tex("plastic", [Color(0.15, 0.2, 0.4), Color(0.85, 0.85, 0.82), Color(0.2, 0.2, 0.22)][r.randi() % 3], 1.0, 0.5)
		b.cylinder(0.6, 1.1, _at(t, Vector3(r.randf_range(-w * 0.3, w * 0.3), hh + 0.95, -d * 0.2)), tank, 10)
	var front := d * 0.5
	var door_x := r.randf_range(-w * 0.3, w * 0.1)
	b.box(Vector3(0.95, 2.1, 0.08), _at(t, Vector3(door_x, 1.05, front + 0.04)), _tex("metal", Color(0.3, 0.3, 0.32), 1.0, 0.5))
	_porch_light(b, t, Vector3(door_x + 0.75, 2.2, front + 0.08), r.randf() < 0.5)
	var has_garage := w > 8.0 and r.randf() < 0.55
	var gx := w * 0.25
	if has_garage:
		b.box(Vector3(2.8, 2.3, 0.06), _at(t, Vector3(gx, 1.15, front + 0.03)), _tex("metal", Color(0.6, 0.62, 0.6), 0.5, 0.5))
	for fl in floors:
		for wx in ([-w * 0.32, w * 0.3] if fl == 0 else [-w * 0.3, 0.0, w * 0.3]):
			if fl == 0 and (absf(wx - door_x) < 1.4 or (has_garage and absf(wx - gx) < 1.8)):
				continue
			_front_window(b, t, wx, 1.5 + fl * 2.8, front, r.randf() < 0.4, trim, null)
			# Rejas en las ventanas de abajo.
			if fl == 0:
				for i in 5:
					b.box(Vector3(0.03, 1.25, 0.03), _at(t, Vector3(wx - 0.5 + i * 0.25, 1.5, front + 0.12)), _tex("metal", Color(0.15, 0.15, 0.15), 1.0), MeshBatch.DETAIL)
	if r.randf() < 0.4:
		# Alero de chapa.
		b.box(Vector3(w * 0.6, 0.06, 1.4), _at(t, Vector3(-w * 0.1, 2.5, front + 0.7), Vector3(-10, 0, 0)), _tex("metal", Color(0.65, 0.66, 0.68), 1.0, 0.4))
	# Patio de cemento y pared baja con reja.
	b.box(Vector3(lot_w - 0.4, 0.03, setback), _at(lot, Vector3(0, 0.025, -setback * 0.5)), concrete)
	var wall := _tex("stucco", paint_c.lerp(Color(0.9, 0.9, 0.9), 0.4), 2.0)
	var bars := _tex("metal", Color(0.12, 0.12, 0.13), 1.0, 0.5)
	for s: Array in _gaps(-lot_w * 0.5 + 0.2, lot_w * 0.5 - 0.2, [door_x] + ([gx] if has_garage else []), 1.4):
		var a: float = s[0]
		var c: float = s[1]
		if c - a < 0.3:
			continue
		b.solid(Vector3(c - a, 0.7, 0.2), _at(lot, Vector3((a + c) * 0.5, 0.35, -0.3)), wall)
		b.box(Vector3(c - a, 0.05, 0.05), _at(lot, Vector3((a + c) * 0.5, 1.6, -0.3)), bars, MeshBatch.DETAIL)
		var x := a + 0.08
		while x < c:
			b.box(Vector3(0.03, 0.9, 0.03), _at(lot, Vector3(x, 1.15, -0.3)), bars, MeshBatch.DETAIL)
			x += 0.18
	if has_garage and r.randf() < 0.5:
		_car(b, _at(lot, Vector3(gx, 0, -setback * 0.5 - 0.8), Vector3(0, 180, 0)), _car_color(r))
	if r.randf() < 0.3:
		_tree(b, lot * Vector3(-lot_w * 0.3, 0, -setback - d - 3.0), 0.9)

## Casa de Las Lomas: lote ancho, dos pisos, garaje doble, ligustro y luces de jardín.
static func _house_lomas(b: MeshBatch, root: Node3D, lot: Transform3D, lot_w: float, depth: float, seed: int) -> void:
	var r := RandomNumberGenerator.new()
	r.seed = seed
	var style := HouseBuilder.make_style(seed % 100000 + 7)
	var w := r.randf_range(12.0, minf(15.0, lot_w - 7.5))
	var d := r.randf_range(9.5, minf(12.0, depth - 10.0))
	var setback := r.randf_range(7.0, 9.0)
	var shift := -2.8
	var t := _at(lot, Vector3(shift, 0, -setback - d * 0.5))
	var floors := 2 if r.randf() < 0.7 else 1
	var hh := 3.0 * floors
	var ext := HouseBuilder.style_material(style["ext"])
	var trim := HouseBuilder.style_material(style["trim"])
	var roof := HouseBuilder.style_material(style["roof"])
	var shutter := HouseBuilder.style_material(style["shutter"])
	b.solid(Vector3(w, hh, d), _at(t, Vector3(0, hh * 0.5, 0)), ext)
	b.box(Vector3(w + 0.04, 0.6, d + 0.04), _at(t, Vector3(0, 0.3, 0)), HouseBuilder.style_material(style["found"]))
	b.roof(Vector3(w + 1.2, r.randf_range(2.4, 3.4), d + 1.4), _at(t, Vector3(0, hh, 0)), roof)
	# Cuerpo de adelante con otro techo (la entrada).
	var ew := 4.2
	b.solid(Vector3(ew, hh, 2.0), _at(t, Vector3(-w * 0.18, hh * 0.5, d * 0.5 + 1.0)), ext)
	b.roof(Vector3(2.6, 1.8, ew + 0.6), _at(t, Vector3(-w * 0.18, hh, d * 0.5 + 1.0), Vector3(0, 90, 0)), roof)
	var front := d * 0.5
	var door_x := -w * 0.18
	b.box(Vector3(1.4, 2.3, 0.08), _at(t, Vector3(door_x, 1.15, front + 2.04)), Mats.tex("door_wood", style["front_door"], 1.0, true, 0.5))
	_porch_light(b, t, Vector3(door_x + 1.0, 2.4, front + 2.08), true)
	_front_window(b, t, door_x, 1.6 + 3.0 * (floors - 1), front + 2.0, r.randf() < 0.5, trim, null, 1.6, 1.2)
	for fl in floors:
		for wx in [-w * 0.42, w * 0.08, w * 0.3]:
			_front_window(b, t, wx, 1.6 + fl * 3.0, front, r.randf() < 0.35, trim, shutter, 1.3, 1.4)
	# Garaje doble.
	var gx := shift + w * 0.5 + 3.4
	var gt := _at(lot, Vector3(gx, 0, -setback - 3.2))
	b.solid(Vector3(6.4, 2.8, 6.4), _at(gt, Vector3(0, 1.4, 0)), ext)
	b.box(Vector3(6.6, 0.2, 6.8), _at(gt, Vector3(0, 2.9, 0)), roof)
	var door := Mats.tex("siding", Color(0.92, 0.92, 0.9), 0.6, true, 0.5)
	for s in [-1.0, 1.0]:
		b.box(Vector3(2.5, 2.2, 0.06), _at(gt, Vector3(s * 1.5, 1.1, 3.23)), door)
	var paving := _tex("stone", Color(0.85, 0.82, 0.78), 1.4)
	b.box(Vector3(6.2, 0.03, setback - 0.0), _at(lot, Vector3(gx, 0.03, -setback * 0.5 + 0.2)), paving)
	b.box(Vector3(1.6, 0.03, setback - 2.0), _at(lot, Vector3(shift + door_x, 0.03, -(setback - 2.0) * 0.5)), paving)
	if r.randf() < 0.7:
		_car(b, _at(lot, Vector3(gx - 1.5, 0, -setback * 0.5), Vector3(0, 180, 0)), _car_color(r))
	# Ligustro alto al frente y luces de jardín.
	_front_fence(b, lot, lot_w, r, [shift + door_x, gx - 1.5, gx + 1.5], 0)
	for i in 3:
		var lx := shift + door_x + (-1.0 if i % 2 == 0 else 1.0) * 1.2
		var lz := -1.5 - i * 1.8
		b.box(Vector3(0.12, 0.6, 0.12), _at(lot, Vector3(lx, 0.3, lz)), Mats.color(Color(1.0, 0.85, 0.6), 0.5, 2.0), MeshBatch.GLOW)
		b.plane(2.4, 2.4, _at(lot, Vector3(lx, 0.05, lz)), _pool_mat(Color(1.0, 0.8, 0.5, 0.35)))
	for k in 2:
		_tree(b, lot * Vector3(r.randf_range(-lot_w * 0.45, -lot_w * 0.2), 0, -r.randf_range(2.5, setback - 1.0)), r.randf_range(1.0, 1.25))

# ---------------------------------------------------------------- comercios

const SHOPS := [
	["Panadería La Espiga", Color(0.8, 0.55, 0.25), false], ["Ferretería El Tornillo", Color(0.85, 0.2, 0.15), false],
	["Farmacia de Turno", Color(0.15, 0.6, 0.35), true], ["Kiosco 24 hs", Color(0.95, 0.75, 0.15), true],
	["Pizzería Don Pepe", Color(0.75, 0.15, 0.12), true], ["Verdulería La Huerta", Color(0.35, 0.65, 0.25), false],
	["Carnicería El Novillo", Color(0.6, 0.12, 0.15), false], ["Lavandería Burbujas", Color(0.3, 0.55, 0.85), false],
	["Peluquería Estilo", Color(0.75, 0.35, 0.65), false], ["Librería El Lápiz", Color(0.2, 0.35, 0.65), false],
	["Bar El Farol", Color(0.55, 0.3, 0.15), true], ["Heladería Polar", Color(0.4, 0.75, 0.9), false],
	["Zapatería Paso Firme", Color(0.35, 0.3, 0.28), false], ["Mueblería Confort", Color(0.55, 0.42, 0.3), false],
	["Electro Hogar", Color(0.15, 0.3, 0.6), false], ["Gimnasio Fuerza", Color(0.2, 0.2, 0.22), false],
	["Cerrajería La Llave", Color(0.85, 0.65, 0.15), false], ["Bazar Todo Hogar", Color(0.85, 0.45, 0.2), false],
	["Pollería El Gallo", Color(0.9, 0.55, 0.1), true], ["Óptica Visión", Color(0.25, 0.45, 0.55), false],
	["Taller Ruedas", Color(0.3, 0.3, 0.35), false], ["Tienda La Esquina", Color(0.65, 0.2, 0.3), true],
]

static var _shop_index := 0

## Colores de toldo y cartel: pocos (cada material distinto es un dibujo más para la placa de video),
## así que cada comercio usa el más parecido de esta lista.
const BRANDS := [Color(0.8, 0.18, 0.14), Color(0.15, 0.55, 0.32), Color(0.92, 0.7, 0.15), Color(0.2, 0.38, 0.7),
		Color(0.6, 0.32, 0.18), Color(0.7, 0.3, 0.6), Color(0.3, 0.3, 0.33), Color(0.35, 0.68, 0.85)]

static func _brand(c: Color) -> Color:
	var best: Color = BRANDS[0]
	for o: Color in BRANDS:
		if Vector3(o.r - c.r, o.g - c.g, o.b - c.b).length() < Vector3(best.r - c.r, best.g - c.g, best.b - c.b).length():
			best = o
	return best

## Fila de comercios mirando a la avenida (en la esquina de Las Lomas, la estación de servicio).
static func _shop_row(b: MeshBatch, root: Node3D, r: RandomNumberGenerator, district: int, x0: float, x1: float,
		front_z: float, depth: float, facing: Vector3) -> void:
	if district == 2 and facing.z > 0.0:
		_gas_station(b, root, _lot(Vector3(x0 + 15.0, 0, front_z), facing), 28.0, depth)
		x0 += 30.0
	var n := maxi(1, roundi((x1 - x0) / 13.0))
	var w := (x1 - x0) / n
	for k in n:
		var t := _lot(Vector3(x0 + (k + 0.5) * w, 0, front_z), facing)
		var shop: Array = SHOPS[_shop_index % SHOPS.size()]
		_shop_index += 1
		_shop(b, root, t, w, depth, r.randi(), shop[0], _brand(shop[1]), shop[2])

static func _shop(b: MeshBatch, root: Node3D, lot: Transform3D, lot_w: float, depth: float, seed: int,
		shop_name: String, c: Color, open: bool) -> void:
	var r := RandomNumberGenerator.new()
	r.seed = seed
	var w := lot_w - 0.25
	var d := minf(depth - 4.0, r.randf_range(12.0, 16.0))
	var floors := 2 if r.randf() < 0.55 else 1
	var hh := 3.8 + 3.0 * (floors - 1)
	var t := _at(lot, Vector3(0, 0, -d * 0.5))
	var wall_c: Color = [Color(0.92, 0.9, 0.85), Color(0.85, 0.82, 0.75), Color(0.8, 0.84, 0.86), Color(0.9, 0.86, 0.8)][r.randi() % 4]
	var wall_tex: String = ["stucco", "brick", "paint"][r.randi() % 3]
	var ext := _tex(wall_tex, wall_c, 2.0, 0.9)
	var trim := _tex("paint", Color(0.95, 0.95, 0.93), 1.0, 0.6)
	b.solid(Vector3(w, hh, d), _at(t, Vector3(0, hh * 0.5, 0)), ext)
	b.box(Vector3(w + 0.1, 0.6, d + 0.1), _at(t, Vector3(0, hh + 0.3, 0)), ext)
	b.box(Vector3(w + 0.2, 0.12, 0.3), _at(t, Vector3(0, hh + 0.62, d * 0.5)), trim, MeshBatch.DETAIL)
	var front := d * 0.5
	# Vidriera (prendida si está abierto; si no, con la persiana baja).
	var vw := w - 2.6
	if open:
		# Pocas tintas de vidriera (cada material distinto es un dibujo más para la placa de video).
		var tint: Color = [Color(1.0, 0.93, 0.8), Color(0.88, 0.95, 1.0), Color(1.0, 0.85, 0.7)][seed % 3]
		b.box(Vector3(vw, 2.4, 0.06), _at(t, Vector3(-0.8, 1.45, front + 0.03)), Mats.color(tint, 0.4, 1.4), MeshBatch.GLOW)
		b.plane(vw + 3.0, 5.0, _at(lot, Vector3(-0.8, 0.045, 2.0)), _pool_mat(Color(tint, 0.45)))
		# Estanterías que se ven a contraluz.
		for i in int(vw / 1.6):
			b.box(Vector3(0.9, 1.6, 0.05), _at(t, Vector3(-0.8 - vw * 0.5 + 0.8 + i * 1.6, 1.0, front + 0.07)), Mats.color(Color(0.18, 0.16, 0.15), 0.9), MeshBatch.DETAIL)
		var light := OmniLight3D.new()
		light.light_color = tint
		light.light_energy = 1.0
		light.omni_range = 7.0
		light.distance_fade_enabled = true
		light.distance_fade_begin = 30.0
		light.distance_fade_length = 10.0
		light.transform = _at(lot, Vector3(-0.8, 2.2, 1.0))
		root.add_child(light)
	else:
		b.box(Vector3(vw, 2.5, 0.06), _at(t, Vector3(-0.8, 1.4, front + 0.04)), _tex("metal", Color(0.55, 0.56, 0.58), 0.4, 0.5))
	b.box(Vector3(1.1, 2.2, 0.06), _at(t, Vector3(w * 0.5 - 1.0, 1.1, front + 0.03)), _tex("metal", Color(0.25, 0.25, 0.27), 1.0, 0.5))
	# Toldo y cartel.
	b.box(Vector3(w - 0.4, 0.08, 1.5), _at(t, Vector3(0, 2.95, front + 0.7), Vector3(-14, 0, 0)), _tex("fabric", c, 0.8, 1.0))
	b.box(Vector3(w - 0.6, 0.8, 0.12), _at(t, Vector3(0, 3.55, front + 0.08)), Mats.color(c.darkened(0.25), 0.7, 0.6 if open else 0.15))
	_label(root, shop_name, _at(t, Vector3(0, 3.55, front + 0.16)), 72 if shop_name.length() < 16 else 60,
			Color(1, 1, 0.95), 80.0)
	# Arriba: departamento con ventanas, aires acondicionados y tanque.
	if floors == 2:
		for wx in [-w * 0.3, w * 0.05, w * 0.32]:
			_front_window(b, t, wx, 5.4, front, r.randf() < 0.35, trim, null, 1.2, 1.3)
			if r.randf() < 0.4:
				b.box(Vector3(0.8, 0.5, 0.45), _at(t, Vector3(wx, 4.6, front + 0.25)), _tex("plastic", Color(0.85, 0.85, 0.83), 1.0, 0.5), MeshBatch.DETAIL)
	if r.randf() < 0.6:
		b.cylinder(0.6, 1.1, _at(t, Vector3(r.randf_range(-w * 0.3, w * 0.3), hh + 0.85, -d * 0.25)), _tex("plastic", Color(0.15, 0.2, 0.4), 1.0, 0.5), 10)
	# Vereda ancha de cemento hasta la vidriera.
	b.box(Vector3(lot_w, 0.03, depth - d), _at(lot, Vector3(0, 0.025, -d - (depth - d) * 0.5)), _tex("concrete", Color(0.7, 0.7, 0.7), 2.0))

## Estación de servicio: techo con luces, surtidores y un minimercado atrás.
static func _gas_station(b: MeshBatch, root: Node3D, lot: Transform3D, w: float, depth: float) -> void:
	var concrete := _tex("concrete", Color(0.85, 0.85, 0.85), 2.0)
	b.box(Vector3(w, 0.03, depth), _at(lot, Vector3(0, 0.028, -depth * 0.5)), concrete)
	var red := Mats.color(Color(0.75, 0.12, 0.1), 0.5, 0.3)
	var white := Mats.color(Color(0.95, 0.95, 0.95), 0.6)
	var canopy := _at(lot, Vector3(0, 0, -8.0))
	for sx in [-6.0, 6.0]:
		for sz in [-3.0, 3.0]:
			b.solid(Vector3(0.4, 4.6, 0.4), _at(canopy, Vector3(sx, 2.3, sz)), white)
	b.box(Vector3(16.0, 0.8, 9.0), _at(canopy, Vector3(0, 4.9, 0)), white)
	b.box(Vector3(16.1, 0.4, 9.1), _at(canopy, Vector3(0, 5.0, 0)), red)
	b.box(Vector3(15.0, 0.04, 8.0), _at(canopy, Vector3(0, 4.48, 0)), Mats.color(Color(1, 1, 0.95), 0.5, 2.5), MeshBatch.GLOW)
	b.plane(20.0, 14.0, _at(canopy, Vector3(0, 0.05, 0)), _pool_mat(Color(1, 1, 0.95, 0.5)))
	for sx in [-3.0, 3.0]:
		b.solid(Vector3(1.0, 0.25, 3.4), _at(canopy, Vector3(sx, 0.12, 0)), concrete)
		for sz in [-0.9, 0.9]:
			b.solid(Vector3(0.6, 1.6, 0.5), _at(canopy, Vector3(sx, 1.05, sz)), red)
			b.box(Vector3(0.62, 0.35, 0.4), _at(canopy, Vector3(sx, 1.45, sz)), Mats.color(Color(0.4, 0.9, 0.5), 0.5, 1.5), MeshBatch.GLOW)
	var light := OmniLight3D.new()
	light.light_color = Color(1, 1, 0.95)
	light.light_energy = 2.0
	light.omni_range = 14.0
	light.distance_fade_enabled = true
	light.distance_fade_begin = 45.0
	light.distance_fade_length = 15.0
	light.transform = _at(canopy, Vector3(0, 4.2, 0))
	root.add_child(light)
	_label(root, "ESTACIÓN DE SERVICIO", _at(canopy, Vector3(0, 5.0, 4.57)), 72, Color(1, 1, 1), 110.0)
	# Minimercado.
	var shop := _at(lot, Vector3(0, 0, -depth + 5.0))
	b.solid(Vector3(12.0, 3.6, 8.0), _at(shop, Vector3(0, 1.8, 0)), _tex("stucco", Color(0.95, 0.95, 0.93), 2.0))
	b.box(Vector3(9.0, 2.3, 0.06), _at(shop, Vector3(-1.0, 1.4, 4.03)), Mats.color(Color(1, 0.97, 0.88), 0.4, 1.4), MeshBatch.GLOW)
	b.box(Vector3(12.1, 0.7, 0.14), _at(shop, Vector3(0, 3.3, 4.08)), red)
	_label(root, "MINIMERCADO 24 HS", _at(shop, Vector3(0, 3.3, 4.17)), 56, Color(1, 1, 1), 80.0)
	# Cartel de precios en un poste alto.
	var sign := _at(lot, Vector3(w * 0.5 - 1.5, 0, -1.0))
	b.solid(Vector3(0.3, 6.0, 0.3), _at(sign, Vector3(0, 3.0, 0)), white)
	b.box(Vector3(2.4, 2.6, 0.3), _at(sign, Vector3(0, 6.8, 0)), red)
	_label(root, "SÚPER   $2,10\nREGULAR $1,95\nDIÉSEL  $1,80", _at(sign, Vector3(0, 6.8, 0.17)), 40, Color(1, 0.95, 0.7), 90.0)

# ---------------------------------------------------------------- plaza y afueras

static func _plaza(b: MeshBatch, root: Node3D, r: RandomNumberGenerator, rect: Rect2) -> void:
	var c := rect.get_center()
	var stone := _tex("stone", Color(0.85, 0.82, 0.78), 1.2)
	# Senderos: alrededor, en cruz y en diagonal.
	_flat(b, rect.position.x, rect.end.x, rect.position.y, rect.position.y + 2.5, 0.032, 0.03, stone)
	_flat(b, rect.position.x, rect.end.x, rect.end.y - 2.5, rect.end.y, 0.032, 0.03, stone)
	_flat(b, rect.position.x, rect.position.x + 2.5, rect.position.y, rect.end.y, 0.032, 0.03, stone)
	_flat(b, rect.end.x - 2.5, rect.end.x, rect.position.y, rect.end.y, 0.032, 0.03, stone)
	_flat(b, c.x - 1.6, c.x + 1.6, rect.position.y, rect.end.y, 0.033, 0.03, stone)
	_flat(b, rect.position.x, rect.end.x, c.y - 1.6, c.y + 1.6, 0.033, 0.03, stone)
	for s in [-1.0, 1.0]:
		var ang := atan2(rect.size.y, rect.size.x * s)
		var len := rect.size.length()
		b.box(Vector3(len, 0.03, 2.2), Transform3D(Basis(Vector3.UP, -ang), Vector3(c.x, 0.018, c.y)), stone)
	# Fuente en el medio con un obelisco.
	var marble := _tex("marble", Color(0.95, 0.95, 0.93), 1.5, 0.4)
	b.solid(Vector3(10.0, 0.6, 10.0), _p(c.x, c.y, 0.3), marble)
	b.box(Vector3(9.0, 0.06, 9.0), _p(c.x, c.y, 0.58), Mats.color(Color(0.2, 0.35, 0.45), 0.05, 0.3, 0.3))
	b.solid(Vector3(1.6, 1.2, 1.6), _p(c.x, c.y, 1.2), marble)
	b.add("pyramid", Transform3D(Basis(Vector3.UP, PI * 0.25).scaled(Vector3(1.4, 9.0, 1.4)), Vector3(c.x, 6.3, c.y)), marble)
	b.plane(16.0, 16.0, _p(c.x, c.y, 0.65), _pool_mat(Color(0.7, 0.85, 1.0, 0.3)))
	var spot := OmniLight3D.new()
	spot.light_color = Color(0.85, 0.9, 1.0)
	spot.light_energy = 1.4
	spot.omni_range = 12.0
	spot.distance_fade_enabled = true
	spot.distance_fade_begin = 50.0
	spot.distance_fade_length = 15.0
	spot.position = Vector3(c.x, 2.0, c.y + 6.0)
	root.add_child(spot)
	_label(root, "PLAZA DEL BARRIO", Transform3D(Basis(Vector3.UP, PI), Vector3(c.x, 1.25, c.y - 0.82)), 40, Color(0.2, 0.2, 0.2, 1), 40.0)
	# Glorieta, juegos, bancos y árboles.
	var gz := Vector3(c.x - rect.size.x * 0.27, 0, c.y - rect.size.y * 0.22)
	var wood := _tex("wood", Color(0.9, 0.85, 0.8), 1.0)
	b.cylinder(4.0, 0.5, _p(gz.x, gz.z, 0.25), marble, 8)
	for i in 8:
		var a := i * TAU / 8.0
		b.solid(Vector3(0.18, 3.0, 0.18), _p(gz.x + cos(a) * 3.6, gz.z + sin(a) * 3.6, 2.0), _tex("paint", Color(0.95, 0.95, 0.93), 1.0))
	b.add("cone8", Transform3D(Basis.from_scale(Vector3(9.0, 1.8, 9.0)), Vector3(gz.x, 4.4, gz.z)), _tex("shingles", Color(0.35, 0.45, 0.4), 1.0))
	var play := Vector3(c.x + rect.size.x * 0.27, 0, c.y + rect.size.y * 0.22)
	b.box(Vector3(7.0, 0.04, 6.0), _p(play.x, play.z, 0.03), _tex("concrete", Color(0.8, 0.6, 0.45), 1.0))
	var metal := _tex("metal", Color(0.85, 0.3, 0.2), 1.0, 0.5)
	for sx in [-1.8, 1.8]:
		b.solid(Vector3(0.12, 2.4, 0.12), _p(play.x + sx, play.z - 1.5, 1.2), metal)
	b.box(Vector3(3.8, 0.12, 0.12), _p(play.x, play.z - 1.5, 2.4), metal)
	for sx in [-0.8, 0.8]:
		b.box(Vector3(0.5, 0.06, 0.25), _p(play.x + sx, play.z - 1.5, 0.55), wood, MeshBatch.DETAIL)
	b.solid(Vector3(0.9, 1.8, 0.9), _p(play.x - 1.5, play.z + 1.5, 0.9), _tex("metal", Color(0.2, 0.45, 0.8), 1.0, 0.5))
	b.box(Vector3(0.8, 0.08, 3.2), Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-32)), Vector3(play.x - 1.5, 0.95, play.z + 2.9)), _tex("metal", Color(0.9, 0.75, 0.2), 1.0, 0.4))
	for i in 10:
		var bx := rect.position.x + 6.0 + (i % 5) * (rect.size.x - 12.0) / 4.0
		var bz := c.y + (2.6 if i < 5 else -2.6)
		_bench(b, Transform3D(Basis(Vector3.UP, 0.0 if i < 5 else PI), Vector3(bx, 0, bz)))
	var x := rect.position.x + 5.0
	while x < rect.end.x - 4.0:
		var z := rect.position.y + 5.0
		while z < rect.end.y - 4.0:
			var near_path := absf(x - c.x) < 4.0 or absf(z - c.y) < 4.0
			var near_stuff := Vector2(x, z).distance_to(Vector2(gz.x, gz.z)) < 7.0 or Vector2(x, z).distance_to(Vector2(play.x, play.z)) < 7.0
			if not near_path and not near_stuff and r.randf() < 0.55:
				_tree(b, Vector3(x + r.randf_range(-1.5, 1.5), 0, z + r.randf_range(-1.5, 1.5)), r.randf_range(1.0, 1.4))
			z += 8.0
		x += 8.0
	for p in [Vector2(rect.position.x + 3.0, rect.position.y + 3.0), Vector2(rect.end.x - 3.0, rect.position.y + 3.0),
			Vector2(rect.position.x + 3.0, rect.end.y - 3.0), Vector2(rect.end.x - 3.0, rect.end.y - 3.0),
			Vector2(c.x - 3.0, c.y - 8.0), Vector2(c.x + 3.0, c.y + 8.0)]:
		_street_lamp(b, root, Vector3(p.x, 0, p.y), Vector3(0, 0, 1), LAMP_COLOR, p.distance_to(c) < 12.0)

static func _bench(b: MeshBatch, t: Transform3D) -> void:
	var wood := _tex("wood", Color(0.75, 0.55, 0.4), 1.0)
	var iron := _tex("metal", Color(0.15, 0.15, 0.16), 1.0, 0.5)
	b.solid(Vector3(1.8, 0.08, 0.45), _at(t, Vector3(0, 0.45, 0)), wood)
	b.box(Vector3(1.8, 0.4, 0.06), _at(t, Vector3(0, 0.75, -0.22), Vector3(-10, 0, 0)), wood, MeshBatch.DETAIL)
	for sx in [-0.8, 0.8]:
		b.box(Vector3(0.06, 0.45, 0.45), _at(t, Vector3(sx, 0.22, 0)), iron, MeshBatch.DETAIL)

## Lo de afuera de la cuadrícula: casas al sur, la cancha al norte, el parque al este y la
## vereda del oeste (junto a las vías).
static func _outskirts(b: MeshBatch, root: Node3D, r: RandomNumberGenerator) -> void:
	var x_lo: float = STREETS_X[0]
	var x_hi: float = STREETS_X[-1]
	var z_lo: float = STREETS_Z[0]
	var z_hi: float = STREETS_Z[-1]
	# Al sur de la calle Los Pinos: una fila de casas mirando a la calle.
	_sidewalk(b, x_lo - HALF, x_hi + HALF, z_lo - HALF - WALK, z_lo - HALF)
	_curb_x(b, x_lo - HALF, x_hi + HALF, z_lo - HALF)
	for i in STREETS_X.size() - 1:
		var xa: float = STREETS_X[i] + HALF + WALK
		var xb: float = STREETS_X[i + 1] - HALF - WALK
		_row(b, root, r, i, "houses", xa, xb, z_lo - HALF - WALK, 24.0, Vector3(0, 0, 1))
		_street_trees(b, r, xa, xb, z_lo - HALF - 0.6, true)
	# Al norte: vereda, una cancha de fútbol con luces y árboles.
	_sidewalk(b, x_lo - HALF, x_hi + HALF, z_hi + HALF, z_hi + HALF + WALK)
	_curb_x(b, x_lo - HALF, x_hi + HALF, z_hi + HALF)
	_soccer_field(b, root, Vector3(-5.0, 0, z_hi + HALF + WALK + 20.0))
	for i in STREETS_X.size() - 1:
		_street_trees(b, r, float(STREETS_X[i]) + HALF, float(STREETS_X[i + 1]) - HALF, z_hi + HALF + 0.6, true)
	# Al este: un parque lineal con árboles.
	_sidewalk(b, x_hi + HALF, x_hi + HALF + WALK, z_lo - HALF, z_hi + HALF)
	_curb_z(b, x_hi + HALF, z_lo - HALF, z_hi + HALF)
	var z := z_lo
	while z < z_hi:
		_tree(b, Vector3(x_hi + HALF + 5.0 + r.randf_range(0, 6), 0, z + r.randf_range(-2, 2)), r.randf_range(1.0, 1.4))
		_tree(b, Vector3(x_hi + HALF + 15.0 + r.randf_range(0, 8), 0, z + 6.0 + r.randf_range(-2, 2)), r.randf_range(1.0, 1.5))
		z += 11.0
	# Al oeste: vereda y el alambrado de las vías.
	_sidewalk(b, x_lo - HALF - WALK, x_lo - HALF, z_lo - HALF, z_hi + HALF)
	_curb_z(b, x_lo - HALF, z_lo - HALF, z_hi + HALF)

static func _soccer_field(b: MeshBatch, root: Node3D, c: Vector3) -> void:
	b.box(Vector3(60.0, 0.03, 34.0), _p(c.x, c.z, 0.02), _tex("grass", Color(0.75, 0.95, 0.7), 2.0, 1.0))
	var white := Mats.color(Color(0.95, 0.95, 0.93), 0.7)
	for s in [-1.0, 1.0]:
		b.box(Vector3(56.0, 0.01, 0.12), _p(c.x, c.z + s * 15.0, 0.04), white, MeshBatch.DETAIL)
		b.box(Vector3(0.12, 0.01, 30.0), _p(c.x + s * 28.0, c.z, 0.04), white, MeshBatch.DETAIL)
		# Arcos.
		for gz in [-3.6, 3.6]:
			b.solid(Vector3(0.12, 2.4, 0.12), _p(c.x + s * 28.0, c.z + gz, 1.2), white)
		b.box(Vector3(0.12, 0.12, 7.3), _p(c.x + s * 28.0, c.z, 2.4), white)
	b.box(Vector3(0.12, 0.01, 30.0), _p(c.x, c.z, 0.04), white, MeshBatch.DETAIL)
	b.cylinder(4.5, 0.01, _p(c.x, c.z, 0.038), white, 20, MeshBatch.DETAIL)
	b.cylinder(4.38, 0.012, _p(c.x, c.z, 0.04), _tex("grass", Color(0.75, 0.95, 0.7), 2.0, 1.0), 20, MeshBatch.DETAIL)
	# Torres de luz (apagadas a esta hora, salvo una).
	var post := _tex("metal", Color(0.5, 0.5, 0.52), 1.0, 0.5)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			b.solid(Vector3(0.4, 12.0, 0.4), _p(c.x + sx * 31.0, c.z + sz * 18.0, 6.0), post)
			b.box(Vector3(2.0, 1.0, 0.3), _p(c.x + sx * 31.0, c.z + sz * 18.0, 12.2), Mats.color(Color(0.9, 0.95, 1.0), 0.5, 1.5 if sx < 0 and sz < 0 else 0.0), MeshBatch.GLOW)

# ---------------------------------------------------------------- zona industrial

const COMPANIES := ["Transportes Rivas", "Maderas del Sur", "Frigorífico Norte", "Reciclados Lara", "Metalúrgica Andina",
		"Logística Delta", "Cartonera El Sol", "Plásticos Unión", "Textil San Blas", "Acopio Central"]

static func _industrial(b: MeshBatch, root: Node3D, r: RandomNumberGenerator) -> void:
	var gravel := _tex("concrete", Color(0.5, 0.5, 0.5), 3.0, 0.95)
	_flat(b, MAP.position.x - 30.0, RAIL_X - 3.0, MAP.position.y - 30.0, MAP.end.y + 30.0, 0.008, 0.008, gravel)
	# Las vías: balasto, durmientes y rieles (sin colisión: en el paso a nivel el camión salta igual).
	var ballast := _tex("stone", Color(0.45, 0.43, 0.4), 0.8)
	_flat(b, RAIL_X - 1.8, RAIL_X + 1.8, MAP.position.y - 30.0, MAP.end.y + 30.0, 0.06, 0.06, ballast)
	var sleeper := _tex("wood", Color(0.4, 0.32, 0.25), 1.0)
	var steel := _tex("metal", Color(0.55, 0.5, 0.45), 1.0, 0.4)
	var z := MAP.position.y - 25.0
	while z < MAP.end.y + 25.0:
		if absf(z - AVENUE_Z) > AV_HALF + 0.5:
			b.box(Vector3(2.6, 0.12, 0.25), _p(RAIL_X, z, 0.1), sleeper, MeshBatch.DETAIL)
		z += 1.2
	for s in [-0.72, 0.72]:
		_flat(b, RAIL_X + s - 0.04, RAIL_X + s + 0.04, MAP.position.y - 25.0, MAP.end.y + 25.0, 0.2, 0.12, steel)
	# Paso a nivel: tablones, cruces de San Andrés y luces rojas.
	_flat(b, RAIL_X - 1.9, RAIL_X + 1.9, AVENUE_Z - AV_HALF, AVENUE_Z + AV_HALF, 0.07, 0.05, _tex("wood", Color(0.5, 0.42, 0.35), 1.0))
	for s in [-1.0, 1.0]:
		var p := Vector3(RAIL_X + s * 4.0, 0, AVENUE_Z + s * (AV_HALF + 1.2))
		var face := Basis(Vector3.UP, PI * 0.5 if s > 0.0 else -PI * 0.5)
		b.solid(Vector3(0.15, 3.6, 0.15), _p(p.x, p.z, 1.8), _tex("metal", Color(0.9, 0.9, 0.9), 1.0, 0.5))
		for a in [35.0, -35.0]:
			b.box(Vector3(1.6, 0.25, 0.05), Transform3D(face * Basis(Vector3.BACK, deg_to_rad(a)), p + face * Vector3(0, 3.1, 0.1)), Mats.color(Color(0.95, 0.95, 0.95), 0.6), MeshBatch.DETAIL)
		for lz in [-0.25, 0.25]:
			b.box(Vector3(0.22, 0.22, 0.22), Transform3D(face, p + face * Vector3(lz, 2.4, 0.1)), Mats.color(Color(1, 0.1, 0.05), 0.5, 2.0), MeshBatch.GLOW)
		_label(root, "PASO A NIVEL", Transform3D(face, p + face * Vector3(0, 2.0, 0.12)), 36, Color(1, 1, 1), 45.0)
	# Alambrado a los dos lados de las vías (con el paso de la avenida).
	var wire := _tex("metal", Color(0.45, 0.45, 0.45), 1.0, 0.5)
	for s in [-3.6, 3.6]:
		for seg in [[MAP.position.y, AVENUE_Z - AV_HALF - 2.0], [AVENUE_Z + AV_HALF + 2.0, MAP.end.y]]:
			var z0: float = seg[0]
			var z1: float = seg[1]
			b.collider(Vector3(0.1, 2.0, z1 - z0), _p(RAIL_X + s, (z0 + z1) * 0.5, 1.0))
			var zz := z0
			while zz < z1:
				b.box(Vector3(0.08, 1.8, 0.08), _p(RAIL_X + s, zz, 0.9), wire, MeshBatch.DETAIL)
				zz += 3.0
			for wy in [0.6, 1.2, 1.75]:
				_flat(b, RAIL_X + s - 0.015, RAIL_X + s + 0.015, z0, z1, wy + 0.015, 0.03, wire, MeshBatch.DETAIL)
	# Galpones a lo largo de la avenida y de la calle industrial: [frente, hacia dónde mira, ancho, fondo].
	var sheds := [
		[Vector3(-212.0, 0, AVENUE_Z + AV_HALF + 4.0), Vector3(0, 0, -1), 30.0, 32.0],
		[Vector3(-250.0, 0, AVENUE_Z + AV_HALF + 4.0), Vector3(0, 0, -1), 30.0, 28.0],
		[Vector3(-288.0, 0, AVENUE_Z + AV_HALF + 4.0), Vector3(0, 0, -1), 32.0, 30.0],
		[Vector3(-212.0, 0, AVENUE_Z - AV_HALF - 4.0), Vector3(0, 0, 1), 28.0, 28.0],
		[Vector3(-296.0, 0, AVENUE_Z - AV_HALF - 4.0), Vector3(0, 0, 1), 26.0, 28.0],
		[Vector3(IND_X + HALF + 4.0, 0, 10.0), Vector3(-1, 0, 0), 30.0, 28.0],
		[Vector3(IND_X + HALF + 4.0, 0, -30.0), Vector3(-1, 0, 0), 24.0, 26.0],
		[Vector3(IND_X - HALF - 4.0, 0, -35.0), Vector3(1, 0, 0), 22.0, 24.0],
		[Vector3(IND_X - HALF - 4.0, 0, 30.0), Vector3(1, 0, 0), 16.0, 20.0],
	]
	for i in sheds.size():
		var sh: Array = sheds[i]
		_shed(b, root, _lot(sh[0], sh[1]), sh[2], sh[3], r.randi(), COMPANIES[i % COMPANIES.size()])
	# Contenedores apilados entre los galpones y las vías.
	var colors := [Color(0.7, 0.2, 0.15), Color(0.15, 0.35, 0.6), Color(0.2, 0.5, 0.3), Color(0.8, 0.6, 0.15), Color(0.5, 0.5, 0.52)]
	for i in 14:
		var cz := -18.0 + (i % 7) * 3.0
		var cx := -208.0 + (i / 7) * 7.0
		var levels := 1 + (i * 7 % 3)
		for lv in levels:
			b.solid(Vector3(6.0, 2.5, 2.4), _p(cx, cz, 1.25 + lv * 2.55), _tex("metal", colors[(i + lv) % colors.size()], 0.6, 0.6))
	# Faroles anaranjados en la calle industrial.
	var lz := IND_Z0 + 8.0
	var side := 1.0
	while lz < AVENUE_Z - 12.0:
		_street_lamp(b, root, Vector3(IND_X + side * (HALF + 0.8), 0, lz), Vector3(-side, 0, 0), SODIUM, true)
		lz += 24.0
		side = -side
	# Fin de la avenida y de la calle industrial: barreras.
	_barrier(b, Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(AVENUE_WEST + 1.0, 0, AVENUE_Z)), AV_HALF * 2.0 + 2.0)
	_barrier(b, Transform3D(Basis(), Vector3(IND_X, 0, IND_Z0 - 1.0)), HALF * 2.0 + 2.0)

## Barrera rayada (fin de la calle), sólida.
static func _barrier(b: MeshBatch, t: Transform3D, w: float) -> void:
	b.solid(Vector3(w, 0.4, 0.15), _at(t, Vector3(0, 1.0, 0)), _tex("paint", Color(0.95, 0.85, 0.2), 1.0, 0.6))
	for sx in [-w * 0.45, 0.0, w * 0.45]:
		b.solid(Vector3(0.15, 1.2, 0.15), _at(t, Vector3(sx, 0.6, 0)), _tex("metal", Color(0.3, 0.3, 0.3), 1.0))
	var x := -w * 0.5 + 0.4
	while x < w * 0.5:
		b.box(Vector3(0.35, 0.41, 0.16), _at(t, Vector3(x, 1.0, 0)), Mats.color(Color(0.1, 0.1, 0.1), 0.7), MeshBatch.DETAIL)
		x += 0.8

## Galpón industrial con portón, cartel, luz anaranjada y cerco.
static func _shed(b: MeshBatch, root: Node3D, lot: Transform3D, w: float, d: float, seed: int, company: String) -> void:
	var r := RandomNumberGenerator.new()
	r.seed = seed
	var h := r.randf_range(6.5, 9.0)
	var c: Color = [Color(0.62, 0.64, 0.66), Color(0.55, 0.6, 0.55), Color(0.7, 0.66, 0.58), Color(0.5, 0.55, 0.62)][r.randi() % 4]
	var t := _at(lot, Vector3(0, 0, -6.0 - d * 0.5))
	var metal := _tex("metal", c, 0.8, 0.6)
	b.solid(Vector3(w, h, d), _at(t, Vector3(0, h * 0.5, 0)), metal)
	b.roof(Vector3(w + 0.4, 1.6, d + 0.6), _at(t, Vector3(0, h, 0)), _tex("metal", c.darkened(0.25), 0.8, 0.5))
	b.box(Vector3(w + 0.06, 1.0, d + 0.06), _at(t, Vector3(0, 0.5, 0)), _tex("concrete", Color(0.65, 0.65, 0.65), 2.0))
	var front := d * 0.5
	b.box(Vector3(6.0, 5.0, 0.08), _at(t, Vector3(-w * 0.2, 2.5, front + 0.04)), _tex("metal", c.darkened(0.4), 0.4, 0.5))
	b.box(Vector3(1.0, 2.1, 0.08), _at(t, Vector3(w * 0.25, 1.05, front + 0.04)), _tex("metal", Color(0.3, 0.3, 0.3), 1.0, 0.5))
	for i in 5:
		b.box(Vector3(2.0, 0.8, 0.06), _at(t, Vector3(-w * 0.4 + i * w * 0.2, h - 1.2, front + 0.03)), Mats.color(Color(0.15, 0.18, 0.22), 0.1, 0.2))
	b.box(Vector3(minf(w - 4.0, 12.0), 1.1, 0.1), _at(t, Vector3(0, h - 2.6, front + 0.06)), Mats.color(Color(0.92, 0.92, 0.9), 0.6))
	var sign := _label(root, company.to_upper(), _at(t, Vector3(0, h - 2.6, front + 0.12)), 80, Color(0.12, 0.15, 0.25), 120.0)
	sign.outline_size = 0
	b.box(Vector3(0.4, 0.2, 0.3), _at(t, Vector3(-w * 0.2, 5.4, front + 0.2)), Mats.color(SODIUM, 0.5, 2.5), MeshBatch.GLOW)
	b.plane(10.0, 9.0, _at(t, Vector3(-w * 0.2, 0.05, front + 4.0)), _pool_mat(Color(SODIUM, 0.4)))
	b.box(Vector3(w, 0.03, 6.0), _at(lot, Vector3(0, 0.02, -3.0)), _tex("concrete", Color(0.6, 0.6, 0.6), 2.0))
	if r.randf() < 0.6:
		# Un camión viejo estacionado.
		var vt := _at(t, Vector3(w * 0.3, 0, front + 3.5), Vector3(0, 90, 0))
		var paint := _tex("metal", _car_color(r), 1.0, 0.5)
		b.solid(Vector3(2.3, 2.6, 5.5), _at(vt, Vector3(0, 1.8, -0.8)), _tex("metal", Color(0.85, 0.85, 0.82), 0.8, 0.5))
		b.solid(Vector3(2.3, 1.9, 1.8), _at(vt, Vector3(0, 1.45, 2.8)), paint)
		for sz in [-2.5, 0.0, 2.8]:
			for sx in [-1.05, 1.05]:
				b.cylinder(0.45, 0.3, _at(vt, Vector3(sx, 0.45, sz), Vector3(0, 0, 90)), Mats.color(Color(0.06, 0.06, 0.06), 0.9), 10, MeshBatch.DETAIL)
	# Pallets.
	for i in r.randi_range(1, 4):
		b.solid(Vector3(1.2, 0.15 * (1 + i % 3), 1.0), _at(t, Vector3(w * 0.5 - 1.5, 0.075 * (1 + i % 3), front + 1.0 + i * 1.3)), _tex("wood", Color(0.8, 0.7, 0.55), 1.0))

# ---------------------------------------------------------------- el Galpón 7

## El depósito del reducidor: se entra por un portón abierto y adentro hay que dejar el camión
## parado en el rectángulo amarillo.
static func _warehouse(b: MeshBatch, root: Node3D) -> void:
	var c := WAREHOUSE
	var sx := WAREHOUSE_SIZE.x * 0.5
	var sz := WAREHOUSE_SIZE.y * 0.5
	var h := 7.0
	var brick := _tex("brick", Color(0.8, 0.72, 0.68), 1.0)
	var metal := _tex("metal", Color(0.5, 0.52, 0.5), 0.8, 0.6)
	# Piso, paredes (la de adelante con el portón) y techo.
	_flat(b, c.x - sx, c.x + sx, c.z - sz, c.z + sz, 0.03, 0.03, _tex("concrete", Color(0.62, 0.62, 0.6), 2.5, 0.9))
	b.solid(Vector3(0.3, h, WAREHOUSE_SIZE.y), _p(c.x - sx, c.z, h * 0.5), brick)
	for s in [-1.0, 1.0]:
		b.solid(Vector3(WAREHOUSE_SIZE.x, h, 0.3), _p(c.x, c.z + s * sz, h * 0.5), brick)
	var door := WAREHOUSE_DOOR
	var side_w := (WAREHOUSE_SIZE.y - door.x) * 0.5
	for s in [-1.0, 1.0]:
		b.solid(Vector3(0.3, h, side_w), _p(c.x + sx, c.z + s * (door.x * 0.5 + side_w * 0.5), h * 0.5), brick)
	b.solid(Vector3(0.3, h - door.y, door.x), _p(c.x + sx, c.z, door.y + (h - door.y) * 0.5), brick)
	# Por dentro, las paredes pintadas en dos colores (abajo verde de taller, arriba crema).
	var low := _tex("paint", Color(0.42, 0.55, 0.48), 2.0, 0.8)
	var high := _tex("paint", Color(0.93, 0.89, 0.8), 2.0, 0.9)
	b.box(Vector3(0.02, 1.3, WAREHOUSE_SIZE.y - 0.4), _p(c.x - sx + 0.16, c.z, 0.65), low)
	b.box(Vector3(0.02, h - 1.5, WAREHOUSE_SIZE.y - 0.4), _p(c.x - sx + 0.16, c.z, 1.3 + (h - 1.5) * 0.5), high)
	for s in [-1.0, 1.0]:
		b.box(Vector3(WAREHOUSE_SIZE.x - 0.4, 1.3, 0.02), _p(c.x, c.z + s * (sz - 0.16), 0.65), low)
		b.box(Vector3(WAREHOUSE_SIZE.x - 0.4, h - 1.5, 0.02), _p(c.x, c.z + s * (sz - 0.16), 1.3 + (h - 1.5) * 0.5), high)
	for s in [-1.0, 1.0]:
		var zc: float = c.z + s * (WAREHOUSE_DOOR.x * 0.5 + side_w * 0.5)
		b.box(Vector3(0.02, 1.3, side_w - 0.3), _p(c.x + sx - 0.16, zc, 0.65), low)
		b.box(Vector3(0.02, h - 1.5, side_w - 0.3), _p(c.x + sx - 0.16, zc, 1.3 + (h - 1.5) * 0.5), high)
	b.box(Vector3(WAREHOUSE_SIZE.x + 0.6, 0.25, WAREHOUSE_SIZE.y + 0.6), _p(c.x, c.z, h + 0.12), metal)
	b.roof(Vector3(WAREHOUSE_SIZE.x + 0.8, 2.0, WAREHOUSE_SIZE.y + 0.8), _p(c.x, c.z, h + 0.25), _tex("metal", Color(0.4, 0.42, 0.4), 0.8, 0.5))
	b.collider(Vector3(WAREHOUSE_SIZE.x, 0.3, WAREHOUSE_SIZE.y), _p(c.x, c.z, h + 0.1))
	# El portón enrollado arriba y la cortina de chapa.
	b.cylinder(0.45, door.x + 0.4, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(c.x + sx - 0.6, door.y + 0.45, c.z)), _tex("metal", Color(0.6, 0.6, 0.6), 0.5, 0.4), 12)
	# Cartel.
	b.box(Vector3(0.12, 1.4, 7.0), _p(c.x + sx + 0.2, c.z, h - 0.9), Mats.color(Color(0.1, 0.1, 0.12), 0.6))
	_label(root, "GALPÓN 7", Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(c.x + sx + 0.28, h - 0.9, c.z)), 150, Color(1.0, 0.75, 0.2), 160.0)
	# Adentro: luces, el rectángulo donde se deja el camión, estanterías, una mesa con plata.
	# Tubos de luz colgados (dos filas) y tres luces de verdad.
	for lx in [-8.0, -2.5, 3.0, 8.5]:
		for lz in [-4.0, 4.0]:
			b.box(Vector3(1.6, 0.08, 0.22), _p(c.x + lx, c.z + lz, h - 1.2), Mats.color(Color(0.95, 0.97, 1.0), 0.5, 3.0), MeshBatch.GLOW)
			for e in [-0.7, 0.7]:
				b.box(Vector3(0.02, 1.0, 0.02), _p(c.x + lx + e, c.z + lz, h - 0.7), Mats.color(Color(0.2, 0.2, 0.2), 0.6), MeshBatch.DETAIL)
	for lx in [-7.0, 0.0, 7.0]:
		var light := OmniLight3D.new()
		light.light_color = Color(0.98, 0.94, 0.85)
		light.light_energy = 2.0
		light.omni_range = 11.0
		light.position = Vector3(c.x + lx, h - 1.6, c.z)
		root.add_child(light)
	var yellow := Mats.color(Color(0.95, 0.78, 0.15), 0.7, 0.4)
	var zr := WAREHOUSE_ZONE
	b.box(Vector3(zr.size.x, 0.01, 0.2), _p(zr.get_center().x, zr.position.y, 0.04), yellow)
	b.box(Vector3(zr.size.x, 0.01, 0.2), _p(zr.get_center().x, zr.end.y, 0.04), yellow)
	b.box(Vector3(0.2, 0.01, zr.size.y), _p(zr.position.x, zr.get_center().y, 0.04), yellow)
	b.box(Vector3(0.2, 0.01, zr.size.y), _p(zr.end.x, zr.get_center().y, 0.04), yellow)
	_warehouse_interior(b, root)
	# Cartel de la empresa en la fachada (de día es un negocio de verdad).
	b.box(Vector3(0.1, 1.5, 4.4), _p(c.x + sx + 0.2, c.z + door.x * 0.5 + 2.6, 3.1), Mats.color(Color(0.95, 0.5, 0.15), 0.7, 0.2))
	var biz := _label(root, "MUDANCEROS TRUCHOS\nMudanzas y reparaciones del hogar\nTel. 555-0107", Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(c.x + sx + 0.27, 3.1, c.z + door.x * 0.5 + 2.6)), 44, Color(0.1, 0.08, 0.06), 70.0)
	biz.outline_size = 0
	# Patio de entrada, cerco con el portón abierto y cartel en la calle.
	_flat(b, c.x + sx, IND_X - HALF, c.z - door.x * 0.5 - 4.0, c.z + door.x * 0.5 + 4.0, 0.03, 0.03, _tex("concrete", Color(0.6, 0.6, 0.6), 2.5))
	var fence_x := IND_X - HALF - 1.0
	var wire := _tex("metal", Color(0.45, 0.45, 0.45), 1.0, 0.5)
	var gap := door.x * 0.5 + 3.5   # el portón del cerco es más ancho que el del galpón (para doblar)
	for seg in [[c.z - sz - 6.0, c.z - gap], [c.z + gap, c.z + sz + 6.0]]:
		var z0: float = seg[0]
		var z1: float = seg[1]
		b.collider(Vector3(0.1, 2.2, z1 - z0), _p(fence_x, (z0 + z1) * 0.5, 1.1))
		var zz := z0
		while zz <= z1:
			b.box(Vector3(0.08, 2.2, 0.08), _p(fence_x, zz, 1.1), wire, MeshBatch.DETAIL)
			zz += 2.5
		for wy in [0.4, 1.2, 2.1]:
			_flat(b, fence_x - 0.015, fence_x + 0.015, z0, z1, wy + 0.015, 0.03, wire, MeshBatch.DETAIL)
	var gate := _tex("metal", Color(0.4, 0.4, 0.4), 1.0, 0.5)
	for s in [-1.0, 1.0]:
		b.box(Vector3(3.6, 2.0, 0.06), Transform3D(Basis(Vector3.UP, s * 1.2), Vector3(fence_x - 1.6, 1.1, c.z + s * gap - s * 0.4)), gate, MeshBatch.DETAIL)
	b.box(Vector3(0.4, 0.2, 0.3), _p(c.x + sx + 0.3, c.z, door.y + 1.1), Mats.color(SODIUM, 0.5, 2.5), MeshBatch.GLOW)
	b.plane(14.0, 12.0, _p(c.x + sx + 6.0, c.z, 0.05), _pool_mat(Color(SODIUM, 0.45)))
	# Carteles: en la esquina de la avenida y antes de llegar.
	_sign(b, root, Vector3(IND_X - HALF - 2.0, 0, AVENUE_Z - AV_HALF - 2.0), Vector3(1, 0, 0), "GALPÓN 7 →")
	_sign(b, root, Vector3(IND_X + HALF + 1.2, 0, c.z + 14.0), Vector3(0, 0, 1), "← GALPÓN 7")
	_sign(b, root, Vector3(IND_X + HALF + 1.2, 0, c.z - 14.0), Vector3(0, 0, -1), "GALPÓN 7 →")

## Cartel en un poste, mirando hacia `facing`.
static func _sign(b: MeshBatch, root: Node3D, p: Vector3, facing: Vector3, text: String) -> void:
	var t := _lot(p, facing)
	b.solid(Vector3(0.15, 3.2, 0.15), _at(t, Vector3(0, 1.6, 0)), _tex("metal", Color(0.3, 0.3, 0.3), 1.0))
	b.box(Vector3(2.6, 0.8, 0.1), _at(t, Vector3(0, 3.0, 0)), Mats.color(Color(0.1, 0.1, 0.12), 0.6))
	_label(root, text, _at(t, Vector3(0, 3.0, 0.07)), 44, Color(1.0, 0.75, 0.2), 70.0)

## Por dentro, el galpón aparenta ser el taller de una empresa de mudanzas y reparaciones: banco
## de trabajo con herramientas colgadas, estanterías con pintura y materiales, escaleras, cajas de
## mudanza y, en un rincón, la oficinita con la computadora donde se le vende al Flaco.
static func _warehouse_interior(b: MeshBatch, root: Node3D) -> void:
	var c := WAREHOUSE
	var sx := WAREHOUSE_SIZE.x * 0.5
	var sz := WAREHOUSE_SIZE.y * 0.5
	var wood := _tex("wood", Color(0.85, 0.72, 0.55), 1.0)
	var dark_wood := _tex("wood", Color(0.5, 0.38, 0.28), 1.0)
	var steel := _tex("metal", Color(0.55, 0.57, 0.6), 0.8, 0.5)
	var blue_steel := _tex("metal", Color(0.3, 0.45, 0.65), 0.8, 0.5)
	var black := Mats.color(Color(0.08, 0.08, 0.09), 0.6)
	var cardboard := _tex("paint", Color(0.72, 0.55, 0.36), 1.0, 0.95)
	var tape := Mats.color(Color(0.55, 0.4, 0.22), 0.5)
	var west := c.x - sx + 0.17
	var wz := c.z + sz - 0.16
	var sw := c.z - sz + 0.16
	# --- Taller, contra la pared del fondo (+z): tablero con herramientas y banco de trabajo.
	var bx := c.x - sx + 5.5
	b.box(Vector3(6.0, 2.0, 0.05), _p(bx, wz - 0.03, 2.1), _tex("wood", Color(0.95, 0.85, 0.65), 0.6))
	var tool_colors := [Color(0.8, 0.15, 0.1), Color(0.95, 0.7, 0.1), Color(0.15, 0.3, 0.6), Color(0.2, 0.2, 0.22)]
	for i in 10:
		var tx := bx - 2.6 + i * 0.58
		var ty := 1.75 + (i % 2) * 0.75
		var col := Mats.color(tool_colors[i % tool_colors.size()], 0.6)
		match i % 4:
			0:   # martillo
				b.box(Vector3(0.04, 0.38, 0.04), _p(tx, wz - 0.08, ty), dark_wood, MeshBatch.DETAIL)
				b.box(Vector3(0.18, 0.07, 0.06), _p(tx, wz - 0.08, ty + 0.2), black, MeshBatch.DETAIL)
			1:   # llave
				b.box(Vector3(0.05, 0.36, 0.02), _p(tx, wz - 0.07, ty), steel, MeshBatch.DETAIL)
				b.box(Vector3(0.11, 0.06, 0.02), _p(tx, wz - 0.07, ty + 0.19), steel, MeshBatch.DETAIL)
			2:   # serrucho
				b.box(Vector3(0.46, 0.14, 0.01), _p(tx, wz - 0.07, ty), steel, MeshBatch.DETAIL)
				b.box(Vector3(0.12, 0.12, 0.04), _p(tx + 0.27, wz - 0.07, ty + 0.02), col, MeshBatch.DETAIL)
			_:   # destornillador
				b.box(Vector3(0.03, 0.2, 0.03), _p(tx, wz - 0.07, ty - 0.08), steel, MeshBatch.DETAIL)
				b.box(Vector3(0.05, 0.13, 0.05), _p(tx, wz - 0.07, ty + 0.08), col, MeshBatch.DETAIL)
	b.solid(Vector3(6.0, 0.08, 1.0), _p(bx, wz - 0.55, 0.92), wood)
	b.box(Vector3(5.8, 0.05, 0.9), _p(bx, wz - 0.55, 0.3), wood)
	for lx in [-2.9, 2.9]:
		for lz in [-0.42, 0.42]:
			b.box(Vector3(0.08, 0.88, 0.08), _p(bx + lx, wz - 0.55 + lz, 0.44), steel)
	b.box(Vector3(0.6, 0.3, 0.3), _p(bx - 2.0, wz - 0.5, 1.11), _tex("metal", Color(0.8, 0.15, 0.1), 0.5, 0.4))   # caja de herramientas
	b.box(Vector3(0.22, 0.18, 0.22), _p(bx + 1.8, wz - 0.75, 1.05), steel)                                            # morsa
	b.box(Vector3(0.08, 0.1, 0.3), _p(bx + 1.8, wz - 0.75, 1.18), steel, MeshBatch.DETAIL)
	b.box(Vector3(0.28, 0.2, 0.07), _p(bx, wz - 0.6, 1.07), _tex("plastic", Color(0.95, 0.7, 0.1), 1.0, 0.5))      # taladro
	b.box(Vector3(0.06, 0.16, 0.07), _p(bx - 0.08, wz - 0.6, 0.96), black, MeshBatch.DETAIL)
	var paints := [Color(0.95, 0.95, 0.92), Color(0.7, 0.2, 0.15), Color(0.2, 0.45, 0.7), Color(0.9, 0.75, 0.3)]
	for i in 4:
		b.cylinder(0.12, 0.24, _p(bx - 0.9 + i * 0.3, wz - 0.4, 1.08), _tex("metal", paints[i], 0.4, 0.4), 10, MeshBatch.DETAIL)
	# Estanterías de materiales (latas de pintura, baldes, cables y cajas rotuladas).
	for k in 2:
		var shx := c.x - sx + 11.0 + k * 3.4
		b.solid(Vector3(3.0, 2.6, 0.7), _p(shx, wz - 0.4, 1.3), blue_steel)
		for lv in 3:
			for j in 4:
				var y := 0.35 + lv * 0.85
				var px := shx - 1.1 + j * 0.72
				if (j + lv + k) % 3 == 0:
					b.box(Vector3(0.6, 0.38, 0.5), _p(px, wz - 0.82, y + 0.2), cardboard, MeshBatch.DETAIL)
				elif (j + lv) % 3 == 1:
					b.cylinder(0.14, 0.28, _p(px, wz - 0.82, y + 0.15), _tex("metal", paints[(j + k) % 4], 0.4, 0.4), 10, MeshBatch.DETAIL)
				else:
					b.cylinder(0.17, 0.12, _p(px, wz - 0.82, y + 0.07), Mats.color(Color(0.15, 0.15, 0.15), 0.8), 12, MeshBatch.DETAIL)
		_label(root, "MATERIALES" if k == 0 else "PINTURERÍA", Transform3D(Basis(Vector3.UP, PI), Vector3(shx, 2.75, wz - 0.78)), 36, Color(1, 0.95, 0.85), 30.0)
	# Escalera de pintor abierta y placas de yeso apoyadas contra la pared.
	var lx0 := c.x + sx - 3.0
	for s in [-1.0, 1.0]:
		b.box(Vector3(0.5, 2.1, 0.06), Transform3D(Basis(Vector3.RIGHT, s * 0.22), Vector3(lx0, 1.02, wz - 1.4 + s * 0.24)), wood)
	for i in 5:
		b.box(Vector3(0.5, 0.04, 0.1), _p(lx0, wz - 1.4 + 0.24 - i * 0.02, 0.35 + i * 0.38), wood, MeshBatch.DETAIL)
	for i in 4:
		b.box(Vector3(1.2, 2.4, 0.03), Transform3D(Basis(Vector3.RIGHT, -0.12), Vector3(c.x + sx - 5.5 - i * 0.03, 1.2, wz - 0.25 - i * 0.04)), _tex("concrete", Color(0.92, 0.92, 0.9), 2.0))
	# --- Pared oeste: el cartel de la empresa, cajas de mudanza, la zorra y mantas.
	b.box(Vector3(0.06, 1.6, 7.0), _p(west, c.z, 4.6), Mats.color(Color(0.95, 0.5, 0.15), 0.7))
	for l in [_label(root, "MUDANCEROS TRUCHOS", Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(west + 0.05, 4.85, c.z)), 120, Color(0.1, 0.08, 0.06), 60.0),
			_label(root, "Mudanzas y reparaciones del hogar", Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(west + 0.05, 4.2, c.z)), 60, Color(0.1, 0.08, 0.06), 60.0)]:
		(l as Label3D).outline_size = 0
	var stacks := [[-4.6, 3], [-3.7, 2], [3.6, 3], [4.5, 2], [-4.6, 1]]
	for i in stacks.size():
		var st: Array = stacks[i]
		for lv in int(st[1]):
			var p := Vector3(west + 0.55 + (i % 2) * 0.1, 0.3 + lv * 0.6, c.z + float(st[0]) + (lv % 2) * 0.08)
			if i == 4:
				p.x += 0.9
			b.solid(Vector3(0.8, 0.58, 0.8), _p(p.x, p.z, p.y), cardboard)
			b.box(Vector3(0.82, 0.6, 0.12), _p(p.x, p.z, p.y), tape, MeshBatch.DETAIL)
	b.box(Vector3(0.05, 1.3, 0.5), Transform3D(Basis(Vector3.FORWARD, 0.15), Vector3(west + 0.5, 0.68, c.z + 1.8)), steel)   # zorra
	b.box(Vector3(0.5, 0.04, 0.45), _p(west + 0.62, c.z + 1.8, 0.06), steel, MeshBatch.DETAIL)
	for i in 3:
		b.box(Vector3(0.9, 0.12, 0.7), _p(west + 0.6, c.z - 1.6, 0.06 + i * 0.12), _tex("fabric", Color(0.25, 0.35, 0.6), 0.6, 1.0))
	# --- Rincón de la oficina (pared de adelante, -z): escritorio, computadora, silla, archivero.
	var desk := COMPUTER_DESK
	b.solid(Vector3(2.4, 0.06, 1.0), _p(desk.x, desk.z, 0.76), dark_wood)
	for lx in [-1.1, 1.1]:
		b.box(Vector3(0.06, 0.74, 0.9), _p(desk.x + lx, desk.z, 0.37), dark_wood)
	b.box(Vector3(0.5, 0.6, 0.85), _p(desk.x + 0.75, desk.z, 0.4), dark_wood)            # cajonera
	# Monitor viejo (de tubo), teclado, mouse y la torre abajo.
	b.box(Vector3(0.52, 0.44, 0.45), _p(desk.x, desk.z - 0.15, 1.02), _tex("plastic", Color(0.85, 0.83, 0.76), 1.0, 0.5))
	b.box(Vector3(0.44, 0.33, 0.02), _p(desk.x, desk.z + 0.08, 1.04), Mats.color(Color(0.35, 0.55, 0.85), 0.3, 1.2), MeshBatch.GLOW)
	b.box(Vector3(0.46, 0.03, 0.16), _p(desk.x, desk.z + 0.3, 0.8), _tex("plastic", Color(0.82, 0.8, 0.74), 1.0, 0.5))
	b.box(Vector3(0.07, 0.03, 0.11), _p(desk.x + 0.36, desk.z + 0.3, 0.8), _tex("plastic", Color(0.82, 0.8, 0.74), 1.0, 0.5), MeshBatch.DETAIL)
	b.box(Vector3(0.2, 0.42, 0.45), _p(desk.x - 0.75, desk.z - 0.1, 0.22), _tex("plastic", Color(0.85, 0.83, 0.76), 1.0, 0.5))
	b.box(Vector3(0.25, 0.35, 0.03), _p(desk.x - 0.7, desk.z + 0.1, 0.96), Mats.color(Color(0.95, 0.95, 0.9), 0.8), MeshBatch.DETAIL)  # papeles
	b.cylinder(0.05, 0.1, _p(desk.x + 0.65, desk.z + 0.1, 0.84), Mats.color(Color(0.9, 0.3, 0.2), 0.6), 10, MeshBatch.DETAIL)        # taza
	# Silla de escritorio (sin colisión: el que se sienta se acomoda solo).
	var chair := COMPUTER_SEAT
	b.box(Vector3(0.5, 0.08, 0.5), _p(chair.x, chair.z, 0.48), black)
	b.box(Vector3(0.48, 0.55, 0.07), _p(chair.x, chair.z + 0.25, 0.82), black)
	b.cylinder(0.04, 0.4, _p(chair.x, chair.z, 0.25), steel, 8)
	b.box(Vector3(0.55, 0.04, 0.08), _p(chair.x, chair.z, 0.04), steel, MeshBatch.DETAIL)
	b.box(Vector3(0.08, 0.04, 0.55), _p(chair.x, chair.z, 0.04), steel, MeshBatch.DETAIL)
	# Lámpara de escritorio (luz de verdad, chica y cálida).
	b.box(Vector3(0.12, 0.35, 0.12), _p(desk.x - 1.0, desk.z - 0.25, 0.95), black, MeshBatch.DETAIL)
	b.box(Vector3(0.22, 0.1, 0.22), _p(desk.x - 1.0, desk.z - 0.1, 1.15), Mats.color(Color(1, 0.85, 0.6), 0.5, 2.0), MeshBatch.GLOW)
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(1.0, 0.8, 0.55)
	lamp.light_energy = 1.2
	lamp.omni_range = 4.0
	lamp.position = Vector3(desk.x - 0.9, 1.3, desk.z + 0.1)
	root.add_child(lamp)
	# La computadora se usa con E (la mira el jugador).
	var pc := StaticBody3D.new()
	pc.name = "Computadora"
	pc.collision_layer = Config.L_WORLD
	pc.collision_mask = 0
	pc.position = Vector3(desk.x, 1.0, desk.z)
	pc.set_meta("interact", "computer")
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.9, 0.55, 0.9)
	shape.shape = box
	pc.add_child(shape)
	root.add_child(pc)
	# Archivero, corcho con encargos, calendario y reloj.
	b.solid(Vector3(0.5, 1.3, 0.6), _p(desk.x - 1.75, sw + 0.32, 0.65), steel)
	for i in 4:
		b.box(Vector3(0.42, 0.02, 0.02), _p(desk.x - 1.75, sw + 0.63, 0.25 + i * 0.32), black, MeshBatch.DETAIL)
	b.box(Vector3(1.4, 0.9, 0.03), _p(desk.x, sw + 0.02, 1.75), _tex("wood", Color(0.75, 0.55, 0.35), 0.3))
	var notes := [Color(1, 0.95, 0.5), Color(0.95, 0.95, 0.95), Color(0.6, 0.85, 1.0), Color(1, 0.7, 0.75)]
	for i in 6:
		b.box(Vector3(0.18, 0.2, 0.01), _p(desk.x - 0.5 + (i % 3) * 0.45, sw + 0.04, 1.6 + (i / 3) * 0.32), Mats.color(notes[i % 4], 0.9), MeshBatch.DETAIL)
	b.box(Vector3(0.5, 0.6, 0.01), _p(desk.x + 1.2, sw + 0.03, 1.7), Mats.color(Color(0.97, 0.97, 0.95), 0.9))
	var month := _label(root, "OCTUBRE", Transform3D(Basis(), Vector3(desk.x + 1.2, 1.92, sw + 0.04)), 13, Color(0.75, 0.1, 0.1), 15.0)
	month.outline_size = 0
	b.cylinder(0.2, 0.04, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(desk.x - 1.75, 2.4, sw + 0.03)), Mats.color(Color(0.95, 0.95, 0.92), 0.6), 16)
	# --- Rincón de descanso: sillón viejo, mesita, heladera y cafetera.
	var sofa := Vector3(c.x + 3.2, 0, sw + 0.55)
	var sofa_mat := _tex("fabric", Color(0.45, 0.3, 0.2), 0.6, 1.0)
	b.solid(Vector3(2.0, 0.45, 0.85), _p(sofa.x, sofa.z, 0.22), sofa_mat)
	b.box(Vector3(2.0, 0.55, 0.2), _p(sofa.x, sofa.z - 0.33, 0.7), sofa_mat)
	for s in [-1.0, 1.0]:
		b.box(Vector3(0.2, 0.3, 0.85), _p(sofa.x + s * 0.95, sofa.z, 0.55), sofa_mat)
	b.box(Vector3(2.6, 0.01, 1.8), _p(sofa.x, sofa.z + 0.9, 0.045), _tex("fabric", Color(0.55, 0.2, 0.18), 0.5, 1.0))
	b.solid(Vector3(0.9, 0.4, 0.5), _p(sofa.x, sofa.z + 1.3, 0.2), wood)
	b.box(Vector3(0.18, 0.12, 0.12), _p(sofa.x - 0.2, sofa.z + 1.3, 0.46), Mats.color(Color(0.85, 0.55, 0.15), 0.4), MeshBatch.DETAIL)
	var fridge := Vector3(c.x + 5.2, 0, sw + 0.4)
	b.solid(Vector3(0.7, 1.6, 0.65), _p(fridge.x, fridge.z, 0.8), _tex("plastic", Color(0.92, 0.92, 0.9), 1.0, 0.4))
	b.box(Vector3(0.04, 0.4, 0.04), _p(fridge.x + 0.28, fridge.z + 0.34, 1.0), steel, MeshBatch.DETAIL)
	b.solid(Vector3(1.0, 0.9, 0.55), _p(fridge.x + 1.0, fridge.z, 0.45), wood)
	b.box(Vector3(0.22, 0.3, 0.2), _p(fridge.x + 0.9, fridge.z, 1.05), black, MeshBatch.DETAIL)
	b.box(Vector3(0.05, 0.05, 0.05), _p(fridge.x + 0.9, fridge.z + 0.11, 1.12), Mats.color(Color(1, 0.2, 0.1), 0.5, 2.0), MeshBatch.GLOW)
	# --- Más cosas de obra: pallets con bolsas de cemento y cerámicos, carretilla, alfombras
	# enrolladas, matafuego y carteles de seguridad.
	var pallet := _tex("wood", Color(0.75, 0.62, 0.45), 1.0)
	var bag := _tex("fabric", Color(0.75, 0.72, 0.66), 0.5, 1.0)
	var px0 := c.x + sx - 2.0
	for k in 2:
		var pz := c.z + sz - 3.4 - k * 1.5
		b.solid(Vector3(1.2, 0.14, 1.0), _p(px0, pz, 0.07), pallet)
		for lv in 3 - k:
			for j in 2:
				b.box(Vector3(0.55, 0.16, 0.85), _p(px0 - 0.28 + j * 0.56, pz, 0.22 + lv * 0.17), bag if k == 0 else _tex("tiles", Color(0.85, 0.7, 0.55), 0.4, 0.4))
	var barrow := Transform3D(Basis(Vector3.UP, 0.6), Vector3(c.x + sx - 4.2, 0, c.z + sz - 3.2))
	b.box(Vector3(0.65, 0.3, 0.95), _at(barrow, Vector3(0, 0.55, 0), Vector3(-8, 0, 0)), _tex("metal", Color(0.85, 0.3, 0.1), 0.6, 0.5))
	b.cylinder(0.18, 0.08, _at(barrow, Vector3(0, 0.18, 0.55), Vector3(0, 0, 90)), black, 10, MeshBatch.DETAIL)
	for s in [-1.0, 1.0]:
		b.box(Vector3(0.04, 0.04, 1.3), _at(barrow, Vector3(s * 0.25, 0.45, -0.3), Vector3(10, 0, 0)), steel, MeshBatch.DETAIL)
	for i in 3:
		b.cylinder(0.16, 1.9, Transform3D(Basis(Vector3.FORWARD, 0.08), Vector3(west + 0.35, 0.95, c.z - 4.2 - i * 0.36)), _tex("fabric", [Color(0.6, 0.2, 0.2), Color(0.3, 0.4, 0.3), Color(0.55, 0.45, 0.3)][i], 0.4, 1.0), 10)
	var red := Mats.color(Color(0.8, 0.08, 0.06), 0.4)
	b.cylinder(0.09, 0.5, _p(c.x + sx - 0.35, c.z + WAREHOUSE_DOOR.x * 0.5 + 0.6, 0.55), red, 10)
	b.box(Vector3(0.05, 0.1, 0.05), _p(c.x + sx - 0.35, c.z + WAREHOUSE_DOOR.x * 0.5 + 0.6, 0.85), black, MeshBatch.DETAIL)
	var signs := [["PROHIBIDO FUMAR", Color(0.8, 0.1, 0.08), Color(1, 1, 1), Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(c.x + sx - 0.18, 2.6, c.z + WAREHOUSE_DOOR.x * 0.5 + 1.8))],
			["SEGURIDAD ANTE TODO", Color(0.95, 0.78, 0.15), Color(0.1, 0.1, 0.1), Transform3D(Basis(Vector3.UP, PI), Vector3(c.x - 1.0, 2.9, wz - 0.03))],
			["USE CASCO Y GUANTES", Color(0.15, 0.4, 0.75), Color(1, 1, 1), Transform3D(Basis(), Vector3(c.x - 6.0, 2.6, sw + 0.03))]]
	for sg: Array in signs:
		var t: Transform3D = sg[3]
		b.box(Vector3(1.5, 0.45, 0.02), t, Mats.color(sg[1], 0.6))
		var l := _label(root, sg[0], t.translated_local(Vector3(0, 0, 0.02)), 30, sg[2], 30.0)
		l.outline_size = 0

# ---------------------------------------------------------------- bordes

## Paredes invisibles alrededor del mapa, y una hilera de árboles para que no se vea el final.
static func _world_edges(root: Node3D) -> void:
	var b := MeshBatch.new(root)
	var r := RandomNumberGenerator.new()
	r.seed = 77
	var m := MAP
	for d in [[Vector3(m.size.x, 6, 1), Vector3(m.get_center().x, 3, m.position.y)], [Vector3(m.size.x, 6, 1), Vector3(m.get_center().x, 3, m.end.y)],
			[Vector3(1, 6, m.size.y), Vector3(m.position.x, 3, m.get_center().y)], [Vector3(1, 6, m.size.y), Vector3(m.end.x, 3, m.get_center().y)]]:
		b.collider(d[0], Transform3D(Basis(), d[1]))
	var x := m.position.x
	while x < m.end.x:
		for z in [m.position.y - 3.0, m.end.y + 3.0]:
			_tree(b, Vector3(x + r.randf_range(-2, 2), 0, z + r.randf_range(-2, 2)), r.randf_range(1.2, 1.7))
		x += 7.0
	var z := m.position.y
	while z < m.end.y:
		for xx in [m.position.x - 3.0, m.end.x + 3.0]:
			_tree(b, Vector3(xx + r.randf_range(-2, 2), 0, z + r.randf_range(-2, 2)), r.randf_range(1.2, 1.7))
		z += 7.0
	b.commit()
