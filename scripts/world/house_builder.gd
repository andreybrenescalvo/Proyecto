class_name HouseBuilder
extends RefCounted
## Arma la casa de Don Ramón con cajas de colores (estilo low-poly, sin modelos externos):
## paredes con sus vanos, muebles fijos, ventanas, el patio, la calle y el camión de mudanzas.
## También devuelve los datos que usa la partida: puertas, objetos para robar, tablas que crujen
## y los puntos por donde camina el dueño.
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
##             ↓ puerta de calle → camión

const H := 2.8          # alto de las paredes
const T := 0.16         # grosor de las paredes
const FLOOR_Y := 0.03   # el piso de la casa queda apenas sobre el pasto
const WALL := Color(0.8, 0.76, 0.68)
const WOOD := Color(0.55, 0.38, 0.24)
const DARK_WOOD := Color(0.36, 0.25, 0.16)
const WHITE := Color(0.88, 0.88, 0.86)
const METAL := Color(0.4, 0.42, 0.45)
const GRASS := Color(0.2, 0.3, 0.17)

static func build(world: Node3D) -> Dictionary:
	var refs := {}
	var root := Node3D.new()
	root.name = "House"
	world.add_child(root)
	_environment(root, refs)
	_grounds(root)
	_shell(root)
	_rooms(root, refs)
	_furniture(root)
	_truck(root, refs)
	_neighborhood(root)
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
	"afuera_frente": Vector3(-4.0, 0, 7.3), "afuera_fondo": Vector3(-6.0, 0, -7.3),
	"patio_fi": Vector3(-9.5, 0, 7.3), "patio_ti": Vector3(-9.5, 0, -7.3),
	"patio_fd": Vector3(9.5, 0, 7.3), "patio_td": Vector3(9.5, 0, -7.3),
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
]

## Dónde duerme el dueño: posición del cuerpo acostado (los pies) y giro.
const BED_LYING := Vector3(6.05, 0.84, 4.2)
const BED_LYING_ROT := Vector3(90, 90, 0)
const BED_SIT := Vector3(5.75, 0.45, 4.2)
## Adónde tira el dueño a los ladrones que atrapa.
const EJECT_POS := Vector3(-1.0, 0.2, 8.2)
## Inicio de cada jugador (al lado del camión, mirando a la casa).
const SPAWNS := [Vector3(-6.3, 0.1, 10.0), Vector3(-1.7, 0.1, 10.0), Vector3(-6.3, 0.1, 12.0), Vector3(-1.7, 0.1, 12.0)]
## Zona del camión: quien está acá cuando se van, se va con el camión.
const TRUCK_ZONE := Rect2(-7.5, 7.0, 7.0, 9.5)
const HOUSE_RECT := Rect2(-8.0, -6.0, 16.0, 12.0)

static func in_house(p: Vector3) -> bool:
	return HOUSE_RECT.has_point(Vector2(p.x, p.z))

static func at_truck(p: Vector3) -> bool:
	return TRUCK_ZONE.has_point(Vector2(p.x, p.z))

## Nombre del lugar (para los avisos: "se escuchó algo en la cocina").
static func room_name(p: Vector3) -> String:
	if not in_house(p):
		return "afuera"
	if p.x < 0.0:
		return "la sala" if p.z > 0.0 else "la cocina"
	if p.x < 2.0:
		return "el pasillo"
	if p.z > 0.0:
		return "el dormitorio"
	return "el estudio" if p.z > -3.0 else "el baño"

## Objetos para robar (y otros que solo hacen ruido): [id, posición, giro en grados].
static func _items() -> Array:
	return [
		["tv", Vector3(-7.65, 0.84, 3.0), 0.0],
		["console", Vector3(-7.65, 0.55, 3.75), 0.0],
		["sofa", Vector3(-3.0, 0.44, 3.0), 0.0],
		["vase", Vector3(-5.2, 0.61, 3.35), 0.0],
		["lamp", Vector3(-1.0, 0.84, 5.4), 0.0],
		["painting", Vector3(-2.0, 1.6, 5.895), 0.0],
		["painting", Vector3(-6.5, 1.6, 0.105), 180.0],
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
	env.fog_density = 0.012
	env.glow_enabled = true
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
	var moon := DirectionalLight3D.new()
	moon.rotation_degrees = Vector3(-48, 30, 0)
	moon.light_energy = 0.35
	moon.light_color = Color(0.6, 0.7, 1.0)
	moon.shadow_enabled = true
	moon.directional_shadow_max_distance = 50.0
	root.add_child(moon)
	refs["env"] = env
	refs["moon"] = moon

# ---------------------------------------------------------------- terreno

static func _grounds(root: Node3D) -> void:
	Mats.add_solid_box(root, Vector3(80, 1, 80), Vector3(0, -0.5, 0), GRASS)
	# Entrada de autos (desde la puerta hasta la calle), vereda y calle.
	Mats.add_box(root, Vector3(3.2, 0.02, 10.0), Vector3(-4.0, 0.01, 11.0), Color(0.42, 0.42, 0.42))
	Mats.add_box(root, Vector3(80, 0.03, 1.4), Vector3(0, 0.015, 16.7), Color(0.5, 0.5, 0.48))
	Mats.add_box(root, Vector3(80, 0.02, 7.0), Vector3(0, 0.01, 21.0), Color(0.12, 0.12, 0.13))
	for i in 12:
		Mats.add_box(root, Vector3(1.6, 0.025, 0.15), Vector3(-33.0 + i * 6.0, 0.015, 21.0), Color(0.85, 0.8, 0.5))
	# Cerca del patio (para que nadie se pierda en la oscuridad).
	var fence := Color(0.45, 0.33, 0.22)
	Mats.add_solid_box(root, Vector3(24.0, 1.2, 0.1), Vector3(0, 0.6, -10.0), fence)
	Mats.add_solid_box(root, Vector3(0.1, 1.2, 18.0), Vector3(-12.0, 0.6, -1.0), fence)
	Mats.add_solid_box(root, Vector3(0.1, 1.2, 18.0), Vector3(12.0, 0.6, -1.0), fence)
	for x in range(-12, 13, 2):
		Mats.add_box(root, Vector3(0.14, 1.35, 0.14), Vector3(x, 0.67, -10.0), fence.darkened(0.2))
	# Bordes invisibles del mundo.
	for d in [[Vector3(80, 4, 1), Vector3(0, 2, 26.0)], [Vector3(1, 4, 80), Vector3(-26.0, 2, 0)],
			[Vector3(1, 4, 80), Vector3(26.0, 2, 0)], [Vector3(80, 4, 1), Vector3(0, 2, -14.0)]]:
		var body := StaticBody3D.new()
		body.collision_layer = Config.L_WORLD
		body.position = d[1]
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = d[0]
		shape.shape = box
		body.add_child(shape)
		root.add_child(body)
	# Árboles.
	for p in [Vector3(-10.0, 0, 3.0), Vector3(10.0, 0, 9.0), Vector3(-9.5, 0, -8.0), Vector3(7.0, 0, -8.5)]:
		_tree(root, p)

static func _tree(root: Node3D, p: Vector3) -> void:
	var trunk := Mats.add_solid_box(root, Vector3(0.35, 2.2, 0.35), p + Vector3(0, 1.1, 0), Color(0.3, 0.22, 0.15))
	trunk.name = "Tree"
	Mats.add_box(root, Vector3(2.4, 1.8, 2.4), p + Vector3(0, 3.0, 0), Color(0.12, 0.22, 0.12), Vector3(0, 20, 0))
	Mats.add_box(root, Vector3(1.7, 1.3, 1.7), p + Vector3(0, 4.2, 0), Color(0.14, 0.25, 0.13), Vector3(0, 55, 0))

# ---------------------------------------------------------------- paredes

static func _wall(root: Node3D, size: Vector3, pos: Vector3) -> void:
	Mats.add_solid_box(root, size, pos, WALL, Config.L_WORLD | Config.L_WALL)

## Pared a lo largo del eje X (en `z`), de x0 a x1, con vanos [desde, hasta] (puertas o pasos).
static func _wall_x(root: Node3D, z: float, x0: float, x1: float, gaps := []) -> void:
	var x := x0
	for g: Array in gaps + [[x1, x1]]:
		if g[0] > x:
			_wall(root, Vector3(g[0] - x, H, T), Vector3((x + g[0]) * 0.5, H * 0.5, z))
		if g[1] > g[0]:
			_wall(root, Vector3(g[1] - g[0], H - Door.HEIGHT - 0.05, T), Vector3((g[0] + g[1]) * 0.5, (H + Door.HEIGHT + 0.05) * 0.5, z))
		x = g[1]

## Pared a lo largo del eje Z (en `x`), de z0 a z1, con vanos.
static func _wall_z(root: Node3D, x: float, z0: float, z1: float, gaps := []) -> void:
	var z := z0
	for g: Array in gaps + [[z1, z1]]:
		if g[0] > z:
			_wall(root, Vector3(T, H, g[0] - z), Vector3(x, H * 0.5, (z + g[0]) * 0.5))
		if g[1] > g[0]:
			_wall(root, Vector3(T, H - Door.HEIGHT - 0.05, g[1] - g[0]), Vector3(x, (H + Door.HEIGHT + 0.05) * 0.5, (g[0] + g[1]) * 0.5))
		z = g[1]

## Ventana de adorno: vidrio que deja ver la "luz de luna" de afuera.
static func _window(root: Node3D, center: Vector3, along_x: bool, w: float, h: float) -> void:
	var depth := T + 0.03
	var glass_size := Vector3(w, h, depth) if along_x else Vector3(depth, h, w)
	var glass := Mats.add_box(root, glass_size, center, Color(0.3, 0.4, 0.62))
	glass.material_override = Mats.color(Color(0.3, 0.4, 0.62), 0.2, 0.55)
	var frame := Color(0.92, 0.9, 0.85)
	var f := T + 0.06
	if along_x:
		Mats.add_box(root, Vector3(w + 0.12, 0.08, f), center + Vector3(0, h * 0.5, 0), frame)
		Mats.add_box(root, Vector3(w + 0.12, 0.08, f), center - Vector3(0, h * 0.5, 0), frame)
		Mats.add_box(root, Vector3(0.06, h, f), center, frame)
	else:
		Mats.add_box(root, Vector3(f, 0.08, w + 0.12), center + Vector3(0, h * 0.5, 0), frame)
		Mats.add_box(root, Vector3(f, 0.08, w + 0.12), center - Vector3(0, h * 0.5, 0), frame)
		Mats.add_box(root, Vector3(f, h, 0.06), center, frame)

static func _shell(root: Node3D) -> void:
	# Piso y techo (el techo tapa la luna: adentro está oscuro).
	Mats.add_solid_box(root, Vector3(16.0, 0.1, 12.0), Vector3(0, FLOOR_Y - 0.05, 0), WOOD)
	Mats.add_solid_box(root, Vector3(16.3, 0.1, 12.3), Vector3(0, H + 0.05, 0), Color(0.86, 0.85, 0.8), Config.L_WORLD | Config.L_WALL)
	# Paredes de afuera (con la puerta de calle y la de atrás).
	_wall_x(root, 6.0, -8.0, 8.0, [[-4.5, -3.5]])
	_wall_x(root, -6.0, -8.0, 8.0, [[-6.5, -5.5]])
	_wall_z(root, -8.0, -6.0, 6.0)
	_wall_z(root, 8.0, -6.0, 6.0)
	# Paredes de adentro.
	_wall_x(root, 0.0, -8.0, 0.0, [[-5.0, -3.4]])              # sala | cocina (paso abierto)
	_wall_z(root, 0.0, -6.0, 6.0, [[-3.0, -1.8], [2.0, 3.2]])  # pasillo | cocina y sala (pasos abiertos)
	_wall_z(root, 2.0, -6.0, 6.0, [[-5.0, -4.0], [-2.0, -1.0], [2.0, 3.0]])   # pasillo | baño, estudio, pieza
	_wall_x(root, 0.0, 2.0, 8.0)                               # dormitorio | estudio
	_wall_x(root, -3.0, 2.0, 8.0)                              # estudio | baño
	# Ventanas.
	_window(root, Vector3(-6.3, 1.5, 6.0), true, 1.4, 1.1)
	_window(root, Vector3(3.3, 1.5, 6.0), true, 1.0, 1.1)
	_window(root, Vector3(-2.3, 1.6, -6.0), true, 1.4, 0.9)
	_window(root, Vector3(5.5, 1.8, -6.0), true, 0.7, 0.6)
	_window(root, Vector3(-8.0, 1.5, 3.0), false, 1.6, 1.1)
	_window(root, Vector3(-8.0, 1.5, -3.0), false, 1.4, 1.1)
	_window(root, Vector3(8.0, 1.5, 1.3), false, 1.0, 1.1)
	_window(root, Vector3(8.0, 1.5, -1.5), false, 1.0, 1.1)
	_roof(root)
	# Escalón y alero de la puerta de calle, con la luz apagada.
	Mats.add_box(root, Vector3(1.6, 0.06, 0.8), Vector3(-4.0, 0.03, 6.5), Color(0.5, 0.48, 0.45))
	Mats.add_box(root, Vector3(1.4, 0.2, 0.25), Vector3(-4.0, 0.19, 6.15), Color(0.2, 0.2, 0.22))
	var number := Label3D.new()
	number.text = "1847"
	number.font_size = 40
	number.pixel_size = 0.005
	number.modulate = Color(0.9, 0.85, 0.7)
	number.position = Vector3(-2.9, 2.0, 6.1)
	root.add_child(number)

## Techo a dos aguas (un prisma triangular).
static func _roof(root: Node3D) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	var x0 := -8.6
	var x1 := 8.6
	var a := Vector2(-6.7, H + 0.05)   # (z, y)
	var b := Vector2(6.7, H + 0.05)
	var c := Vector2(0.0, H + 2.4)
	var verts := [
		# Caras inclinadas.
		[Vector3(x0, a.y, a.x), Vector3(x1, a.y, a.x), Vector3(x1, c.y, c.x)],
		[Vector3(x0, a.y, a.x), Vector3(x1, c.y, c.x), Vector3(x0, c.y, c.x)],
		[Vector3(x0, b.y, b.x), Vector3(x0, c.y, c.x), Vector3(x1, c.y, c.x)],
		[Vector3(x0, b.y, b.x), Vector3(x1, c.y, c.x), Vector3(x1, b.y, b.x)],
		# Triángulos de los costados.
		[Vector3(x0, a.y, a.x), Vector3(x0, c.y, c.x), Vector3(x0, b.y, b.x)],
		[Vector3(x1, a.y, a.x), Vector3(x1, b.y, b.x), Vector3(x1, c.y, c.x)],
	]
	for tri: Array in verts:
		for v: Vector3 in tri:
			st.add_vertex(v)
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.45, 0.2, 0.16)
	mat.roughness = 0.9
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = mat
	root.add_child(mi)

# ---------------------------------------------------------------- cuartos

static func _floor_patch(root: Node3D, rect: Rect2, c: Color) -> void:
	Mats.add_box(root, Vector3(rect.size.x, 0.004, rect.size.y), Vector3(rect.get_center().x, FLOOR_Y + 0.002, rect.get_center().y), c)

static func _rooms(root: Node3D, refs: Dictionary) -> void:
	_floor_patch(root, Rect2(-8, 0, 8, 6), Color(0.5, 0.34, 0.22))      # sala: madera
	_floor_patch(root, Rect2(-8, -6, 8, 6), Color(0.62, 0.6, 0.55))     # cocina: baldosa
	_floor_patch(root, Rect2(0, -6, 2, 12), Color(0.46, 0.32, 0.21))    # pasillo
	_floor_patch(root, Rect2(2, 0, 6, 6), Color(0.35, 0.3, 0.42))       # dormitorio: alfombra
	_floor_patch(root, Rect2(2, -3, 6, 3), Color(0.44, 0.3, 0.2))       # estudio
	_floor_patch(root, Rect2(2, -6, 6, 3), Color(0.55, 0.65, 0.68))     # baño
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

static func _solid(root: Node3D, size: Vector3, pos: Vector3, c: Color) -> StaticBody3D:
	return Mats.add_solid_box(root, size, pos, c)

static func _table(root: Node3D, size: Vector3, pos: Vector3, c: Color) -> void:
	_solid(root, Vector3(size.x, 0.06, size.z), Vector3(pos.x, size.y - 0.03, pos.z), c)
	for sx in [-0.5, 0.5]:
		for sz in [-0.5, 0.5]:
			_solid(root, Vector3(0.06, size.y - 0.06, 0.06),
					Vector3(pos.x + sx * (size.x - 0.1), (size.y - 0.06) * 0.5, pos.z + sz * (size.z - 0.1)), c.darkened(0.15))

static func _furniture(root: Node3D) -> void:
	var y := FLOOR_Y
	# --- Sala ---
	_solid(root, Vector3(0.45, 0.5, 1.8), Vector3(-7.72, y + 0.25 - 0.03, 3.0), DARK_WOOD)    # mueble de la tele
	_table(root, Vector3(0.6, 0.4, 1.2), Vector3(-5.2, 0, 3.0), WOOD)                         # mesa de centro
	_solid(root, Vector3(0.35, 1.8, 1.2), Vector3(-0.25, 0.9, 4.7), DARK_WOOD)                # biblioteca
	for i in 3:
		for j in 4:
			Mats.add_box(root, Vector3(0.04, 0.3, 0.08), Vector3(-0.44, 0.45 + i * 0.5, 4.25 + j * 0.28),
					[Color(0.6, 0.2, 0.2), Color(0.2, 0.35, 0.55), Color(0.65, 0.55, 0.25), Color(0.3, 0.45, 0.3)][(i + j) % 4])
	Mats.add_box(root, Vector3(3.0, 0.006, 2.4), Vector3(-5.0, y + 0.005, 3.0), Color(0.55, 0.22, 0.2))   # alfombra
	var standby := Mats.add_box(root, Vector3(0.02, 0.02, 0.02), Vector3(-7.48, 0.53, 2.3), Color(1, 0.1, 0.1))
	standby.material_override = Mats.color(Color(1, 0.1, 0.1), 0.5, 4.0)
	# --- Cocina ---
	_solid(root, Vector3(5.0, 0.9, 0.6), Vector3(-2.7, 0.45, -5.68), Color(0.85, 0.83, 0.78))   # mesada
	Mats.add_box(root, Vector3(5.02, 0.04, 0.62), Vector3(-2.7, 0.9, -5.68), Color(0.3, 0.3, 0.32))
	Mats.add_box(root, Vector3(0.7, 0.02, 0.5), Vector3(-4.4, 0.92, -5.68), Color(0.1, 0.1, 0.1))    # cocina a gas
	_solid(root, Vector3(0.8, 1.9, 0.7), Vector3(-7.5, 0.95, -5.55), WHITE)                     # heladera
	Mats.add_box(root, Vector3(0.04, 0.5, 0.05), Vector3(-7.15, 1.2, -5.18), METAL)
	_table(root, Vector3(1.2, 0.75, 0.8), Vector3(-2.6, 0, -3.2), WOOD)
	var clock := Label3D.new()
	clock.text = "03:12"
	clock.font_size = 28
	clock.pixel_size = 0.004
	clock.modulate = Color(0.3, 1.0, 0.4)
	clock.position = Vector3(-7.5, 1.6, -5.18)
	root.add_child(clock)
	# --- Pasillo ---
	_solid(root, Vector3(0.35, 0.8, 0.7), Vector3(1.78, 0.4, 4.6), DARK_WOOD)
	# --- Dormitorio ---
	_solid(root, Vector3(2.0, 0.45, 1.6), Vector3(7.0, 0.225, 4.2), DARK_WOOD)                  # cama
	Mats.add_box(root, Vector3(1.95, 0.12, 1.55), Vector3(7.0, 0.51, 4.2), Color(0.9, 0.9, 0.88))
	Mats.add_box(root, Vector3(1.4, 0.4, 1.62), Vector3(6.7, 0.77, 4.2), Color(0.35, 0.45, 0.7))     # frazada
	Mats.add_box(root, Vector3(0.35, 0.14, 1.0), Vector3(7.7, 0.64, 4.2), WHITE)                # almohada
	_solid(root, Vector3(0.1, 1.0, 1.7), Vector3(7.95, 0.5, 4.2), DARK_WOOD)                    # respaldo
	_solid(root, Vector3(0.5, 0.55, 0.5), Vector3(7.7, 0.275, 2.9), WOOD)                       # veladores
	_solid(root, Vector3(0.5, 0.55, 0.5), Vector3(7.7, 0.275, 5.5), WOOD)
	Mats.add_cylinder(root, 0.06, 0.3, Vector3(7.7, 0.7, 5.5), METAL)
	var shade := Mats.add_cylinder(root, 0.16, 0.2, Vector3(7.7, 0.95, 5.5), Color(0.95, 0.88, 0.7))
	shade.name = "LampShade"
	_solid(root, Vector3(1.6, 2.1, 0.6), Vector3(4.8, 1.05, 5.62), DARK_WOOD)                   # ropero
	Mats.add_box(root, Vector3(0.02, 1.9, 0.02), Vector3(4.8, 1.05, 5.31), Color(0.2, 0.14, 0.09))
	_solid(root, Vector3(1.2, 0.9, 0.5), Vector3(5.0, 0.45, 0.33), WOOD)                        # cómoda
	var mirror := Mats.add_box(root, Vector3(0.8, 0.9, 0.03), Vector3(5.0, 1.55, 0.1), Color(0.55, 0.62, 0.7))
	mirror.material_override = Mats.color(Color(0.55, 0.62, 0.7), 0.05, 0.0, 0.8)
	# --- Estudio ---
	_solid(root, Vector3(0.7, 0.75, 1.4), Vector3(7.6, 0.375, -1.5), WOOD)                      # escritorio
	_solid(root, Vector3(1.2, 1.2, 0.3), Vector3(4.5, 0.6, -2.8), DARK_WOOD)                    # repisa
	# --- Baño ---
	_solid(root, Vector3(0.45, 0.45, 0.65), Vector3(7.6, 0.225, -5.6), WHITE)                   # inodoro
	_solid(root, Vector3(0.4, 0.5, 0.2), Vector3(7.6, 0.7, -5.88), WHITE)
	_solid(root, Vector3(0.6, 0.85, 0.45), Vector3(5.4, 0.425, -5.72), WHITE)                   # lavamanos
	_solid(root, Vector3(1.7, 0.55, 0.75), Vector3(6.9, 0.275, -3.45), WHITE)                   # bañera
	Mats.add_box(root, Vector3(1.5, 0.02, 0.55), Vector3(6.9, 0.555, -3.45), Color(0.6, 0.75, 0.85))

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
	for r: Rect2 in rects:
		for i in int(r.size.x / 0.2):
			var c := Color(0.52, 0.36, 0.24) if i % 2 == 0 else Color(0.47, 0.32, 0.2)
			Mats.add_box(root, Vector3(0.18, 0.006, r.size.y), Vector3(r.position.x + 0.1 + i * 0.2, FLOOR_Y + 0.006, r.get_center().y), c)
	return rects

# ---------------------------------------------------------------- el camión

static func _truck(root: Node3D, refs: Dictionary) -> void:
	var body := Color(0.92, 0.9, 0.84)
	var stripe := Color(0.95, 0.5, 0.12)
	var cx := -4.0
	# Caja de carga: piso a 0,55 m, abierta atrás (hacia la casa).
	_solid(root, Vector3(2.2, 0.1, 4.2), Vector3(cx, 0.5, 11.1), Color(0.35, 0.3, 0.25))
	_solid(root, Vector3(2.1, 0.4, 6.0), Vector3(cx, 0.25, 12.0), Color(0.15, 0.15, 0.16))
	for side in [-1.0, 1.0]:
		_solid(root, Vector3(0.08, 2.05, 4.2), Vector3(cx + side * 1.1, 1.575, 11.1), body)
		Mats.add_box(root, Vector3(0.1, 0.3, 4.2), Vector3(cx + side * 1.11, 1.2, 11.1), stripe)
	_solid(root, Vector3(2.2, 2.05, 0.08), Vector3(cx, 1.575, 13.2), body)
	_solid(root, Vector3(2.3, 0.08, 4.3), Vector3(cx, 2.64, 11.1), body)
	# Rampa desde el pasto hasta el piso de la caja.
	var ramp := _solid(root, Vector3(2.0, 0.08, 1.52), Vector3(cx, 0.26, 8.3), METAL)
	ramp.rotation_degrees.x = -21.4
	# Cabina.
	_solid(root, Vector3(2.1, 1.6, 1.8), Vector3(cx, 1.25, 14.1), body)
	var glass := Mats.add_box(root, Vector3(1.9, 0.6, 0.05), Vector3(cx, 1.65, 15.01), Color(0.2, 0.25, 0.35))
	glass.material_override = Mats.color(Color(0.2, 0.25, 0.35), 0.1, 0.2)
	for side in [-1.0, 1.0]:
		var head := Mats.add_box(root, Vector3(0.3, 0.15, 0.05), Vector3(cx + side * 0.75, 0.85, 15.01), Color(1, 0.95, 0.75))
		head.material_override = Mats.color(Color(1, 0.95, 0.75), 0.5, 1.5)
		var tail := Mats.add_box(root, Vector3(0.12, 0.2, 0.05), Vector3(cx + side * 1.0, 0.75, 8.98), Color(1, 0.1, 0.1))
		tail.material_override = Mats.color(Color(1, 0.1, 0.1), 0.5, 2.5)
	for z in [9.8, 12.6, 14.3]:
		for side in [-1.0, 1.0]:
			Mats.add_cylinder(root, 0.38, 0.25, Vector3(cx + side * 1.0, 0.38, z), Color(0.08, 0.08, 0.08), Vector3(0, 0, 90), 12)
	# Puerta del conductor: mantener E para irse.
	var door := _solid(root, Vector3(0.06, 0.9, 0.8), Vector3(cx - 1.08, 1.35, 14.1), body.darkened(0.1))
	door.set_meta("interact", "truck_leave")
	Mats.add_box(door, Vector3(0.04, 0.4, 0.7), Vector3(-0.03, 0.2, 0), Color(0.2, 0.25, 0.35))
	# Letreros.
	for side in [-1.0, 1.0]:
		var label := Label3D.new()
		label.text = "MUDANZAS TRUCHAS\n¡Nos llevamos todo!"
		label.font_size = 72
		label.pixel_size = 0.005
		label.outline_size = 12
		label.modulate = Color(0.95, 0.45, 0.1)
		label.outline_modulate = Color(0.15, 0.1, 0.05)
		label.position = Vector3(cx + side * 1.17, 1.85, 11.1)
		label.rotation_degrees.y = 90.0 * side
		root.add_child(label)
	var back := Label3D.new()
	back.text = "MUDANZAS TRUCHAS"
	back.font_size = 48
	back.pixel_size = 0.005
	back.outline_size = 10
	back.modulate = Color(0.95, 0.45, 0.1)
	back.position = Vector3(cx, 2.45, 8.96)
	back.rotation_degrees.y = 180.0
	root.add_child(back)
	# Luz adentro de la caja (para ver lo que se cargó).
	var inside := OmniLight3D.new()
	inside.light_color = Color(1.0, 0.85, 0.6)
	inside.light_energy = 0.8
	inside.omni_range = 4.5
	inside.position = Vector3(cx, 2.4, 11.5)
	root.add_child(inside)
	# Lo que toca esta zona cuenta como cargado.
	var area := Area3D.new()
	area.collision_layer = 0
	area.collision_mask = Config.L_SMALL | Config.L_BIG
	area.monitorable = false
	area.position = Vector3(cx, 1.6, 11.1)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.1, 2.1, 4.1)
	shape.shape = box
	area.add_child(shape)
	root.add_child(area)
	refs["truck_area"] = area
	# Farol de la calle.
	Mats.add_solid_box(root, Vector3(0.15, 4.5, 0.15), Vector3(1.5, 2.25, 15.8), Color(0.2, 0.2, 0.22))
	Mats.add_box(root, Vector3(0.9, 0.1, 0.12), Vector3(1.1, 4.5, 15.8), Color(0.2, 0.2, 0.22))
	var bulb := Mats.add_box(root, Vector3(0.3, 0.12, 0.25), Vector3(0.75, 4.42, 15.8), Color(1, 0.75, 0.4))
	bulb.material_override = Mats.color(Color(1, 0.75, 0.4), 0.5, 3.0)
	var street := OmniLight3D.new()
	street.light_color = Color(1.0, 0.72, 0.4)
	street.light_energy = 1.8
	street.omni_range = 14.0
	street.position = Vector3(0.75, 4.2, 15.8)
	root.add_child(street)

# ---------------------------------------------------------------- el barrio (de fondo)

static func _neighborhood(root: Node3D) -> void:
	var colors := [Color(0.55, 0.5, 0.45), Color(0.45, 0.5, 0.55), Color(0.6, 0.55, 0.45)]
	for i in 5:
		var x := -28.0 + i * 14.0
		Mats.add_box(root, Vector3(10.0, 3.0, 8.0), Vector3(x, 1.5, 30.0), colors[i % 3])
		Mats.add_box(root, Vector3(10.6, 0.5, 8.6), Vector3(x, 3.2, 30.0), Color(0.3, 0.18, 0.15))
		if i % 2 == 0:
			var w := Mats.add_box(root, Vector3(1.4, 1.0, 0.05), Vector3(x + 2.0, 1.6, 25.98), Color(1, 0.8, 0.45))
			w.material_override = Mats.color(Color(1, 0.8, 0.45), 0.5, 1.8)
