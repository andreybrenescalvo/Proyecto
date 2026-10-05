class_name LevelBuilder
extends RefCounted
## Arma la parte fija del nivel con cajas de colores (estilo low-poly, sin modelos externos):
## superficie con el campamento y el prestamista, pozo con su torre, cáscara de la mina,
## paneles del montacargas y la báscula donde se vende el mineral.
## Cuando haya arte de verdad (Kenney, Quaternius, Synty...) se reemplaza pieza por pieza.

const GROUND := Color(0.42, 0.55, 0.28)
const DIRT := Color(0.5, 0.42, 0.3)
const WOOD := Color(0.55, 0.38, 0.22)
const DARK_WOOD := Color(0.38, 0.26, 0.15)
const METAL := Color(0.32, 0.34, 0.37)
const HALF := 40.0     # la superficie va de -40 a 40

static func build(world: Node3D) -> Dictionary:
	var refs := {}
	var root := Node3D.new()
	root.name = "Level"
	world.add_child(root)
	_environment(root, refs)
	_surface(root)
	_headframe(root)
	_shaft(root)
	_mine_shell(root)
	_panel(root, Vector3(2.9, 0.0, 2.9), "top")
	_panel(root, Vector3(2.9, Config.MINE_Y, 2.9), "bottom")
	refs["sell_area"] = _sell_zone(root)
	_lender(root)
	_camp(root)
	_mine_lights(root)
	return refs

# ---------------------------------------------------------------- ambiente

static func _environment(root: Node3D, refs: Dictionary) -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.32, 0.52, 0.85)
	sky_mat.sky_horizon_color = Color(0.78, 0.8, 0.82)
	sky_mat.ground_horizon_color = Color(0.6, 0.58, 0.55)
	sky_mat.ground_bottom_color = Color(0.25, 0.22, 0.2)
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.45
	env.ambient_light_color = Color(0.32, 0.25, 0.2)
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 6.0
	env.fog_enabled = true
	env.fog_light_color = Color(0.72, 0.78, 0.85)
	env.fog_density = 0.0025
	env.glow_enabled = true
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -35, 0)
	sun.light_energy = 1.0
	sun.light_color = Color(1.0, 0.95, 0.85)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 70.0
	root.add_child(sun)
	refs["env"] = env
	refs["sun"] = sun

# ---------------------------------------------------------------- superficie

static func _surface(root: Node3D) -> void:
	# Suelo en cuatro partes, dejando el agujero del pozo (x y z entre -2 y 2).
	var side := HALF - 2.0
	Mats.add_solid_box(root, Vector3(side, 1, HALF * 2), Vector3(-2.0 - side * 0.5, -0.5, 0), GROUND)
	Mats.add_solid_box(root, Vector3(side, 1, HALF * 2), Vector3(2.0 + side * 0.5, -0.5, 0), GROUND)
	Mats.add_solid_box(root, Vector3(4, 1, side), Vector3(0, -0.5, -2.0 - side * 0.5), GROUND)
	Mats.add_solid_box(root, Vector3(4, 1, side), Vector3(0, -0.5, 2.0 + side * 0.5), GROUND)
	# Tierra pisada alrededor del pozo y camino a la báscula (solo visual).
	for patch in [[Vector3(10, 0.02, 5), Vector3(-7, 0.01, 0)], [Vector3(10, 0.02, 5), Vector3(7, 0.01, 0)],
			[Vector3(4, 0.02, 6), Vector3(0, 0.01, -5)], [Vector3(4, 0.02, 6), Vector3(0, 0.01, 5)],
			[Vector3(3, 0.02, 10), Vector3(4, 0.01, 8)]]:
		Mats.add_box(root, patch[0], patch[1], DIRT)
	# Cerco en el borde del mapa (con colisión invisible).
	for i in 4:
		var horizontal := i < 2
		var sign_dir := -1.0 if i % 2 == 0 else 1.0
		var size := Vector3(HALF * 2, 4, 0.5) if horizontal else Vector3(0.5, 4, HALF * 2)
		var pos := Vector3(0, 2, sign_dir * (HALF - 1)) if horizontal else Vector3(sign_dir * (HALF - 1), 2, 0)
		var wall := StaticBody3D.new()
		wall.collision_layer = Config.L_WORLD
		wall.position = pos
		var cs := CollisionShape3D.new()
		var b := BoxShape3D.new()
		b.size = size
		cs.shape = b
		wall.add_child(cs)
		root.add_child(wall)
		for k in 40:
			var t := -HALF + 1 + k * 2.0
			var post_pos := Vector3(t, 0.5, sign_dir * (HALF - 1)) if horizontal else Vector3(sign_dir * (HALF - 1), 0.5, t)
			Mats.add_box(root, Vector3(0.15, 1.0, 0.15), post_pos, DARK_WOOD)
		var rail := Vector3(HALF * 2, 0.1, 0.08) if horizontal else Vector3(0.08, 0.1, HALF * 2)
		Mats.add_box(root, rail, Vector3(pos.x, 0.8, pos.z), WOOD)
	# Barandas a los costados del pozo (los lados X quedan abiertos para entrar al montacargas).
	for sz in [-1.0, 1.0]:
		Mats.add_solid_box(root, Vector3(4.8, 1.1, 0.12), Vector3(0, 0.55, sz * 2.5), WOOD)
		for sx in [-2.4, 0.0, 2.4]:
			Mats.add_box(root, Vector3(0.16, 1.2, 0.16), Vector3(sx, 0.6, sz * 2.5), DARK_WOOD)
	# Árboles y piedras de decoración (posiciones fijas).
	var rng := RandomNumberGenerator.new()
	rng.seed = 1234
	for i in 45:
		var p := Vector3(rng.randf_range(-HALF + 3, HALF - 3), 0, rng.randf_range(-HALF + 3, HALF - 3))
		if absf(p.x) < 16 and absf(p.z) < 14:
			continue
		if rng.randf() < 0.7:
			_tree(root, p, rng.randf_range(0.8, 1.4))
		else:
			var s := rng.randf_range(0.6, 1.8)
			Mats.add_box(root, Vector3(s, s * 0.7, s * 0.9), p + Vector3(0, s * 0.3, 0), Color(0.5, 0.48, 0.45), Vector3(0, rng.randf() * 90, rng.randf() * 10))

static func _tree(root: Node3D, p: Vector3, s: float) -> void:
	Mats.add_cylinder(root, 0.18 * s, 1.2 * s, p + Vector3(0, 0.6 * s, 0), DARK_WOOD, Vector3.ZERO, 6)
	for k in 3:
		var cone := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.0
		mesh.bottom_radius = (1.4 - k * 0.35) * s
		mesh.height = 1.6 * s
		mesh.radial_segments = 7
		mesh.rings = 1
		cone.mesh = mesh
		cone.material_override = Mats.color(Color(0.2, 0.42 + k * 0.04, 0.22))
		cone.position = p + Vector3(0, (1.6 + k * 0.9) * s, 0)
		root.add_child(cone)

## Torre de madera sobre el pozo, con la rueda del cable.
static func _headframe(root: Node3D) -> void:
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			Mats.add_solid_box(root, Vector3(0.35, 8.0, 0.35), Vector3(sx * 2.75, 4.0, sz * 2.75), WOOD)
	for y in [3.0, 7.8]:
		for sz in [-1.0, 1.0]:
			Mats.add_box(root, Vector3(5.85, 0.3, 0.3), Vector3(0, y, sz * 2.75), DARK_WOOD)
		for sx in [-1.0, 1.0]:
			Mats.add_box(root, Vector3(0.3, 0.3, 5.85), Vector3(sx * 2.75, y, 0), DARK_WOOD)
	Mats.add_box(root, Vector3(0.4, 0.4, 5.85), Vector3(0, 8.1, 0), DARK_WOOD)
	Mats.add_cylinder(root, 0.9, 0.2, Vector3(0, 8.6, 0), METAL, Vector3(90, 0, 0), 14)
	Mats.add_cylinder(root, 0.25, 0.3, Vector3(0, 8.6, 0), Color(0.6, 0.15, 0.1), Vector3(90, 0, 0), 8)
	var sign_label := _label(root, "MINA LA ESPERANZA", Vector3(0, 6.6, 2.95), 96)
	sign_label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	sign_label.double_sided = false
	Mats.add_box(root, Vector3(4.6, 0.8, 0.1), Vector3(0, 6.6, 2.88), Color(0.3, 0.2, 0.12))

# ---------------------------------------------------------------- pozo y mina

static func _shaft(root: Node3D) -> void:
	var top := 0.0
	var bottom := Config.MINE_Y + Config.CELL_HEIGHT
	var h := top - bottom
	var mid := (top + bottom) * 0.5
	var wall_color := Color(0.36, 0.3, 0.25)
	Mats.add_solid_box(root, Vector3(0.4, h, 4.8), Vector3(2.2, mid, 0), wall_color)
	Mats.add_solid_box(root, Vector3(0.4, h, 4.8), Vector3(-2.2, mid, 0), wall_color)
	Mats.add_solid_box(root, Vector3(4.0, h, 0.4), Vector3(0, mid, 2.2), wall_color)
	Mats.add_solid_box(root, Vector3(4.0, h, 0.4), Vector3(0, mid, -2.2), wall_color)
	# Anillos de madera cada 3 metros (ayudan a ver que el montacargas se mueve).
	var y := bottom + 1.5
	while y < top - 0.5:
		for s in [-1.0, 1.0]:
			Mats.add_box(root, Vector3(0.12, 0.25, 4.0), Vector3(s * 1.97, y, 0), WOOD)
			Mats.add_box(root, Vector3(4.0, 0.25, 0.12), Vector3(0, y, s * 1.97), WOOD)
		y += 3.0

static func _mine_shell(root: Node3D) -> void:
	var lo := Config.GRID_MIN * Config.CELL_SIZE
	var hi := (Config.GRID_MAX + 1) * Config.CELL_SIZE
	var size := hi - lo
	var center := (hi + lo) * 0.5
	var floor_y := Config.MINE_Y
	var ceil_y := Config.MINE_Y + Config.CELL_HEIGHT
	Mats.add_solid_box(root, Vector3(size, 0.5, size), Vector3(center, floor_y - 0.25, center), Color(0.3, 0.26, 0.22))
	# Techo con el agujero del pozo.
	var ceil_color := Color(0.27, 0.23, 0.2)
	var side := hi - 2.0
	Mats.add_solid_box(root, Vector3(side, 0.5, size), Vector3(-2.0 - side * 0.5, ceil_y + 0.25, center), ceil_color)
	Mats.add_solid_box(root, Vector3(side, 0.5, size), Vector3(2.0 + side * 0.5, ceil_y + 0.25, center), ceil_color)
	Mats.add_solid_box(root, Vector3(4, 0.5, side), Vector3(0, ceil_y + 0.25, -2.0 - side * 0.5), ceil_color)
	Mats.add_solid_box(root, Vector3(4, 0.5, side), Vector3(0, ceil_y + 0.25, 2.0 + side * 0.5), ceil_color)
	# Marco de madera en la boca del pozo, abajo.
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			Mats.add_box(root, Vector3(0.3, Config.CELL_HEIGHT, 0.3), Vector3(sx * 2.15, floor_y + Config.CELL_HEIGHT * 0.5, sz * 2.15), WOOD)
	for sz in [-1.0, 1.0]:
		Mats.add_box(root, Vector3(4.6, 0.3, 0.3), Vector3(0, ceil_y - 0.15, sz * 2.15), DARK_WOOD)
		Mats.add_box(root, Vector3(0.3, 0.3, 4.6), Vector3(sz * 2.15, ceil_y - 0.15, 0), DARK_WOOD)
	# Rieles en el piso (decoración).
	for z in [-0.45, 0.45]:
		Mats.add_box(root, Vector3(8.0, 0.06, 0.08), Vector3(6.0, floor_y + 0.03, z - 0.5), METAL)
	for k in 8:
		Mats.add_box(root, Vector3(0.2, 0.04, 1.4), Vector3(2.5 + k, floor_y + 0.02, -0.5), DARK_WOOD)

static func _mine_lights(root: Node3D) -> void:
	for p in [Vector3(-5.6, 0, -5.6), Vector3(5.6, 0, -5.6), Vector3(-5.6, 0, 5.6), Vector3(5.6, 0, 5.6), Vector3(11.0, 0, -1.0)]:
		var pos: Vector3 = p + Vector3(0, Config.MINE_Y + 2.5, 0)
		var light := OmniLight3D.new()
		light.light_color = Color(1.0, 0.72, 0.4)
		light.light_energy = 1.6
		light.omni_range = 9.0
		light.position = pos
		root.add_child(light)
		var bulb := Mats.add_box(root, Vector3(0.18, 0.25, 0.18), pos, Color(1.0, 0.8, 0.45))
		bulb.material_override = Mats.color(Color(1.0, 0.8, 0.45), 0.5, 3.0)
		Mats.add_cylinder(root, 0.015, 0.35, pos + Vector3(0, 0.3, 0), Color(0.1, 0.1, 0.1), Vector3.ZERO, 4)

## Panel con botones para el montacargas. Arriba es rápido; abajo, lento. Los dos tienen campana.
static func _panel(root: Node3D, pos: Vector3, which: String) -> void:
	Mats.add_box(root, Vector3(0.15, 1.1, 0.15), pos + Vector3(0, 0.55, 0), DARK_WOOD)
	var board := Mats.add_box(root, Vector3(0.7, 0.55, 0.12), pos + Vector3(0, 1.3, 0), METAL)
	board.rotation_degrees = Vector3(0, 45, 0)
	# El panel mira hacia el pozo; "left" es la izquierda de quien lo mira de frente.
	var facing := Vector3(-1, 0, -1).normalized()
	var left := Vector3(1, 0, -1).normalized()
	var base := pos + Vector3(0, 1.3, 0) + facing * 0.08
	_button(root, base + left * 0.2 + Vector3(0, 0.08, 0), Color(0.2, 0.8, 0.3), "lift_up_" + which)
	_button(root, base + Vector3(0, 0.08, 0), Color(0.85, 0.2, 0.15), "lift_down_" + which)
	_button(root, base - left * 0.2 + Vector3(0, 0.08, 0), Color(0.95, 0.8, 0.2), "bell")
	var text := "VERDE sube · ROJO baja · AMARILLO campana\n" + ("(rápido)" if which == "top" else "(lento)")
	var label := _label(root, text, base + Vector3(0, 0.42, 0) + facing * 0.02, 28)
	label.rotation_degrees = Vector3(0, -135, 0)
	label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	label.double_sided = false   # de espaldas no se ve (si no, se lee al revés)

static func _button(root: Node3D, pos: Vector3, c: Color, id: String) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = Config.L_WORLD
	body.position = pos
	body.set_meta("interact", id)
	var cs := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = Vector3(0.2, 0.2, 0.2)
	cs.shape = b
	body.add_child(cs)
	var mi := Mats.add_box(body, Vector3(0.14, 0.14, 0.1), Vector3.ZERO, c)
	mi.material_override = Mats.color(c, 0.4, 0.6)
	mi.rotation_degrees = Vector3(0, 45, 0)
	root.add_child(body)

# ---------------------------------------------------------------- báscula y prestamista

## Báscula: todo trozo de mineral que quede encima se vende (también si está dentro del carrito).
static func _sell_zone(root: Node3D) -> Area3D:
	var p := Config.SELL_ZONE_POS
	Mats.add_solid_box(root, Vector3(3.2, 0.12, 3.2), p + Vector3(0, 0.06, 0), Color(0.45, 0.47, 0.5))
	for k in 4:
		Mats.add_box(root, Vector3(3.2, 0.02, 0.06), p + Vector3(0, 0.13, -1.2 + k * 0.8), Color(0.3, 0.32, 0.35))
	Mats.add_solid_box(root, Vector3(0.12, 0.7, 3.2), p + Vector3(1.6, 0.35, 0), Color(0.8, 0.7, 0.2))
	Mats.add_solid_box(root, Vector3(3.2, 0.7, 0.12), p + Vector3(0, 0.35, -1.6), Color(0.8, 0.7, 0.2))
	Mats.add_box(root, Vector3(0.15, 2.4, 0.15), p + Vector3(1.75, 1.2, -1.75), DARK_WOOD)
	Mats.add_box(root, Vector3(2.4, 0.9, 0.08), p + Vector3(1.75, 2.6, -1.75), Color(0.3, 0.2, 0.12), Vector3(0, 90, 0))
	var sign_label := _label(root, "BÁSCULA\nel mineral que dejes aquí se vende", p + Vector3(1.69, 2.6, -1.75), 40)
	sign_label.rotation_degrees = Vector3(0, -90, 0)
	sign_label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	sign_label.double_sided = false
	var area := Area3D.new()
	area.collision_layer = 0
	area.collision_mask = Config.L_SMALL
	area.position = p + Vector3(0, 1.3, 0)
	var cs := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = Vector3(3.2, 2.4, 3.2)
	cs.shape = b
	area.add_child(cs)
	root.add_child(area)
	return area

static func _lender(root: Node3D) -> void:
	var p := Config.SELL_ZONE_POS + Vector3(3.6, 0, 2.2)
	# Escritorio con una bolsa de plata.
	Mats.add_solid_box(root, Vector3(1.6, 0.8, 0.8), p + Vector3(-0.9, 0.4, 0), DARK_WOOD)
	Mats.add_box(root, Vector3(0.35, 0.3, 0.35), p + Vector3(-0.6, 0.95, 0), Color(0.75, 0.65, 0.4))
	Mats.add_box(root, Vector3(0.3, 0.06, 0.2), p + Vector3(-1.2, 0.83, 0.1), Color(0.3, 0.6, 0.3))
	# El prestamista: traje oscuro, sombrero, cara de pocos amigos.
	var npc := Node3D.new()
	npc.position = p + Vector3(0.2, 0, 0)
	npc.rotation_degrees = Vector3(0, 90, 0)
	root.add_child(npc)
	Mats.add_box(npc, Vector3(0.7, 0.85, 0.42), Vector3(0, 1.1, 0), Color(0.15, 0.15, 0.18))
	Mats.add_box(npc, Vector3(0.3, 0.7, 0.32), Vector3(-0.17, 0.35, 0), Color(0.12, 0.12, 0.14))
	Mats.add_box(npc, Vector3(0.3, 0.7, 0.32), Vector3(0.17, 0.35, 0), Color(0.12, 0.12, 0.14))
	Mats.add_box(npc, Vector3(0.12, 0.5, 0.05), Vector3(0, 1.2, -0.22), Color(0.6, 0.1, 0.1))
	Mats.add_box(npc, Vector3(0.44, 0.44, 0.42), Vector3(0, 1.75, 0), Color(0.85, 0.7, 0.58))
	Mats.add_box(npc, Vector3(0.6, 0.05, 0.6), Vector3(0, 2.0, 0), Color(0.1, 0.1, 0.1))
	Mats.add_box(npc, Vector3(0.38, 0.25, 0.38), Vector3(0, 2.14, 0), Color(0.1, 0.1, 0.1))
	Mats.add_box(npc, Vector3(0.3, 0.05, 0.04), Vector3(0, 1.62, -0.22), Color(0.25, 0.15, 0.1))
	Mats.add_cylinder(npc, 0.025, 0.2, Vector3(0.1, 1.62, -0.3), Color(0.4, 0.25, 0.15), Vector3(90, 0, 0), 5)
	var label := _label(root, "PRESTAMISTA", p + Vector3(0.2, 2.7, 0), 56)
	label.modulate = Color(1.0, 0.85, 0.4)

## Campamento: carpa y cajas.
static func _camp(root: Node3D) -> void:
	var tent := MeshInstance3D.new()
	var prism := PrismMesh.new()
	prism.size = Vector3(4.0, 2.6, 5.0)
	tent.mesh = prism
	tent.material_override = Mats.color(Color(0.62, 0.55, 0.4))
	tent.position = Vector3(-8.0, 1.3, 9.0)
	root.add_child(tent)
	Mats.add_solid_box(root, Vector3(4.0, 2.6, 5.0), Vector3(-8.0, 1.3, 9.0), Color(0, 0, 0)).get_child(1).visible = false
	Mats.add_box(root, Vector3(1.2, 1.6, 0.05), Vector3(-8.0, 0.8, 6.49), Color(0.25, 0.2, 0.15))
	for i in 3:
		Mats.add_solid_box(root, Vector3(1.0, 0.8, 1.0), Vector3(-4.5 + i * 0.3, 0.4 + i * 0.0, 11.5 - i * 1.1), WOOD.darkened(i * 0.1))
	var crate_label := _label(root, "DINAMITA", Vector3(-4.5, 0.85, 10.95), 32)
	crate_label.modulate = Color(0.9, 0.2, 0.15)
	# Fogata.
	for k in 6:
		var a := k * TAU / 6.0
		Mats.add_box(root, Vector3(0.3, 0.2, 0.3), Vector3(-3.0 + cos(a) * 0.6, 0.1, 5.0 + sin(a) * 0.6), Color(0.45, 0.43, 0.4))
	var fire := OmniLight3D.new()
	fire.light_color = Color(1.0, 0.55, 0.2)
	fire.light_energy = 1.5
	fire.omni_range = 6.0
	fire.position = Vector3(-3.0, 0.6, 5.0)
	root.add_child(fire)
	var flame := Mats.add_box(root, Vector3(0.3, 0.45, 0.3), Vector3(-3.0, 0.3, 5.0), Color(1.0, 0.5, 0.15), Vector3(0, 45, 0))
	flame.material_override = Mats.color(Color(1.0, 0.5, 0.15), 0.5, 4.0)

static func _label(root: Node3D, text: String, pos: Vector3, size: int) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font_size = size
	label.pixel_size = 0.005
	label.outline_size = 8
	label.position = pos
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	root.add_child(label)
	return label
