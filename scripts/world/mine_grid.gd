class_name MineGrid
extends Node3D
## La mina es una grilla de columnas de roca (vista desde arriba, cada celda es una columna
## de piso a techo). Solo existen como nodos las columnas que tocan un hueco: las que se
## pueden ver o golpear. El resto es solo un dato, así una mina grande no necesita miles de nodos.
##
## La mina se genera a partir de una semilla: todas las computadoras arman exactamente la misma
## mina y después solo se sincronizan los cambios (celdas rotas o derrumbadas).

const S := Config.CELL_SIZE
const H := Config.CELL_HEIGHT

var seed_value := 0
var overrides := {}        # Vector2i -> Config.Cell: cambios respecto de la mina original
var _nodes := {}           # Vector2i -> StaticBody3D
var _noise := FastNoiseLite.new()
var _noise2 := FastNoiseLite.new()
var _shape := BoxShape3D.new()

func _init() -> void:
	_shape.size = Vector3(S, H, S)

## Arma la mina desde cero. `new_overrides` permite llegar a una partida ya empezada.
func setup(new_seed: int, new_overrides := {}) -> void:
	seed_value = new_seed
	_noise.seed = new_seed
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.frequency = 0.16
	_noise2.seed = new_seed + 7
	_noise2.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise2.frequency = 0.09
	overrides = new_overrides.duplicate()
	for n in _nodes.values():
		(n as Node).free()
	_nodes.clear()
	for x in range(Config.GRID_MIN, Config.GRID_MAX + 1):
		for z in range(Config.GRID_MIN, Config.GRID_MAX + 1):
			_refresh(Vector2i(x, z))

# ---------------------------------------------------------------- consultas

static func cell_center(c: Vector2i) -> Vector3:
	return Vector3((c.x + 0.5) * S, Config.MINE_Y + H * 0.5, (c.y + 0.5) * S)

static func world_to_cell(p: Vector3) -> Vector2i:
	return Vector2i(floori(p.x / S), floori(p.z / S))

static func is_shaft(c: Vector2i) -> bool:
	return (c.x == -1 or c.x == 0) and (c.y == -1 or c.y == 0)

static func zone_of(c: Vector2i) -> Vector2i:
	return Vector2i(floori(float(c.x) / Config.ZONE_CELLS), floori(float(c.y) / Config.ZONE_CELLS))

## ¿El punto está dentro de la galería de la mina?
static func in_mine(p: Vector3) -> bool:
	var lim_min := Config.GRID_MIN * S
	var lim_max := (Config.GRID_MAX + 1) * S
	return p.y > Config.MINE_Y - 1.0 and p.y < Config.MINE_Y + H + 1.0 \
			and p.x > lim_min and p.x < lim_max and p.z > lim_min and p.z < lim_max

static func is_solid(t: int) -> bool:
	return t != Config.Cell.EMPTY

func get_type(c: Vector2i) -> int:
	if overrides.has(c):
		return overrides[c]
	return base_type(c)

## Tipo de celda de la mina original (antes de que nadie rompa nada).
func base_type(c: Vector2i) -> int:
	if c.x <= Config.GRID_MIN or c.x >= Config.GRID_MAX or c.y <= Config.GRID_MIN or c.y >= Config.GRID_MAX:
		return Config.Cell.BEDROCK
	if is_shaft(c) or _is_start_area(c):
		return Config.Cell.EMPTY
	# Más lejos del pozo = vetas más ricas (en el juego completo esto sería "más profundo").
	var d := Vector2(c.x + 0.5, c.y + 0.5).length()
	var rich := clampf((d - 4.0) / 9.0, 0.0, 1.0)
	var n := _noise.get_noise_2d(c.x, c.y)
	if n > 0.18 - rich * 0.1:
		var score := rich * 0.85 + (_noise2.get_noise_2d(c.x, c.y) + 1.0) * 0.15 + hash01(c) * 0.15
		if score > 0.92:
			return Config.Cell.GOLD
		if score > 0.68:
			return Config.Cell.SILVER
		if score > 0.38:
			return Config.Cell.IRON
		return Config.Cell.COAL
	return Config.Cell.ROCK

## Cámara inicial alrededor del pozo y dos túneles cortos para empezar.
static func _is_start_area(c: Vector2i) -> bool:
	if c.x >= -3 and c.x <= 2 and c.y >= -3 and c.y <= 2:
		return true
	if (c.y == -1 or c.y == 0) and c.x >= 3 and c.x <= 5:
		return true
	if (c.x == -1 or c.x == 0) and c.y >= -6 and c.y <= -4:
		return true
	return false

## Número pseudoaleatorio fijo por celda (0 a 1). Igual en todas las computadoras.
func hash01(c: Vector2i, salt := 0) -> float:
	var h: int = (c.x * 73856093) ^ (c.y * 19349663) ^ ((seed_value + salt) * 83492791)
	h = (h ^ (h >> 13)) * 1274126177
	h = h ^ (h >> 16)
	return float(h & 0xFFFF) / 65535.0

## Estabilidad inicial de una zona: las zonas lejanas (más ricas) son más inestables.
func initial_stability(zone: Vector2i) -> float:
	var center := Vector2((zone.x + 0.5) * Config.ZONE_CELLS, (zone.y + 0.5) * Config.ZONE_CELLS)
	var far := clampf(center.length() / 16.0, 0.0, 1.0)
	return clampf(0.95 - 0.3 * far + (hash01(zone, 99) - 0.5) * 0.1, 0.4, 1.0)

## Celdas cuyo centro está dentro del radio (medido en horizontal).
func cells_in_radius(center: Vector3, radius: float) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var c0 := world_to_cell(center)
	var r_cells := ceili(radius / S) + 1
	var flat := Vector2(center.x, center.z)
	for x in range(c0.x - r_cells, c0.x + r_cells + 1):
		for z in range(c0.y - r_cells, c0.y + r_cells + 1):
			var c := Vector2i(x, z)
			if x < Config.GRID_MIN or x > Config.GRID_MAX or z < Config.GRID_MIN or z > Config.GRID_MAX:
				continue
			var cc := cell_center(c)
			if Vector2(cc.x, cc.z).distance_to(flat) <= radius + 0.3:
				result.append(c)
	return result

func count_type(t: int) -> int:
	var n := 0
	for x in range(Config.GRID_MIN, Config.GRID_MAX + 1):
		for z in range(Config.GRID_MIN, Config.GRID_MAX + 1):
			if get_type(Vector2i(x, z)) == t:
				n += 1
	return n

## Huella de la mina actual para comprobar que todas las computadoras ven lo mismo.
func checksum() -> int:
	var total := 0
	for x in range(Config.GRID_MIN, Config.GRID_MAX + 1):
		for z in range(Config.GRID_MIN, Config.GRID_MAX + 1):
			var t := get_type(Vector2i(x, z))
			total = (total * 31 + t * 7 + x * 3 + z) % 1000000007
	return total

func node_count() -> int:
	return _nodes.size()

# ---------------------------------------------------------------- cambios

func set_cell(c: Vector2i, t: int) -> void:
	overrides[c] = t
	_refresh(c)
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		_refresh(c + d)

## Cambios como lista plana [x, z, tipo, x, z, tipo, ...] para mandarlos por red.
func serialize_overrides() -> PackedInt32Array:
	var arr := PackedInt32Array()
	for c in overrides:
		arr.append(c.x)
		arr.append(c.y)
		arr.append(overrides[c])
	return arr

static func deserialize_overrides(arr: PackedInt32Array) -> Dictionary:
	var d := {}
	for i in range(0, arr.size() - 2, 3):
		d[Vector2i(arr[i], arr[i + 1])] = arr[i + 2]
	return d

## Golpe de pico: la columna tiembla un poco.
func shake_cell(c: Vector2i) -> void:
	if not _nodes.has(c):
		return
	var body: Node3D = _nodes[c]
	var mesh: Node3D = body.get_meta("mesh")
	var tw := mesh.create_tween()
	tw.tween_property(mesh, "position", Vector3(randf_range(-0.06, 0.06), 0, randf_range(-0.06, 0.06)), 0.04)
	tw.tween_property(mesh, "position", Vector3.ZERO, 0.08)

func _refresh(c: Vector2i) -> void:
	if c.x < Config.GRID_MIN or c.x > Config.GRID_MAX or c.y < Config.GRID_MIN or c.y > Config.GRID_MAX:
		return
	var t := get_type(c)
	var want := is_solid(t) and _touches_empty(c)
	if _nodes.has(c):
		var existing: Node = _nodes[c]
		if want and int(existing.get_meta("cell_type")) == t:
			return
		existing.free()
		_nodes.erase(c)
	if want:
		_nodes[c] = _make_cell_node(c, t)

func _touches_empty(c: Vector2i) -> bool:
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var n: Vector2i = c + d
		if n.x < Config.GRID_MIN or n.x > Config.GRID_MAX or n.y < Config.GRID_MIN or n.y > Config.GRID_MAX:
			continue
		if get_type(n) == Config.Cell.EMPTY:
			return true
	return false

# ---------------------------------------------------------------- visual

func _make_cell_node(c: Vector2i, t: int) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = Config.L_WORLD
	body.collision_mask = 0
	body.position = cell_center(c)
	body.set_meta("cell", c)
	body.set_meta("cell_type", t)
	var shape := CollisionShape3D.new()
	shape.shape = _shape
	body.add_child(shape)

	var visual := Node3D.new()
	body.add_child(visual)
	body.set_meta("mesh", visual)
	var shade := hash01(c, 3)
	match t:
		Config.Cell.BEDROCK:
			Mats.add_box(visual, Vector3(S, H, S), Vector3.ZERO, Color(0.2, 0.2, 0.24).lightened(shade * 0.06))
		Config.Cell.RUBBLE:
			var rc := Color(0.5, 0.42, 0.33)
			Mats.add_box(visual, Vector3(S, H * 0.55, S), Vector3(0, -H * 0.22, 0), rc)
			Mats.add_box(visual, Vector3(1.4, 1.1, 1.3), Vector3(0.2, 0.55, -0.1), rc.darkened(0.12), Vector3(8, 25, -6))
			Mats.add_box(visual, Vector3(1.1, 1.0, 1.2), Vector3(-0.3, 1.05, 0.25), rc.lightened(0.08), Vector3(-10, 50, 12))
			Mats.add_box(visual, Vector3(1.6, 0.9, 1.0), Vector3(0.0, 1.0, -0.4), rc.darkened(0.05), Vector3(5, -20, 4))
		_:
			var rock := Color(0.38, 0.32, 0.27).lightened(shade * 0.08).darkened((1.0 - shade) * 0.08)
			Mats.add_box(visual, Vector3(S, H, S), Vector3.ZERO, rock)
			var info: Dictionary = Config.CELL_INFO[t]
			var ore: String = info["ore"]
			if ore != "":
				_add_nuggets(visual, c, Config.ORES[ore]["color"], ore)
	add_child(body)
	return body

## Pepitas de mineral en las caras de la columna para que se note la veta.
func _add_nuggets(parent: Node3D, c: Vector2i, ore_color: Color, ore: String) -> void:
	var shiny := ore == "gold" or ore == "silver"
	# El carbón brilla un poco (si no, parece un agujero negro en la pared).
	var mat := Mats.color(ore_color, 0.35 if shiny else 0.25, 0.25 if shiny else 0.0, 0.6 if shiny else 0.4)
	for i in 10:
		var face := i % 4
		var along := (hash01(c, i * 2 + 10) - 0.5) * (S - 0.6)
		var up := (hash01(c, i * 2 + 11) - 0.5) * (H - 0.6)
		var size := 0.16 + hash01(c, i + 40) * 0.18
		var out := S * 0.5 - size * 0.15
		var pos := Vector3.ZERO
		match face:
			0: pos = Vector3(out, up, along)
			1: pos = Vector3(-out, up, along)
			2: pos = Vector3(along, up, out)
			3: pos = Vector3(along, up, -out)
		var mi := MeshInstance3D.new()
		mi.mesh = Mats.box_mesh(Vector3(size, size, size))
		mi.material_override = mat
		mi.position = pos
		mi.rotation = Vector3(hash01(c, i + 60) * TAU, hash01(c, i + 70) * TAU, 0.0)
		parent.add_child(mi)
