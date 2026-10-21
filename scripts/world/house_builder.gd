class_name HouseBuilder
extends RefCounted
## Arma la casa de Don Ramón, su patio y el camión de mudanzas con cajas texturizadas
## (las texturas las genera tools/generate_textures.py). La ciudad alrededor la arma CityBuilder.
## También devuelve los datos que usa la partida: puertas, objetos para robar, tablas que crujen
## y los puntos por donde camina el dueño.
##
## Cada pared tiene dos "caras" finitas, una por lado, y cada cara pertenece a un lugar
## ("ext" afuera, o el cuarto de ese lado). Así la casa puede ser de ladrillo por fuera y tener
## empapelado en la sala. Cada noche se elige un estilo distinto (ver make_style y apply_style).
##
## Planta (vista desde arriba, el frente da a la calle, hacia +Z):
##
##   z=-6 +-----------+--+-----------+
##        |  cocina   |  |   baño    |
##        |           |p |-----------+ z=-3
##        |           |a |  estudio  |
##   z=0  +---  ------+s +-----------+
##        |           |i |           |
##        |   sala    |l | dormitorio|  (la cama, contra la pared de la derecha)
##        |           |l |           |
##   z=6  +----||-----+o +-----------+
##       x=-8        x=0 x=2        x=8
##             ↓ puerta de calle → camino → vereda → camión (estacionado en la calle)

const H := 2.8          # alto de las paredes
const T := 0.16         # grosor de las paredes
const FLOOR_Y := 0.03   # el piso de la casa queda apenas sobre el pasto
const SKIN := 0.01      # grosor de las caras de las paredes
const WOOD := Color(0.62, 0.45, 0.3)
const DARK_WOOD := Color(0.42, 0.3, 0.2)
const WHITE := Color(0.92, 0.92, 0.9)

## Dónde está estacionado el camión (centro de la caja de carga) y hacia dónde mira.
## Bien lejos de la pieza de Don Ramón: si no, el motor lo despertaría.
const TRUCK_POS := Vector3(-10.0, 0.0, 18.7)
const TRUCK_ROT := -90.0      # la puerta de carga (atrás) mira hacia la entrada de la casa

static func build(world: Node3D) -> Dictionary:
	var refs := {"slots": {}}
	var root := Node3D.new()
	root.name = "House"
	world.add_child(root)
	_environment(root, refs)
	CityBuilder.build(root)
	_shell(root, refs)
	_rooms(root, refs)
	_furniture(root, refs)
	_yard(root)
	_truck(root, refs)
	refs["doors"] = _doors(root)
	refs["items"] = _items()
	refs["boards"] = _boards(root)
	refs["waypoints"] = WAYPOINTS
	refs["edges"] = EDGES
	return refs

# ---------------------------------------------------------------- datos de la casa

## Puntos por donde camina el dueño (x, z) y cómo se conectan.
const WAYPOINTS := {
	"cama": Vector3(5.5, 0, 4.2), "pieza": Vector3(4.5, 0, 2.5), "pieza_puerta": Vector3(2.7, 0, 2.5),
	"pasillo_pieza": Vector3(1.0, 0, 2.5), "pasillo_frente": Vector3(1.0, 0, 5.2), "pasillo_medio": Vector3(1.0, 0, 0.0),
	"pasillo_estudio": Vector3(1.0, 0, -1.5), "pasillo_cocina": Vector3(1.0, 0, -2.4), "pasillo_baño": Vector3(1.0, 0, -4.5),
	"pasillo_fondo": Vector3(1.0, 0, -5.4),
	"estudio_puerta": Vector3(2.7, 0, -1.5), "estudio": Vector3(5.0, 0, -1.5),
	"baño_puerta": Vector3(2.7, 0, -4.5), "baño": Vector3(4.5, 0, -4.5),
	"sala_pasillo": Vector3(-0.7, 0, 2.6), "sala": Vector3(-4.2, 0, 1.2), "sala_puerta": Vector3(-4.0, 0, 5.2),
	"sala_cocina": Vector3(-4.2, 0, 0.0), "cocina": Vector3(-5.2, 0, -2.4), "cocina_pasillo": Vector3(-0.7, 0, -2.4),
	"cocina_puerta": Vector3(-6.0, 0, -5.2),
	"afuera_frente": Vector3(-4.0, 0, 7.7), "afuera_fondo": Vector3(-6.0, 0, -7.3),
	"patio_fi": Vector3(-9.5, 0, 7.7), "patio_ti": Vector3(-9.5, 0, -7.3),
	"patio_fd": Vector3(9.5, 0, 7.7), "patio_td": Vector3(9.5, 0, -7.3),
	"jardin": Vector3(-4.0, 0, 12.0),
}
const EDGES := [
	["cama", "pieza"], ["pieza", "pieza_puerta"], ["pieza_puerta", "pasillo_pieza"],
	["pasillo_pieza", "pasillo_frente"], ["pasillo_pieza", "pasillo_medio"], ["pasillo_pieza", "sala_pasillo"],
	["pasillo_medio", "pasillo_estudio"], ["pasillo_estudio", "pasillo_cocina"], ["pasillo_cocina", "pasillo_baño"],
	["pasillo_baño", "pasillo_fondo"], ["pasillo_estudio", "estudio_puerta"], ["estudio_puerta", "estudio"],
	["pasillo_baño", "baño_puerta"], ["baño_puerta", "baño"], ["pasillo_cocina", "cocina_pasillo"],
	["cocina_pasillo", "cocina"], ["sala_pasillo", "sala"], ["sala", "sala_puerta"], ["sala", "sala_cocina"],
	["sala_cocina", "cocina"], ["cocina", "cocina_puerta"], ["sala_puerta", "afuera_frente"],
	["cocina_puerta", "afuera_fondo"], ["afuera_frente", "patio_fi"], ["patio_fi", "patio_ti"],
	["patio_ti", "afuera_fondo"], ["afuera_frente", "patio_fd"], ["patio_fd", "patio_td"], ["patio_td", "afuera_fondo"],
	["afuera_frente", "jardin"],
]

## Dónde duerme el dueño: posición del cuerpo acostado (los pies) y giro.
const BED_LYING := Vector3(6.05, 0.84, 4.2)
const BED_LYING_ROT := Vector3(90, 90, 0)
const BED_SIT := Vector3(5.75, 0.45, 4.2)
## Adónde tira el dueño a los ladrones que atrapa (el jardín de adelante).
const EJECT_POS := Vector3(-1.5, 0.2, 10.5)
## Inicio de cada jugador (en la vereda, junto a la puerta de carga del camión, mirando a la casa).
const SPAWNS := [Vector3(-6.8, 0.1, 16.2), Vector3(-5.4, 0.1, 16.2), Vector3(-6.8, 0.1, 17.2), Vector3(-5.4, 0.1, 17.2)]
## Zona del camión: quien está acá cuando se van, se va con el camión.
const TRUCK_ZONE := Rect2(-15.5, 15.4, 10.5, 6.0)
const HOUSE_RECT := Rect2(-8.0, -6.0, 16.0, 12.0)

static func in_house(p: Vector3) -> bool:
	return HOUSE_RECT.has_point(Vector2(p.x, p.z))

static func at_truck(p: Vector3) -> bool:
	return TRUCK_ZONE.has_point(Vector2(p.x, p.z))

## Cuarto en el que cae un punto ("ext" si es afuera).
static func room_key(p: Vector3) -> String:
	if not in_house(p):
		return "ext"
	if p.x < 0.0:
		return "sala" if p.z > 0.0 else "cocina"
	if p.x < 2.0:
		return "pasillo"
	if p.z > 0.0:
		return "dormitorio"
	return "estudio" if p.z > -3.0 else "baño"

const ROOM_NAMES := {"ext": "afuera", "sala": "la sala", "cocina": "la cocina", "pasillo": "el pasillo",
		"dormitorio": "el dormitorio", "estudio": "el estudio", "baño": "el baño"}

## Nombre del lugar (para los avisos: "se escuchó algo en la cocina").
static func room_name(p: Vector3) -> String:
	return ROOM_NAMES[room_key(p)]

## Objetos para robar (y otros que solo hacen ruido): [id, posición, giro en grados].
static func _items() -> Array:
	return [
		["tv", Vector3(-7.65, 0.84, 3.0), 0.0],
		["console", Vector3(-7.65, 0.55, 3.75), 0.0],
		["sofa", Vector3(-3.0, 0.44, 3.0), 0.0],
		["vase", Vector3(-5.2, 0.61, 3.35), 0.0],
		["lamp", Vector3(-1.0, 0.84, 5.4), 0.0],
		["painting", Vector3(-2.0, 1.6, 5.88), 0.0],
		["painting", Vector3(-6.5, 1.6, 0.12), 180.0],
		["microwave", Vector3(-1.0, 1.07, -5.62), 0.0],
		["blender", Vector3(-2.2, 1.1, -5.62), 0.0],
		["plates", Vector3(-3.4, 0.97, -5.62), 0.0],
		["pot", Vector3(-4.4, 1.02, -5.62), 0.0],
		["chair", Vector3(-3.5, 0.49, -3.2), 90.0],
		["chair", Vector3(-1.7, 0.49, -3.2), -90.0],
		["jewelry", Vector3(7.7, 0.66, 2.9), 90.0],
		["watch", Vector3(5.3, 0.95, 0.35), 0.0],
		["safe", Vector3(3.0, 0.39, 0.65), 0.0],
		["laptop", Vector3(7.55, 0.79, -1.6), 90.0],
		["pc", Vector3(7.6, 0.27, -0.5), 0.0],
		["office_chair", Vector3(6.8, 0.54, -1.5), 90.0],
		["guitar", Vector3(3.0, 0.54, -0.4), 0.0],
		["trophy", Vector3(4.2, 1.4, -2.8), 0.0],
		["perfume", Vector3(5.3, 0.95, -5.72), 0.0],
		["duck", Vector3(6.9, 0.65, -3.45), 30.0],
		["photo", Vector3(1.8, 0.94, 4.6), 90.0],
	]

# ---------------------------------------------------------------- estilos

## Fachadas posibles: [revestimiento, color, techo, color del techo, marcos, postigos, puerta, zócalo]
const FACADES := [
	["siding", Color(0.96, 0.96, 0.93), "shingles", Color(0.42, 0.42, 0.45), Color(0.97, 0.97, 0.95), Color(0.15, 0.24, 0.4), Color(0.55, 0.12, 0.1), "brick"],
	["siding", Color(0.62, 0.74, 0.86), "shingles", Color(0.3, 0.3, 0.33), Color(0.97, 0.97, 0.95), Color(0.97, 0.97, 0.95), Color(0.12, 0.2, 0.32), "stone"],
	["siding", Color(0.7, 0.78, 0.62), "shingles", Color(0.5, 0.4, 0.33), Color(0.95, 0.92, 0.84), Color(0.2, 0.32, 0.22), Color(0.62, 0.45, 0.3), "stone"],
	["siding", Color(0.98, 0.88, 0.58), "shingles", Color(0.36, 0.36, 0.38), Color(0.97, 0.97, 0.95), Color(0.45, 0.14, 0.12), Color(0.18, 0.3, 0.2), "brick"],
	["brick", Color(1.0, 1.0, 1.0), "shingles", Color(0.3, 0.3, 0.32), Color(0.95, 0.94, 0.9), Color(0.1, 0.1, 0.11), Color(0.15, 0.15, 0.17), "concrete"],
	["brick", Color(0.82, 0.72, 0.68), "shingles", Color(0.5, 0.42, 0.36), Color(0.94, 0.9, 0.82), Color(0.25, 0.32, 0.25), Color(0.62, 0.45, 0.3), "concrete"],
	["stucco", Color(0.96, 0.88, 0.74), "clay_tiles", Color(1.0, 1.0, 1.0), Color(0.52, 0.36, 0.24), Color(0.3, 0.45, 0.32), Color(0.45, 0.3, 0.2), "stone"],
	["stucco", Color(0.97, 0.8, 0.78), "clay_tiles", Color(0.95, 0.9, 0.9), Color(0.98, 0.98, 0.96), Color(0.2, 0.45, 0.55), Color(0.2, 0.45, 0.55), "stone"],
	["stucco", Color(0.98, 0.98, 0.96), "clay_tiles", Color(0.9, 0.85, 0.8), Color(0.2, 0.3, 0.5), Color(0.2, 0.3, 0.5), Color(0.2, 0.3, 0.5), "concrete"],
]

const PAINTS := [Color(0.95, 0.93, 0.86), Color(0.9, 0.94, 0.95), Color(0.95, 0.88, 0.78), Color(0.84, 0.9, 0.8),
		Color(0.96, 0.9, 0.9), Color(0.82, 0.86, 0.93), Color(0.98, 0.95, 0.8)]
const PAPERS := [Color(0.92, 0.86, 0.72), Color(0.78, 0.86, 0.76), Color(0.9, 0.78, 0.78), Color(0.78, 0.82, 0.92),
		Color(0.95, 0.92, 0.85), Color(0.7, 0.62, 0.55)]
const WOODS := [Color(1.0, 1.0, 1.0), Color(0.78, 0.68, 0.6), Color(1.12, 1.02, 0.9), Color(0.62, 0.5, 0.42)]
const CARPETS := [Color(0.72, 0.65, 0.55), Color(0.55, 0.58, 0.62), Color(0.5, 0.56, 0.7), Color(0.72, 0.55, 0.58), Color(0.5, 0.6, 0.5)]
const TILES := [Color(0.96, 0.96, 0.94), Color(0.88, 0.86, 0.8), Color(0.72, 0.8, 0.86), Color(0.7, 0.72, 0.74), Color(0.86, 0.92, 0.86)]

## Arma un estilo de casa al azar (con una semilla, así todas las computadoras ven lo mismo).
## Cada valor es [textura, color, metros que mide la textura, aspereza].
static func make_style(seed: int) -> Dictionary:
	var r := RandomNumberGenerator.new()
	r.seed = seed
	var f: Array = FACADES[r.randi() % FACADES.size()]
	var pick := func(list: Array) -> Color: return list[r.randi() % list.size()]
	var wall := func() -> Array:
		match r.randi() % 3:
			0:
				return ["wallpaper_damask", pick.call(PAPERS), 1.0, 0.9]
			1:
				return ["wallpaper_stripes", pick.call(PAPERS), 1.2, 0.9]
		return ["paint", pick.call(PAINTS), 2.0, 0.9]
	var wood_floor := func() -> Array: return ["wood_floor", pick.call(WOODS), 1.15, 0.6]
	var s := {
		"ext": [f[0], f[1], 1.0 if f[0] != "stucco" else 2.0, 0.9],
		"roof": [f[2], f[3], 1.0 if f[2] == "shingles" else 1.4, 0.85],
		"trim": ["paint", f[4], 1.0, 0.6],
		"shutter": ["door_wood", f[5], 1.0, 0.6],
		"found": [f[7], Color(0.9, 0.9, 0.9) if f[7] != "brick" else Color(0.8, 0.7, 0.65), 1.0, 0.95],
		"front_door": f[6],
		"sala": wall.call(),
		"cocina": ["paint", pick.call(PAINTS), 2.0, 0.8],
		"pasillo": ["paint", pick.call(PAINTS), 2.0, 0.9] if r.randf() < 0.6 else wall.call(),
		"dormitorio": wall.call(),
		"estudio": ["paint", pick.call([Color(0.55, 0.65, 0.58), Color(0.55, 0.6, 0.72), Color(0.75, 0.62, 0.5)] + PAINTS), 2.0, 0.9] \
				if r.randf() < 0.6 else wall.call(),
		"baño": ["tiles_small", pick.call(TILES), 1.2, 0.3],
		"backsplash": ["tiles_small", pick.call(TILES), 0.8, 0.3],
		"f_sala": wood_floor.call() if r.randf() < 0.75 else ["carpet", pick.call(CARPETS), 1.0, 1.0],
		"f_cocina": ["tiles", pick.call(TILES), 1.2, 0.4],
		"f_pasillo": wood_floor.call(),
		"f_dormitorio": ["carpet", pick.call(CARPETS), 1.0, 1.0] if r.randf() < 0.7 else wood_floor.call(),
		"f_estudio": wood_floor.call(),
		"f_baño": ["tiles", pick.call(TILES), 0.8, 0.35],
		"blanket": ["fabric", Color.from_hsv(r.randf(), r.randf_range(0.25, 0.5), r.randf_range(0.5, 0.75)), 0.6, 1.0],
		"curtain": ["fabric", Color.from_hsv(r.randf(), r.randf_range(0.2, 0.45), r.randf_range(0.55, 0.85)), 0.5, 1.0],
		"rug": ["fabric", Color.from_hsv(r.randf(), r.randf_range(0.35, 0.6), r.randf_range(0.35, 0.6)), 0.5, 1.0],
	}
	return s

static func style_material(spec: Array) -> StandardMaterial3D:
	return Mats.tex(spec[0], spec[1], spec[2], true, spec[3])

## Le pone a la casa el estilo de esta semilla (se llama al empezar cada noche).
static func apply_style(refs: Dictionary, seed: int) -> void:
	var style := make_style(seed)
	var slots: Dictionary = refs["slots"]
	for slot: String in slots:
		if not style.has(slot):
			continue
		var mat := style_material(style[slot])
		for mi: MeshInstance3D in slots[slot]:
			mi.material_override = mat
	if refs.has("doors") and not (refs["doors"] as Array).is_empty():
		(refs["doors"][0] as Door).paint(style["front_door"])

## Registra una malla en un "lugar" del estilo (para poder cambiarle el material después).
static func _slot(refs: Dictionary, slot: String, mi: MeshInstance3D) -> MeshInstance3D:
	var slots: Dictionary = refs["slots"]
	if not slots.has(slot):
		slots[slot] = []
	slots[slot].append(mi)
	return mi

# ---------------------------------------------------------------- ambiente

static func _environment(root: Node3D, refs: Dictionary) -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.02, 0.03, 0.08)
	sky_mat.sky_horizon_color = Color(0.1, 0.12, 0.2)
	sky_mat.ground_horizon_color = Color(0.08, 0.09, 0.12)
	sky_mat.ground_bottom_color = Color(0.03, 0.03, 0.04)
	sky_mat.sun_angle_max = 2.0
	sky.sky_material = sky_mat
	env.sky = sky
	# Noche: luz ambiente azulada y tenue. Se ve, pero con la linterna se ve mucho mejor.
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.42, 0.48, 0.72)
	env.ambient_light_energy = 0.36
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 6.0
	env.fog_enabled = true
	env.fog_light_color = Color(0.06, 0.07, 0.12)
	env.fog_density = 0.01
	env.glow_enabled = true
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
	var moon := DirectionalLight3D.new()
	moon.rotation_degrees = Vector3(-48, 30, 0)
	moon.light_energy = 0.35
	moon.light_color = Color(0.6, 0.7, 1.0)
	moon.shadow_enabled = true
	moon.shadow_bias = 0.2
	moon.shadow_normal_bias = 2.5
	moon.directional_shadow_max_distance = 40.0
	moon.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	root.add_child(moon)
	refs["env"] = env
	refs["moon"] = moon

# ---------------------------------------------------------------- helpers

## Caja visual con textura.
static func _box(root: Node3D, size: Vector3, pos: Vector3, mat: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = Mats.box_mesh(size)
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot
	root.add_child(mi)
	return mi

## Caja sólida (con colisión) con textura.
static func _solid(root: Node3D, size: Vector3, pos: Vector3, mat: Material, layer := Config.L_WORLD) -> StaticBody3D:
	var body := Mats.add_solid_box(root, size, pos, Color.WHITE, layer)
	(body.get_child(1) as MeshInstance3D).material_override = mat
	return body

static func _collider(root: Node3D, size: Vector3, pos: Vector3, layer := Config.L_WORLD) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = layer
	body.collision_mask = 0
	body.position = pos
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	root.add_child(body)
	return body

static func _tex(name: String, tint := Color.WHITE, meters := 1.0, roughness := 0.85) -> StandardMaterial3D:
	return Mats.tex(name, tint, meters, true, roughness)

## Prisma triangular (techo a dos aguas), con las caras de los dos lados (sirve cualquier material).
static func _prism(root: Node3D, x0: float, x1: float, half_depth: float, base_y: float, ridge_y: float) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	var a := Vector2(-half_depth, base_y)   # (z, y)
	var b := Vector2(half_depth, base_y)
	var c := Vector2(0.0, ridge_y)
	var tris := [
		[Vector3(x0, a.y, a.x), Vector3(x1, a.y, a.x), Vector3(x1, c.y, c.x)],
		[Vector3(x0, a.y, a.x), Vector3(x1, c.y, c.x), Vector3(x0, c.y, c.x)],
		[Vector3(x0, b.y, b.x), Vector3(x0, c.y, c.x), Vector3(x1, c.y, c.x)],
		[Vector3(x0, b.y, b.x), Vector3(x1, c.y, c.x), Vector3(x1, b.y, b.x)],
		[Vector3(x0, a.y, a.x), Vector3(x0, c.y, c.x), Vector3(x0, b.y, b.x)],
		[Vector3(x1, a.y, a.x), Vector3(x1, b.y, b.x), Vector3(x1, c.y, c.x)],
	]
	for tri: Array in tris:
		for v: Vector3 in tri:
			st.add_vertex(v)
		for i in [2, 1, 0]:
			st.add_vertex(tri[i])
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	root.add_child(mi)
	return mi

## Árbol: tronco y copa en dos o tres bloques.
static func _tree(root: Node3D, p: Vector3, big := 1.0) -> void:
	_solid(root, Vector3(0.35, 2.2, 0.35) * Vector3(big, 1, big), p + Vector3(0, 1.1, 0), _tex("bark", Color.WHITE, 1.0))
	var leaves := _tex("leaves", Color.WHITE, 1.5, 1.0)
	_box(root, Vector3(2.6, 1.9, 2.6) * big, p + Vector3(0, 3.0 * big, 0), leaves, Vector3(0, 20, 0))
	_box(root, Vector3(1.9, 1.4, 1.9) * big, p + Vector3(0, 4.3 * big, 0), leaves, Vector3(0, 55, 0))

static func _bush(root: Node3D, p: Vector3, size: Vector3) -> void:
	_solid(root, size, p + Vector3(0, size.y * 0.5, 0), _tex("leaves", Color(0.9, 1.0, 0.9), 1.0, 1.0))

## Auto estacionado (de adorno, pero sólido).
static func _car(root: Node3D, p: Vector3, rot_y: float, c: Color) -> void:
	var car := Node3D.new()
	car.position = p
	car.rotation_degrees.y = rot_y
	root.add_child(car)
	var paint := Mats.tex("metal", c, 2.0, true, 0.35)
	_solid(car, Vector3(1.8, 0.7, 4.2), Vector3(0, 0.6, 0), paint)
	_box(car, Vector3(1.6, 0.6, 2.2), Vector3(0, 1.25, -0.2), paint)
	var glass := Mats.color(Color(0.12, 0.15, 0.2), 0.1, 0.0, 0.3)
	_box(car, Vector3(1.62, 0.45, 2.0), Vector3(0, 1.28, -0.2), glass)
	_box(car, Vector3(1.5, 0.42, 0.05), Vector3(0, 1.25, 0.92), glass, Vector3(-30, 0, 0))
	for sz in [-1.35, 1.35]:
		for sx in [-0.9, 0.9]:
			Mats.add_cylinder(car, 0.33, 0.25, Vector3(sx, 0.33, sz), Color(0.06, 0.06, 0.06), Vector3(0, 0, 90), 12)
	for sx in [-0.65, 0.65]:
		var tail := Mats.add_box(car, Vector3(0.3, 0.12, 0.04), Vector3(sx, 0.75, -2.11), Color(0.5, 0.05, 0.05))
		tail.material_override = Mats.color(Color(0.6, 0.05, 0.05), 0.4, 0.6)

# ---------------------------------------------------------------- paredes

## Pared a lo largo del eje X (en `z`), de x0 a x1, con vanos [desde, hasta] (puertas o pasos).
static func _wall_x(root: Node3D, refs: Dictionary, z: float, x0: float, x1: float, gaps := []) -> void:
	for piece in _pieces(x0, x1, gaps):
		_wall_piece(root, refs, true, z, piece[0], piece[1], piece[2], piece[3])

## Pared a lo largo del eje Z (en `x`), de z0 a z1, con vanos.
static func _wall_z(root: Node3D, refs: Dictionary, x: float, z0: float, z1: float, gaps := []) -> void:
	for piece in _pieces(z0, z1, gaps):
		_wall_piece(root, refs, false, x, piece[0], piece[1], piece[2], piece[3])

## Divide una pared en tramos: [desde, hasta, altura de abajo, altura de arriba].
## Sobre cada vano queda un dintel (hasta el techo).
static func _pieces(a0: float, a1: float, gaps: Array) -> Array:
	var out := []
	var a := a0
	for g: Array in gaps + [[a1, a1]]:
		if g[0] > a:
			out.append([a, g[0], 0.0, H])
		if g[1] > g[0]:
			out.append([g[0], g[1], Door.HEIGHT + 0.05, H])
		a = g[1]
	return out

## Un tramo de pared: el cuerpo (con colisión, color de los marcos) y una cara fina de cada lado
## con el material del cuarto que da a ese lado. `along_x` = la pared corre a lo largo de X.
static func _wall_piece(root: Node3D, refs: Dictionary, along_x: bool, at: float, a: float, b: float, y0: float, y1: float) -> void:
	var length := b - a
	var mid := (a + b) * 0.5
	var hy := y1 - y0
	var cy := (y0 + y1) * 0.5
	var size := Vector3(length, hy, T) if along_x else Vector3(T, hy, length)
	var pos := Vector3(mid, cy, at) if along_x else Vector3(at, cy, mid)
	var body := Mats.add_solid_box(root, size, pos, Color.WHITE, Config.L_WORLD | Config.L_WALL)
	var core := body.get_child(1) as MeshInstance3D
	# El cuerpo queda tapado por las caras: si también hiciera sombra, las mancharía con rayas.
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_slot(refs, "trim", core)
	# Las caras se cortan donde cambia el cuarto (por ejemplo, la pared de adelante da a la sala,
	# al pasillo y al dormitorio).
	var splits := [-8.0, 0.0, 2.0, 8.0] if along_x else [-6.0, -3.0, 0.0, 6.0]
	var cuts := [a]
	for s: float in splits:
		if s > a + 0.001 and s < b - 0.001:
			cuts.append(s)
	cuts.append(b)
	for i in cuts.size() - 1:
		var c: float = cuts[i]
		var d: float = cuts[i + 1]
		for side in [-1.0, 1.0]:
			var probe := Vector3((c + d) * 0.5, 1.0, at + side * 0.4) if along_x else Vector3(at + side * 0.4, 1.0, (c + d) * 0.5)
			var key := room_key(probe)
			var ext := key == "ext"
			var c2 := c
			var d2 := d
			if ext:
				# Afuera, las caras tapan también las esquinas de la casa.
				var lo := -8.0 if along_x else -6.0
				var hi := 8.0 if along_x else 6.0
				if c2 <= lo + 0.001:
					c2 -= T * 0.5 + SKIN * 2.0
				if d2 >= hi - 0.001:
					d2 += T * 0.5 + SKIN * 2.0
			var off: float = side * (T * 0.5 + SKIN * 0.5 + 0.004)
			var l2 := d2 - c2
			var m2 := (c2 + d2) * 0.5
			var skin_size := Vector3(l2, hy, SKIN) if along_x else Vector3(SKIN, hy, l2)
			var skin_pos := Vector3(m2, cy, at + off) if along_x else Vector3(at + off, cy, m2)
			_slot(refs, key, _box(root, skin_size, skin_pos, Mats.color(WHITE)))
			if y0 > 0.0:
				continue
			# Abajo: zócalo de madera adentro, base de piedra o ladrillo afuera.
			var band_h := 0.5 if ext else 0.1
			var band_t := 0.03 if ext else 0.02
			var boff: float = side * (T * 0.5 + SKIN + 0.004 + band_t * 0.5 + 0.002)
			var bsize := Vector3(l2, band_h, band_t) if along_x else Vector3(band_t, band_h, l2)
			var bpos := Vector3(m2, FLOOR_Y + band_h * 0.5, at + boff) if along_x else Vector3(at + boff, FLOOR_Y + band_h * 0.5, m2)
			if ext:
				_slot(refs, "found", _box(root, bsize, bpos, Mats.color(WHITE)))
			else:
				_box(root, bsize, bpos, _tex("wood", Color(0.75, 0.62, 0.5), 0.8, 0.6))

## Ventana: vidrio con "luz de luna", marco, alféizar, postigos afuera y cortinas adentro.
## `out` es hacia dónde queda la calle (afuera).
static func _window(root: Node3D, refs: Dictionary, center: Vector3, out: Vector3, w: float, h: float) -> void:
	var along_x := absf(out.z) > 0.5
	var depth := T + 0.06
	var glass_size := Vector3(w, h, depth) if along_x else Vector3(depth, h, w)
	var glass := Mats.add_box(root, glass_size, center, Color(0.3, 0.4, 0.62))
	glass.material_override = Mats.color(Color(0.28, 0.38, 0.6), 0.1, 0.5)
	var f := depth + 0.02
	var trim := Mats.color(WHITE)
	if along_x:
		_slot(refs, "trim", _box(root, Vector3(w + 0.14, 0.09, f), center + Vector3(0, h * 0.5, 0), trim))
		_slot(refs, "trim", _box(root, Vector3(w + 0.14, 0.09, f), center - Vector3(0, h * 0.5, 0), trim))
		_slot(refs, "trim", _box(root, Vector3(0.07, h, f), center + Vector3(-w * 0.5, 0, 0), trim))
		_slot(refs, "trim", _box(root, Vector3(0.07, h, f), center + Vector3(w * 0.5, 0, 0), trim))
		_slot(refs, "trim", _box(root, Vector3(0.05, h, f), center, trim))
		_slot(refs, "trim", _box(root, Vector3(w + 0.3, 0.05, 0.14), center + Vector3(0, -h * 0.5 - 0.06, out.z * 0.12), trim))
	else:
		_slot(refs, "trim", _box(root, Vector3(f, 0.09, w + 0.14), center + Vector3(0, h * 0.5, 0), trim))
		_slot(refs, "trim", _box(root, Vector3(f, 0.09, w + 0.14), center - Vector3(0, h * 0.5, 0), trim))
		_slot(refs, "trim", _box(root, Vector3(f, h, 0.07), center + Vector3(0, 0, -w * 0.5), trim))
		_slot(refs, "trim", _box(root, Vector3(f, h, 0.07), center + Vector3(0, 0, w * 0.5), trim))
		_slot(refs, "trim", _box(root, Vector3(f, h, 0.05), center, trim))
		_slot(refs, "trim", _box(root, Vector3(0.14, 0.05, w + 0.3), center + Vector3(out.x * 0.12, -h * 0.5 - 0.06, 0), trim))
	var side_dir := Vector3(1, 0, 0) if along_x else Vector3(0, 0, 1)
	for s in [-1.0, 1.0]:
		# Postigos (afuera).
		var shutter_size := Vector3(0.36, h + 0.1, 0.04) if along_x else Vector3(0.04, h + 0.1, 0.36)
		_slot(refs, "shutter", _box(root, shutter_size, center + side_dir * s * (w * 0.5 + 0.24) + out * (T * 0.5 + 0.04), Mats.color(WHITE)))
		# Cortinas (adentro).
		var curtain_size := Vector3(0.32, h + 0.35, 0.04) if along_x else Vector3(0.04, h + 0.35, 0.32)
		_slot(refs, "curtain", _box(root, curtain_size, center + side_dir * s * (w * 0.5 + 0.08) - out * (T * 0.5 + 0.06) + Vector3(0, 0.1, 0), Mats.color(WHITE)))

static func _shell(root: Node3D, refs: Dictionary) -> void:
	# Piso y techo (el techo tapa la luna: adentro está oscuro).
	Mats.add_solid_box(root, Vector3(16.0, 0.1, 12.0), Vector3(0, FLOOR_Y - 0.05, 0), WOOD)
	_solid(root, Vector3(16.3, 0.1, 12.3), Vector3(0, H + 0.05, 0), _tex("paint", Color(0.95, 0.95, 0.93), 2.0), Config.L_WORLD | Config.L_WALL)
	# Paredes de afuera (con la puerta de calle y la de atrás).
	_wall_x(root, refs, 6.0, -8.0, 8.0, [[-4.5, -3.5]])
	_wall_x(root, refs, -6.0, -8.0, 8.0, [[-6.5, -5.5]])
	_wall_z(root, refs, -8.0, -6.0, 6.0)
	_wall_z(root, refs, 8.0, -6.0, 6.0)
	# Paredes de adentro.
	_wall_x(root, refs, 0.0, -8.0, 0.0, [[-5.0, -3.4]])              # sala | cocina (paso abierto)
	_wall_z(root, refs, 0.0, -6.0, 6.0, [[-3.0, -1.8], [2.0, 3.2]])  # pasillo | cocina y sala (pasos abiertos)
	_wall_z(root, refs, 2.0, -6.0, 6.0, [[-5.0, -4.0], [-2.0, -1.0], [2.0, 3.0]])   # pasillo | baño, estudio, pieza
	_wall_x(root, refs, 0.0, 2.0, 8.0)                               # dormitorio | estudio
	_wall_x(root, refs, -3.0, 2.0, 8.0)                              # estudio | baño
	# Ventanas.
	_window(root, refs, Vector3(-6.3, 1.5, 6.0), Vector3(0, 0, 1), 1.4, 1.1)
	_window(root, refs, Vector3(-1.6, 1.5, 6.0), Vector3(0, 0, 1), 0.9, 1.1)
	_window(root, refs, Vector3(3.3, 1.5, 6.0), Vector3(0, 0, 1), 1.0, 1.1)
	_window(root, refs, Vector3(6.6, 1.5, 6.0), Vector3(0, 0, 1), 1.0, 1.1)
	_window(root, refs, Vector3(-2.3, 1.6, -6.0), Vector3(0, 0, -1), 1.4, 0.9)
	_window(root, refs, Vector3(5.5, 1.8, -6.0), Vector3(0, 0, -1), 0.7, 0.6)
	_window(root, refs, Vector3(-8.0, 1.5, 3.0), Vector3(-1, 0, 0), 1.6, 1.1)
	_window(root, refs, Vector3(-8.0, 1.5, -3.0), Vector3(-1, 0, 0), 1.4, 1.1)
	_window(root, refs, Vector3(8.0, 1.5, 1.3), Vector3(1, 0, 0), 1.0, 1.1)
	_window(root, refs, Vector3(8.0, 1.5, -1.5), Vector3(1, 0, 0), 1.0, 1.1)
	# Esquineros.
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_slot(refs, "trim", _box(root, Vector3(0.16, H, 0.16), Vector3(sx * (8.0 + T * 0.5), H * 0.5, sz * (6.0 + T * 0.5)), Mats.color(WHITE)))
	# Techo a dos aguas, aleros y chimenea.
	_slot(refs, "roof", _prism(root, -8.6, 8.6, 6.8, H + 0.1, H + 2.5))
	for sz in [-1.0, 1.0]:
		_slot(refs, "trim", _box(root, Vector3(17.2, 0.18, 0.06), Vector3(0, H + 0.04, sz * 6.82), Mats.color(WHITE)))
	_box(root, Vector3(0.8, 2.6, 0.8), Vector3(-5.5, H + 1.7, -2.6), _tex("brick", Color(0.85, 0.8, 0.78), 1.0))
	_box(root, Vector3(0.95, 0.12, 0.95), Vector3(-5.5, H + 3.0, -2.6), _tex("concrete", Color.WHITE, 1.0))
	# Alero de la entrada con dos columnas, escalón y luz de la puerta.
	_slot(refs, "roof", _box(root, Vector3(2.6, 0.14, 1.6), Vector3(-4.0, Door.HEIGHT + 0.35, 6.9), Mats.color(WHITE), Vector3(-8, 0, 0)))
	for sx in [-1.15, 1.15]:
		_slot(refs, "trim", _box(root, Vector3(0.14, Door.HEIGHT + 0.3, 0.14), Vector3(-4.0 + sx, (Door.HEIGHT + 0.3) * 0.5, 7.6), Mats.color(WHITE)))
	_box(root, Vector3(2.2, 0.08, 1.4), Vector3(-4.0, 0.04, 6.85), _tex("concrete", Color.WHITE, 1.0))
	var porch := OmniLight3D.new()
	porch.light_color = Color(1.0, 0.78, 0.5)
	porch.light_energy = 0.9
	porch.omni_range = 5.5
	porch.position = Vector3(-4.0, Door.HEIGHT + 0.15, 6.45)
	root.add_child(porch)
	var bulb := Mats.add_box(root, Vector3(0.14, 0.2, 0.1), Vector3(-3.3, 2.0, 6.15), Color(1, 0.8, 0.5))
	bulb.material_override = Mats.color(Color(1, 0.8, 0.5), 0.5, 2.5)
	var number := Label3D.new()
	number.text = "1847"
	number.font_size = 40
	number.pixel_size = 0.005
	number.modulate = Color(0.95, 0.9, 0.75)
	number.position = Vector3(-2.75, 2.0, 6.11)
	root.add_child(number)

# ---------------------------------------------------------------- cuartos

static func _floor_patch(root: Node3D, refs: Dictionary, slot: String, rect: Rect2) -> void:
	_slot(refs, slot, _box(root, Vector3(rect.size.x, 0.004, rect.size.y), Vector3(rect.get_center().x, FLOOR_Y + 0.002, rect.get_center().y), Mats.color(WHITE)))

static func _rooms(root: Node3D, refs: Dictionary) -> void:
	_floor_patch(root, refs, "f_sala", Rect2(-8, 0, 8, 6))
	_floor_patch(root, refs, "f_cocina", Rect2(-8, -6, 8, 6))
	_floor_patch(root, refs, "f_pasillo", Rect2(0, -6, 2, 12))
	_floor_patch(root, refs, "f_dormitorio", Rect2(2, 0, 6, 6))
	_floor_patch(root, refs, "f_estudio", Rect2(2, -3, 6, 3))
	_floor_patch(root, refs, "f_baño", Rect2(2, -6, 6, 3))
	# Luz de noche en el pasillo (enchufada abajo, naranja y débil).
	var night := OmniLight3D.new()
	night.light_color = Color(1.0, 0.65, 0.3)
	night.light_energy = 0.7
	night.omni_range = 4.5
	night.position = Vector3(0.2, 0.35, 0.6)
	root.add_child(night)
	var plug := Mats.add_box(root, Vector3(0.06, 0.1, 0.08), Vector3(0.1, 0.35, 0.6), Color(1.0, 0.7, 0.35))
	plug.material_override = Mats.color(Color(1.0, 0.7, 0.35), 0.5, 2.0)
	# Lámpara del velador del dueño: se prende cuando se despierta.
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(1.0, 0.82, 0.55)
	lamp.light_energy = 0.0
	lamp.omni_range = 7.0
	lamp.shadow_enabled = true
	lamp.position = Vector3(7.7, 1.15, 5.5)
	root.add_child(lamp)
	refs["bedroom_lamp"] = lamp

# ---------------------------------------------------------------- muebles fijos

static func _table(root: Node3D, size: Vector3, pos: Vector3, mat: Material) -> void:
	_solid(root, Vector3(size.x, 0.06, size.z), Vector3(pos.x, size.y - 0.03, pos.z), mat)
	for sx in [-0.5, 0.5]:
		for sz in [-0.5, 0.5]:
			_solid(root, Vector3(0.06, size.y - 0.06, 0.06),
					Vector3(pos.x + sx * (size.x - 0.1), (size.y - 0.06) * 0.5, pos.z + sz * (size.z - 0.1)), mat)

static func _furniture(root: Node3D, refs: Dictionary) -> void:
	var y := FLOOR_Y
	var wood := _tex("wood", Color.WHITE, 1.0, 0.6)
	var dark := _tex("wood", Color(0.62, 0.5, 0.42), 1.0, 0.6)
	var cabinet := _tex("wood", Color(1.15, 1.12, 1.08), 1.0, 0.5)
	var ceramic := _tex("plastic", Color(0.97, 0.97, 0.97), 1.0, 0.15)
	var steel := _tex("metal", Color(0.95, 0.95, 0.95), 1.0, 0.3)
	# --- Sala ---
	_solid(root, Vector3(0.45, 0.5, 1.8), Vector3(-7.72, y + 0.25 - 0.03, 3.0), dark)        # mueble de la tele
	_table(root, Vector3(0.6, 0.4, 1.2), Vector3(-5.2, 0, 3.0), wood)                         # mesa de centro
	_solid(root, Vector3(0.35, 1.8, 1.2), Vector3(-0.25, 0.9, 4.7), dark)                     # biblioteca
	var spines := [Color(0.6, 0.2, 0.2), Color(0.2, 0.35, 0.55), Color(0.65, 0.55, 0.25), Color(0.3, 0.45, 0.3), Color(0.5, 0.4, 0.55)]
	for i in 3:
		for j in 5:
			_box(root, Vector3(0.04, 0.28 + (j % 2) * 0.04, 0.16), Vector3(-0.44, 0.45 + i * 0.5, 4.2 + j * 0.22),
					_tex("fabric", spines[(i + j) % spines.size()], 0.3, 0.8))
	_slot(refs, "rug", _box(root, Vector3(3.0, 0.006, 2.4), Vector3(-5.0, y + 0.005, 3.0), Mats.color(WHITE)))
	var standby := Mats.add_box(root, Vector3(0.02, 0.02, 0.02), Vector3(-7.48, 0.53, 2.3), Color(1, 0.1, 0.1))
	standby.material_override = Mats.color(Color(1, 0.1, 0.1), 0.5, 4.0)
	# --- Cocina ---
	_solid(root, Vector3(5.0, 0.86, 0.6), Vector3(-2.7, 0.43, -5.68), cabinet)                # muebles bajos
	for i in 8:
		_box(root, Vector3(0.02, 0.6, 0.02), Vector3(-5.05 + i * 0.62, 0.45, -5.37), _tex("metal", Color(0.5, 0.5, 0.52), 1.0, 0.4))
	_box(root, Vector3(5.04, 0.05, 0.64), Vector3(-2.7, 0.885, -5.68), _tex("marble", Color.WHITE, 1.2, 0.2))   # mesada
	_box(root, Vector3(0.7, 0.02, 0.5), Vector3(-4.4, 0.92, -5.68), Mats.color(Color(0.08, 0.08, 0.08), 0.3))   # hornallas
	_slot(refs, "backsplash", _box(root, Vector3(5.0, 0.6, 0.012), Vector3(-2.7, 1.21, -6.0 + T * 0.5 + 0.02), Mats.color(WHITE)))
	_box(root, Vector3(5.0, 0.7, 0.35), Vector3(-2.7, 2.05, -5.8), cabinet)                   # alacenas
	_solid(root, Vector3(0.8, 1.9, 0.7), Vector3(-7.5, 0.95, -5.55), steel)                   # heladera
	_box(root, Vector3(0.04, 0.5, 0.05), Vector3(-7.15, 1.2, -5.18), _tex("metal", Color(0.4, 0.4, 0.42), 1.0, 0.3))
	_table(root, Vector3(1.2, 0.75, 0.8), Vector3(-2.6, 0, -3.2), wood)
	var clock := Label3D.new()
	clock.text = "03:12"
	clock.font_size = 28
	clock.pixel_size = 0.004
	clock.modulate = Color(0.3, 1.0, 0.4)
	clock.position = Vector3(-7.5, 1.6, -5.18)
	root.add_child(clock)
	# --- Pasillo ---
	_solid(root, Vector3(0.35, 0.8, 0.7), Vector3(1.78, 0.4, 4.6), dark)
	# --- Dormitorio ---
	_solid(root, Vector3(2.0, 0.45, 1.6), Vector3(7.0, 0.225, 4.2), dark)                     # cama
	_box(root, Vector3(1.95, 0.12, 1.55), Vector3(7.0, 0.51, 4.2), _tex("fabric", Color(0.95, 0.95, 0.93), 0.5, 1.0))
	_slot(refs, "blanket", _box(root, Vector3(1.4, 0.4, 1.62), Vector3(6.7, 0.77, 4.2), Mats.color(WHITE)))     # frazada
	_box(root, Vector3(0.35, 0.14, 1.0), Vector3(7.7, 0.64, 4.2), _tex("fabric", Color(0.97, 0.97, 0.97), 0.4, 1.0))
	_solid(root, Vector3(0.1, 1.0, 1.7), Vector3(7.95, 0.5, 4.2), dark)                       # respaldo
	_solid(root, Vector3(0.5, 0.55, 0.5), Vector3(7.7, 0.275, 2.9), wood)                     # veladores
	_solid(root, Vector3(0.5, 0.55, 0.5), Vector3(7.7, 0.275, 5.5), wood)
	Mats.add_cylinder(root, 0.06, 0.3, Vector3(7.7, 0.7, 5.5), Color(0.4, 0.42, 0.45))
	var shade := Mats.add_cylinder(root, 0.16, 0.2, Vector3(7.7, 0.95, 5.5), Color(0.95, 0.88, 0.7))
	shade.material_override = _tex("fabric", Color(0.98, 0.9, 0.72), 0.3, 1.0)
	_solid(root, Vector3(1.6, 2.1, 0.6), Vector3(4.8, 1.05, 5.62), dark)                      # ropero
	_box(root, Vector3(0.02, 1.9, 0.02), Vector3(4.8, 1.05, 5.31), Mats.color(Color(0.2, 0.14, 0.09)))
	_solid(root, Vector3(1.2, 0.9, 0.5), Vector3(5.0, 0.45, 0.33), wood)                      # cómoda
	var mirror := Mats.add_box(root, Vector3(0.8, 0.9, 0.03), Vector3(5.0, 1.55, 0.12), Color(0.55, 0.62, 0.7))
	mirror.material_override = Mats.color(Color(0.55, 0.62, 0.7), 0.05, 0.0, 0.8)
	# --- Estudio ---
	_solid(root, Vector3(0.7, 0.75, 1.4), Vector3(7.6, 0.375, -1.5), wood)                    # escritorio
	_solid(root, Vector3(1.2, 1.2, 0.3), Vector3(4.5, 0.6, -2.8), dark)                       # repisa
	# --- Baño ---
	_solid(root, Vector3(0.45, 0.45, 0.65), Vector3(7.6, 0.225, -5.6), ceramic)               # inodoro
	_solid(root, Vector3(0.4, 0.5, 0.2), Vector3(7.6, 0.7, -5.88), ceramic)
	_solid(root, Vector3(0.6, 0.85, 0.45), Vector3(5.4, 0.425, -5.72), ceramic)               # lavamanos
	_solid(root, Vector3(1.7, 0.55, 0.75), Vector3(6.9, 0.275, -3.45), ceramic)               # bañera
	_box(root, Vector3(1.5, 0.02, 0.55), Vector3(6.9, 0.555, -3.45), Mats.color(Color(0.6, 0.75, 0.85), 0.1))
	var bath_mirror := Mats.add_box(root, Vector3(0.6, 0.7, 0.03), Vector3(5.4, 1.5, -5.89), Color(0.55, 0.62, 0.7))
	bath_mirror.material_override = Mats.color(Color(0.55, 0.62, 0.7), 0.05, 0.0, 0.8)

# ---------------------------------------------------------------- el patio

static func _yard(root: Node3D) -> void:
	# Camino de piedras desde la puerta hasta la vereda.
	_box(root, Vector3(1.4, 0.03, 8.2), Vector3(-4.0, 0.016, 11.6), _tex("stone", Color(0.9, 0.9, 0.9), 1.0))
	# Cerco vivo a lo largo de la vereda (con un paso para el camino).
	_bush(root, Vector3(-8.7, 0, 15.0), Vector3(6.6, 0.9, 0.7))
	_bush(root, Vector3(4.7, 0, 15.0), Vector3(14.6, 0.9, 0.7))
	for p in [Vector3(-6.5, 0, 6.75), Vector3(-1.6, 0, 6.75), Vector3(3.3, 0, 6.75), Vector3(6.6, 0, 6.75)]:
		_bush(root, p, Vector3(1.2, 0.7, 0.6))
	# Cerca de madera atrás y a los costados.
	var fence := _tex("door_wood", Color(0.8, 0.68, 0.55), 1.0, 0.9)
	_solid(root, Vector3(24.0, 1.2, 0.1), Vector3(0, 0.6, -10.0), fence)
	_solid(root, Vector3(0.1, 1.2, 24.0), Vector3(-12.0, 0.6, 2.0), fence)
	_solid(root, Vector3(0.1, 1.2, 24.0), Vector3(12.0, 0.6, 2.0), fence)
	for x in range(-12, 13, 2):
		_box(root, Vector3(0.14, 1.35, 0.14), Vector3(x, 0.67, -10.0), fence)
	# Buzón, tachos de basura y árboles.
	var post := _tex("door_wood", Color(0.7, 0.6, 0.5), 1.0)
	_solid(root, Vector3(0.1, 1.0, 0.1), Vector3(-2.2, 0.5, 15.8), post)
	_box(root, Vector3(0.25, 0.25, 0.45), Vector3(-2.2, 1.1, 15.8), _tex("metal", Color(0.2, 0.25, 0.35), 1.0, 0.4))
	for x in [-1.2, -0.5]:
		_solid(root, Vector3(0.55, 1.0, 0.6), Vector3(x, 0.5, 15.9), _tex("plastic", Color(0.25, 0.35, 0.28), 1.0, 0.5))
	for p in [Vector3(-10.0, 0, 3.0), Vector3(9.8, 0, 11.5), Vector3(-9.5, 0, -8.0), Vector3(7.0, 0, -8.5)]:
		_tree(root, p)
	# El auto viejo de Don Ramón, en su entrada.
	_box(root, Vector3(3.2, 0.03, 8.8), Vector3(5.0, 0.015, 11.2), _tex("concrete", Color(0.9, 0.9, 0.9), 2.0))
	_car(root, Vector3(5.0, 0, 11.0), 180.0, Color(0.55, 0.12, 0.12))

# ---------------------------------------------------------------- puertas

## Puertas: [nombre, bisagra, giro de la pared, hacia dónde abre, qué tan fuerte chilla]
static func _doors(root: Node3D) -> Array:
	var specs := [
		["puerta de calle", Vector3(-4.5, FLOOR_Y, 6.0), 0.0, 1.0, 0.25],
		["puerta de la cocina", Vector3(-6.5, FLOOR_Y, -6.0), 0.0, -1.0, 0.25],
		["puerta del dormitorio", Vector3(2.0, FLOOR_Y, 2.0), -90.0, 1.0, 0.6],
		["puerta del estudio", Vector3(2.0, FLOOR_Y, -2.0), -90.0, 1.0, 0.3],
		["puerta del baño", Vector3(2.0, FLOOR_Y, -5.0), -90.0, 1.0, 0.3],
	]
	var doors := []
	for i in specs.size():
		var s: Array = specs[i]
		var d := Door.create(i, s[0], s[1], s[2], 1.0, s[3], s[4])
		root.add_child(d)
		doors.append(d)
	return doors

# ---------------------------------------------------------------- tablas que crujen

static func _boards(root: Node3D) -> Array:
	var rects := [
		Rect2(0.2, 1.6, 1.6, 1.8),      # frente a la puerta del dormitorio (la peor)
		Rect2(-4.6, 4.2, 1.2, 0.8),     # entrando por la puerta de calle
		Rect2(-6.6, -5.4, 1.2, 1.0),    # entrando por la puerta de la cocina
		Rect2(-1.2, 1.0, 1.0, 1.4),     # entre la sala y el pasillo
	]
	# Se ven apenas distintas: tablas más gastadas, un poco más claras.
	var worn := _tex("wood_floor", Color(1.15, 1.05, 0.95), 0.9, 0.7)
	for r: Rect2 in rects:
		_box(root, Vector3(r.size.x, 0.006, r.size.y), Vector3(r.get_center().x, FLOOR_Y + 0.006, r.get_center().y), worn)
	return rects

# ---------------------------------------------------------------- el camión

## El camión de mudanzas (ver truck.gd), estacionado en la calle.
static func _truck(root: Node3D, refs: Dictionary) -> void:
	var truck := Truck.new()
	root.add_child(truck)
	truck.park(TRUCK_POS, TRUCK_ROT)
	refs["truck"] = truck
	refs["truck_area"] = truck.area
