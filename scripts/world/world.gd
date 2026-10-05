class_name World
extends Node3D
## El mundo de una partida.
##
## El anfitrión es la autoridad: simula la física, la mina, la dinamita, los derrumbes,
## el montacargas y el dinero. Los clientes mueven su propio minero, mandan pedidos
## ("quiero picar esta celda", "quiero poner dinamita acá") y reciben los resultados.
##
## Todos los mensajes de red pasan por este nodo (que tiene el mismo camino en todas las
## computadoras) con RPC propios en vez de MultiplayerSpawner. Así es simple entrar a una
## partida empezada (se manda una "foto" completa) y reiniciarla.

signal game_changed                              # dinero, deuda, día...
signal message(text: String, important: bool)    # avisos para el HUD
signal players_changed

const SYNC_INTERVAL := 0.05     # 20 actualizaciones por segundo
const BODIES_PER_PACKET := 30   # 30 objetos * 32 bytes entran en un paquete de red

var grid: MineGrid
var lift: Lift
var hud: Hud
var env: Environment
var sun: DirectionalLight3D
var sell_area: Area3D
var entities_root: Node3D
var players_root: Node3D

var entities := {}          # id -> Entity
var players := {}           # peer -> Player
var player_names := {}      # peer -> String
var player_slots := {}      # peer -> número de jugador (color)
var stability := {}         # zona (Vector2i) -> 0..1 (1 = firme). Si falta, vale la inicial.
var game := {}              # money, debt, day, time_left, strikes
var local_player: Player
var is_server := false
var debug_force_collapse := false   # para pruebas: toda explosión en la mina provoca derrumbe
var test_reports := {}              # pruebas automáticas: peer -> [checksum, entidades]

# --- solo en el anfitrión ---
var _rng := RandomNumberGenerator.new()
var _next_id := 1
var _ready_peers := {}      # peers que ya recibieron la foto inicial
var _cell_hp := {}          # golpes que le quedan a cada celda
var _pick_times := {}
var _bell_time := -10.0
var _collapses: Array[Dictionary] = []
var _sync_timer := 0.0
var _game_timer := 0.0
var _stab_timer := 0.0
var _sell_timer := 0.0
var _game_dirty := false
var _time := 0.0

# --- en cada computadora ---
var _hint_timer := 0.0

func _ready() -> void:
	is_server = multiplayer.is_server()
	var refs := LevelBuilder.build(self)
	env = refs["env"]
	sun = refs["sun"]
	sell_area = refs["sell_area"]
	grid = MineGrid.new()
	grid.name = "MineGrid"
	add_child(grid)
	lift = Lift.new()
	lift.name = "Lift"
	lift.server_side = is_server
	add_child(lift)
	entities_root = Node3D.new()
	entities_root.name = "Entities"
	add_child(entities_root)
	players_root = Node3D.new()
	players_root.name = "Players"
	add_child(players_root)
	hud = Hud.new()
	hud.name = "Hud"
	hud.world = self
	add_child(hud)
	if is_server:
		_rng.randomize()
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)
		lift.hard_stop.connect(_on_lift_hard_stop)
		_srv_new_game()
		_ready_peers[1] = true
		_add_player(1, Net.player_name, _spawn_point(0), 0)
		message.emit("Bajen a la mina, junten mineral y véndanlo en la báscula. El prestamista cobra al final de cada día.", true)
	else:
		hud.show_banner("Conectando con la mina...")
		rpc_hello.rpc_id(1, Net.player_name)

# ================================================================ consultas

func get_entity(id: int) -> Entity:
	return entities.get(id)

func get_stability(zone: Vector2i) -> float:
	if stability.has(zone):
		return stability[zone]
	return grid.initial_stability(zone)

func supports_near(pos: Vector3, radius: float) -> int:
	var n := 0
	for e: Entity in entities.values():
		if e.kind == "support":
			var d := Vector2(e.global_position.x - pos.x, e.global_position.z - pos.z).length()
			if d < radius:
				n += 1
	return n

## Probabilidad de derrumbe si se detona una carga en `pos` (la usa el HUD para el aviso).
func estimate_collapse(pos: Vector3, charge: int) -> float:
	if not MineGrid.in_mine(pos):
		return 0.0
	var zone := MineGrid.zone_of(MineGrid.world_to_cell(pos))
	return Config.collapse_chance(charge, get_stability(zone), supports_near(pos, Config.blast_radius(charge) + 3.0))

func player_position(peer: int) -> Vector3:
	if not players.has(peer):
		return Vector3.INF
	var p: Player = players[peer]
	return p.get_state()[0]

func debug_text() -> String:
	var t := "FPS %d   objetos %d   celdas visibles %d\n" % [Engine.get_frames_per_second(), entities.size(), grid.node_count()]
	if local_player:
		var pos := local_player.global_position
		t += "pos %s\n" % [pos.snapped(Vector3(0.1, 0.1, 0.1))]
		if MineGrid.in_mine(pos):
			var zone := MineGrid.zone_of(MineGrid.world_to_cell(pos))
			t += "zona %s  estabilidad %.2f  puntales cerca %d\n" % [zone, get_stability(zone), supports_near(pos, 8.0)]
			for k in range(1, Config.MAX_CHARGE + 1):
				t += "  %d cartuchos: %d%% de derrumbe\n" % [k, roundi(estimate_collapse(pos, k) * 100.0)]
	t += "montacargas %.1f m  %.1f m/s" % [lift.height, lift.speed]
	return t

# ================================================================ jugadores

func _spawn_point(slot: int) -> Vector3:
	return Config.SPAWN_POS + Vector3(slot * 1.5, 0, 0)

func _free_slot() -> int:
	for i in Net.MAX_PLAYERS:
		if not player_slots.values().has(i):
			return i
	return player_slots.size()

func _add_player(peer: int, pname: String, pos: Vector3, slot: int) -> void:
	if players.has(peer):
		return
	var p := Player.new()
	p.setup(peer, pname, peer == multiplayer.get_unique_id(), self, slot)
	players_root.add_child(p)
	p.teleport(pos)
	players[peer] = p
	player_names[peer] = pname
	player_slots[peer] = slot
	if p.is_local:
		local_player = p
		if DisplayServer.get_name() != "headless":
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	players_changed.emit()

func _remove_player(peer: int) -> void:
	if players.has(peer):
		(players[peer] as Node).queue_free()
	players.erase(peer)
	player_names.erase(peer)
	player_slots.erase(peer)
	players_changed.emit()

## El cliente avisa que ya cargó el mundo y manda su nombre.
@rpc("any_peer", "call_remote", "reliable")
func rpc_hello(pname: String) -> void:
	if not is_server:
		return
	var peer := multiplayer.get_remote_sender_id()
	pname = pname.strip_edges().substr(0, 20)
	if pname == "":
		pname = "Minero %d" % (players.size() + 1)
	var slot := _free_slot()
	var spawn := _spawn_point(slot)
	rpc_welcome.rpc_id(peer, _snapshot())
	_ready_peers[peer] = true
	_add_player(peer, pname, spawn, slot)
	_send_clients(&"rpc_add_player", [peer, pname, spawn, slot])
	_broadcast_message("%s llegó a la mina." % pname)

@rpc("authority", "call_remote", "reliable")
func rpc_welcome(snap: Dictionary) -> void:
	_apply_snapshot(snap)
	hud.hide_banner()
	message.emit("Bajen a la mina, junten mineral y véndanlo en la báscula. El prestamista cobra al final de cada día.", true)

@rpc("authority", "call_remote", "reliable")
func rpc_add_player(peer: int, pname: String, pos: Vector3, slot: int) -> void:
	_add_player(peer, pname, pos, slot)

@rpc("authority", "call_remote", "reliable")
func rpc_remove_player(peer: int) -> void:
	_remove_player(peer)

@rpc("authority", "call_remote", "reliable")
func rpc_teleport(pos: Vector3) -> void:
	if local_player:
		local_player.teleport(pos)

func _on_peer_disconnected(peer: int) -> void:
	_ready_peers.erase(peer)
	lift.set_input(peer, 0, "top")
	for e: Entity in entities.values():
		if e.held_by == peer:
			e.held_by = 0
	var pname: String = player_names.get(peer, "Alguien")
	_remove_player(peer)
	_send_clients(&"rpc_remove_player", [peer])
	_broadcast_message("%s se fue de la partida." % pname)

## Cada computadora manda la posición de su minero; el anfitrión la reparte.
func send_player_state(pos: Vector3, yaw: float, pitch: float, tool_id: int) -> void:
	if not is_server:
		rpc_player_state.rpc_id(1, pos, yaw, pitch, tool_id)

@rpc("any_peer", "call_remote", "unreliable_ordered")
func rpc_player_state(pos: Vector3, yaw: float, pitch: float, tool_id: int) -> void:
	if not is_server:
		return
	var peer := multiplayer.get_remote_sender_id()
	if players.has(peer):
		(players[peer] as Player).set_net_state(pos, yaw, pitch, tool_id)

@rpc("authority", "call_remote", "unreliable_ordered")
func rpc_players(states: Array) -> void:
	var me := multiplayer.get_unique_id()
	for s: Array in states:
		var peer: int = s[0]
		if peer != me and players.has(peer):
			(players[peer] as Player).set_net_state(s[1], s[2], s[3], s[4])

# ================================================================ foto completa

func _snapshot() -> Dictionary:
	var ents := []
	for e: Entity in entities.values():
		var info := e.info.duplicate()
		if e.kind == "dynamite":
			info["fuse"] = e.fuse
		ents.append([e.entity_id, e.kind, info, e.global_position, e.global_transform.basis.get_rotation_quaternion()])
	var pl := []
	for peer: int in players:
		pl.append([peer, player_names[peer], player_position(peer), player_slots[peer]])
	return {
		"seed": grid.seed_value,
		"cells": grid.serialize_overrides(),
		"stability": _pack_stability(),
		"game": game.duplicate(),
		"entities": ents,
		"players": pl,
		"lift": [lift.height, lift.speed],
	}

func _apply_snapshot(snap: Dictionary) -> void:
	for id: int in entities.keys():
		_destroy_entity(id)
	grid.setup(snap["seed"], MineGrid.deserialize_overrides(snap["cells"]))
	stability = _unpack_stability(snap["stability"])
	game = snap["game"]
	for d: Array in snap["entities"]:
		_create_entity(d[0], d[1], d[2], d[3], d[4])
	for d: Array in snap["players"]:
		_add_player(d[0], d[1], d[2], d[3])
	var lift_state: Array = snap["lift"]
	lift.height = lift_state[0]
	lift.set_net_state(lift_state[0], lift_state[1])
	game_changed.emit()

func _pack_stability() -> PackedFloat32Array:
	var arr := PackedFloat32Array()
	for zone: Vector2i in stability:
		arr.append(zone.x)
		arr.append(zone.y)
		arr.append(stability[zone])
	return arr

static func _unpack_stability(arr: PackedFloat32Array) -> Dictionary:
	var d := {}
	for i in range(0, arr.size() - 2, 3):
		d[Vector2i(int(arr[i]), int(arr[i + 1]))] = arr[i + 2]
	return d

@rpc("authority", "call_remote", "reliable")
func rpc_reset(snap: Dictionary) -> void:
	_apply_snapshot(snap)

# ================================================================ envío (anfitrión)

## Manda un RPC a todos los clientes listos (no al anfitrión).
func _send_clients(method: StringName, args: Array) -> void:
	for peer: int in _ready_peers:
		if peer != 1:
			callv(&"rpc_id", [peer, method] + args)

## Manda a todos los clientes y además lo ejecuta en el anfitrión.
func _send_all(method: StringName, args: Array) -> void:
	_send_clients(method, args)
	callv(method, args)

func _broadcast_message(text: String, important := false) -> void:
	_send_all(&"rpc_message", [text, important])

func _message_to(peer: int, text: String) -> void:
	if peer == multiplayer.get_unique_id():
		message.emit(text, false)
	else:
		rpc_message.rpc_id(peer, text, false)

@rpc("authority", "call_remote", "reliable")
func rpc_message(text: String, important: bool) -> void:
	message.emit(text, important)

# ================================================================ entidades

func _srv_spawn(kind: String, info: Dictionary, pos: Vector3, rot := Quaternion.IDENTITY, vel := Vector3.ZERO) -> Entity:
	if kind == "ore" and entities.size() >= Config.MAX_ENTITIES:
		return null
	var id := _next_id
	_next_id += 1
	var e := _create_entity(id, kind, info, pos, rot)
	e.linear_velocity = vel
	_send_clients(&"rpc_spawn", [id, kind, info, pos, rot])
	return e

func _srv_despawn(id: int) -> void:
	if entities.has(id):
		_destroy_entity(id)
		_send_clients(&"rpc_despawn", [id])

func _create_entity(id: int, kind: String, info: Dictionary, pos: Vector3, rot: Quaternion) -> Entity:
	if entities.has(id):
		_destroy_entity(id)
	var e := Entity.create(id, kind, info, is_server)
	e.transform = Transform3D(Basis(rot), pos)
	entities_root.add_child(e)
	entities[id] = e
	return e

func _destroy_entity(id: int) -> void:
	var e: Entity = entities.get(id)
	entities.erase(id)
	if e == null:
		return
	if local_player and local_player.holding_id == id:
		local_player.holding_id = 0
	entities_root.remove_child(e)
	e.queue_free()

@rpc("authority", "call_remote", "reliable")
func rpc_spawn(id: int, kind: String, info: Dictionary, pos: Vector3, rot: Quaternion) -> void:
	_create_entity(id, kind, info, pos, rot)

@rpc("authority", "call_remote", "reliable")
func rpc_despawn(id: int) -> void:
	_destroy_entity(id)

@rpc("authority", "call_remote", "unreliable_ordered")
func rpc_bodies(ids: PackedInt32Array, positions: PackedVector3Array, rots: PackedFloat32Array) -> void:
	for i in ids.size():
		var e: Entity = entities.get(ids[i])
		if e:
			e.set_net_transform(positions[i], Quaternion(rots[i * 4], rots[i * 4 + 1], rots[i * 4 + 2], rots[i * 4 + 3]))

# ================================================================ pedidos de los jugadores
# Cada pedido tiene tres partes: la función pública (la llama el minero local), el RPC que
# llega al anfitrión y la versión _srv_ que hace el trabajo con el número de jugador.

func request_pick(c: Vector2i) -> void:
	if is_server:
		_srv_pick(1, c)
	else:
		rpc_req_pick.rpc_id(1, c)

@rpc("any_peer", "call_remote", "reliable")
func rpc_req_pick(c: Vector2i) -> void:
	if is_server:
		_srv_pick(multiplayer.get_remote_sender_id(), c)

func _srv_pick(peer: int, c: Vector2i) -> void:
	if _time - float(_pick_times.get(peer, -10.0)) < Config.PICK_COOLDOWN * 0.8:
		return
	_pick_times[peer] = _time
	var t := grid.get_type(c)
	if t == Config.Cell.EMPTY or t == Config.Cell.BEDROCK:
		return
	if player_position(peer).distance_to(MineGrid.cell_center(c)) > Config.PICK_RANGE + 2.5:
		return
	var hp: int = int(_cell_hp.get(c, Config.CELL_INFO[t]["hp"])) - 1
	if hp <= 0:
		_srv_break_cells([c], player_position(peer), false)
	else:
		_cell_hp[c] = hp
		_send_all(&"rpc_cell_hit", [c, peer])

@rpc("authority", "call_remote", "reliable")
func rpc_cell_hit(c: Vector2i, hitter: int) -> void:
	if hitter == multiplayer.get_unique_id():
		return   # quien pica ya vio el efecto al instante
	grid.shake_cell(c)
	var pos := MineGrid.cell_center(c)
	var from := player_position(hitter)
	if from != Vector3.INF:
		var dir := from - pos
		dir.y = 0.0
		pos += dir.normalized() * Config.CELL_SIZE * 0.5 + Vector3(0, 0.3, 0)
	Sfx.play_at("pick", pos, -6.0)
	Fx.chips(self, pos, Color(0.45, 0.4, 0.35))

func request_dynamite(pos: Vector3, normal: Vector3, charge: int) -> void:
	if is_server:
		_srv_dynamite(1, pos, normal, charge)
	else:
		rpc_req_dynamite.rpc_id(1, pos, normal, charge)

@rpc("any_peer", "call_remote", "reliable")
func rpc_req_dynamite(pos: Vector3, normal: Vector3, charge: int) -> void:
	if is_server:
		_srv_dynamite(multiplayer.get_remote_sender_id(), pos, normal, charge)

func _srv_dynamite(peer: int, pos: Vector3, normal: Vector3, charge: int) -> Entity:
	charge = clampi(charge, 1, Config.MAX_CHARGE)
	var cost := charge * Config.DYNAMITE_COST
	if int(game["money"]) < cost:
		_message_to(peer, "No alcanza el dinero: %d cartuchos cuestan $%d." % [charge, cost])
		return null
	game["money"] = int(game["money"]) - cost
	_game_dirty = true
	var up := normal.normalized() if normal.length() > 0.1 else Vector3.UP
	var rot := Quaternion(Vector3.UP, up) if up.dot(Vector3.UP) > -0.99 else Quaternion(Vector3.RIGHT, PI)
	var e := _srv_spawn("dynamite", {"charge": charge, "stuck": true, "fuse": Config.FUSE_TIME}, pos, rot)
	return e

func request_support(pos: Vector3) -> void:
	if is_server:
		_srv_support(1, pos)
	else:
		rpc_req_support.rpc_id(1, pos)

@rpc("any_peer", "call_remote", "reliable")
func rpc_req_support(pos: Vector3) -> void:
	if is_server:
		_srv_support(multiplayer.get_remote_sender_id(), pos)

func _srv_support(peer: int, pos: Vector3) -> Entity:
	if not MineGrid.in_mine(pos):
		return null
	if int(game["money"]) < Config.SUPPORT_COST:
		_message_to(peer, "No alcanza el dinero: un puntal cuesta $%d." % Config.SUPPORT_COST)
		return null
	game["money"] = int(game["money"]) - Config.SUPPORT_COST
	_game_dirty = true
	var floor_pos := Vector3(pos.x, Config.MINE_Y, pos.z)
	var e := _srv_spawn("support", {}, floor_pos, Quaternion(Vector3.UP, _rng.randf() * TAU))
	_send_all(&"rpc_sound", ["thud", floor_pos + Vector3(0, 1, 0), 0.0])
	return e

func request_grab(id: int) -> void:
	if is_server:
		_srv_grab(1, id)
	else:
		rpc_req_grab.rpc_id(1, id)

@rpc("any_peer", "call_remote", "reliable")
func rpc_req_grab(id: int) -> void:
	if is_server:
		_srv_grab(multiplayer.get_remote_sender_id(), id)

func _srv_grab(peer: int, id: int) -> bool:
	var e: Entity = entities.get(id)
	var ok := e != null and e.is_grabbable() and e.held_by == 0 \
			and player_position(peer).distance_to(e.global_position) < Config.INTERACT_RANGE + 2.0
	if ok:
		for other: Entity in entities.values():
			if other.held_by == peer:
				other.held_by = 0
		e.held_by = peer
		e.hold_target = e.global_position
		e.hold_stamp = _time
		if e.freeze:
			e.freeze = false   # dinamita pegada a la pared: se despega
		e.sleeping = false
	if peer == multiplayer.get_unique_id():
		rpc_grab_result(id, ok)
	else:
		rpc_grab_result.rpc_id(peer, id, ok)
	return ok

@rpc("authority", "call_remote", "reliable")
func rpc_grab_result(id: int, ok: bool) -> void:
	if ok and local_player:
		local_player.holding_id = id

@rpc("authority", "call_remote", "reliable")
func rpc_released(id: int) -> void:
	if local_player and local_player.holding_id == id:
		local_player.holding_id = 0

func send_hold_target(id: int, target: Vector3) -> void:
	if is_server:
		_srv_hold(1, id, target)
	else:
		rpc_hold.rpc_id(1, id, target)

@rpc("any_peer", "call_remote", "unreliable_ordered")
func rpc_hold(id: int, target: Vector3) -> void:
	if is_server:
		_srv_hold(multiplayer.get_remote_sender_id(), id, target)

func _srv_hold(peer: int, id: int, target: Vector3) -> void:
	var e: Entity = entities.get(id)
	if e and e.held_by == peer:
		e.hold_target = target
		e.hold_stamp = _time

func request_release(id: int, throw_dir: Vector3) -> void:
	if is_server:
		_srv_release(1, id, throw_dir)
	else:
		rpc_req_release.rpc_id(1, id, throw_dir)

@rpc("any_peer", "call_remote", "reliable")
func rpc_req_release(id: int, throw_dir: Vector3) -> void:
	if is_server:
		_srv_release(multiplayer.get_remote_sender_id(), id, throw_dir)

func _srv_release(peer: int, id: int, throw_dir: Vector3) -> void:
	var e: Entity = entities.get(id)
	if e == null or e.held_by != peer:
		return
	e.held_by = 0
	if throw_dir.length() > 0.1 and not e.is_heavy():
		e.linear_velocity = throw_dir.normalized() * Config.THROW_SPEED + Vector3(0, 1.5, 0)
		e.angular_velocity = Vector3(_rng.randf_range(-6, 6), _rng.randf_range(-6, 6), _rng.randf_range(-6, 6))

func send_lift_input(dir: int, panel: String) -> void:
	if is_server:
		lift.set_input(1, dir, panel)
	else:
		rpc_lift_input.rpc_id(1, dir, panel)

@rpc("any_peer", "call_remote", "unreliable_ordered")
func rpc_lift_input(dir: int, panel: String) -> void:
	if is_server:
		lift.set_input(multiplayer.get_remote_sender_id(), dir, panel)

@rpc("authority", "call_remote", "unreliable_ordered")
func rpc_lift(h: float, s: float) -> void:
	lift.set_net_state(h, s)

func request_bell() -> void:
	if is_server:
		_srv_bell()
	else:
		rpc_req_bell.rpc_id(1)

@rpc("any_peer", "call_remote", "reliable")
func rpc_req_bell() -> void:
	if is_server:
		_srv_bell()

func _srv_bell() -> void:
	if _time - _bell_time < 1.0:
		return
	_bell_time = _time
	_send_all(&"rpc_bell", [])

@rpc("authority", "call_remote", "reliable")
func rpc_bell() -> void:
	Sfx.play_at("bell", Vector3(2.9, 1.5, 2.9), 4.0)
	Sfx.play_at("bell", Vector3(2.9, Config.MINE_Y + 1.5, 2.9), 4.0)
	message.emit("¡Campana! Alguien llama al montacargas.", false)

@rpc("authority", "call_remote", "reliable")
func rpc_sound(sound: String, pos: Vector3, volume_db: float) -> void:
	Sfx.play_at(sound, pos, volume_db)

# ================================================================ celdas, explosiones, derrumbes

## Rompe celdas y suelta el mineral. `from` es de dónde vino el golpe (para lanzar los trozos).
func _srv_break_cells(cells: Array, from: Vector3, blast: bool) -> void:
	var changes := PackedInt32Array()
	for c: Vector2i in cells:
		var t := grid.get_type(c)
		if t == Config.Cell.EMPTY or t == Config.Cell.BEDROCK:
			continue
		grid.set_cell(c, Config.Cell.EMPTY)
		_cell_hp.erase(c)
		changes.append_array([c.x, c.y, Config.Cell.EMPTY])
		var info: Dictionary = Config.CELL_INFO[t]
		var ore: String = info["ore"]
		if ore == "":
			continue
		for i in int(info["drops"]):
			var p := MineGrid.cell_center(c) + Vector3(_rng.randf_range(-0.6, 0.6), _rng.randf_range(-0.9, 0.5), _rng.randf_range(-0.6, 0.6))
			var out := p - from
			out.y = 0.0
			out = out.normalized() if out.length() > 0.01 else Vector3.ZERO
			var speed := _rng.randf_range(2.0, 5.0) if blast else 1.0
			var vel := out * speed + Vector3(0, _rng.randf_range(1.0, 3.0), 0)
			var rot := Quaternion.from_euler(Vector3(_rng.randf() * TAU, _rng.randf() * TAU, 0))
			_srv_spawn("ore", {"ore": ore}, p, rot, vel)
	if changes.size() > 0:
		_send_clients(&"rpc_cells", [changes, blast])
		if not blast:
			_cells_fx(changes)

@rpc("authority", "call_remote", "reliable")
func rpc_cells(changes: PackedInt32Array, blast: bool) -> void:
	for i in range(0, changes.size() - 2, 3):
		grid.set_cell(Vector2i(changes[i], changes[i + 1]), changes[i + 2])
	if not blast:
		_cells_fx(changes)

func _cells_fx(changes: PackedInt32Array) -> void:
	for i in range(0, changes.size() - 2, 3):
		var pos := MineGrid.cell_center(Vector2i(changes[i], changes[i + 1]))
		Sfx.play_at("thud", pos, 2.0)
		Fx.chips(self, pos, Color(0.45, 0.4, 0.35))
		Fx.dust(self, pos + Vector3(0, 1.2, 0), 10)

func _srv_explode(e: Entity) -> void:
	var pos := e.global_position
	var charge := clampi(int(e.info.get("charge", 1)), 1, Config.MAX_CHARGE)
	_srv_despawn(e.entity_id)
	var radius := Config.blast_radius(charge)
	var in_mine := MineGrid.in_mine(pos)
	if in_mine:
		var cells := []
		for c in grid.cells_in_radius(pos, radius):
			if not MineGrid.is_shaft(c):
				cells.append(c)
		_srv_break_cells(cells, pos, true)
	# Empujar todo lo que esté cerca (y encender la dinamita vecina: reacción en cadena).
	for other: Entity in entities.values().duplicate():
		var d := other.global_position.distance_to(pos)
		if d > radius * 1.5:
			continue
		if other.kind == "support":
			if d < 2.2:
				_srv_despawn(other.entity_id)
			continue
		if other.kind == "dynamite":
			other.fuse = minf(other.fuse, _rng.randf_range(0.15, 0.4))
			other.freeze = false
		if other.freeze:
			continue
		var dir := (other.global_position - pos + Vector3(0, 0.6, 0)).normalized()
		var force := (1.0 - d / (radius * 1.5)) * (6.0 + charge * 2.0)
		var scale_factor := 0.35 if other.is_heavy() else 1.0
		other.apply_central_impulse(dir * force * other.mass * scale_factor)
		other.apply_torque_impulse(Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1), _rng.randf_range(-1, 1)) * other.mass * 0.3)
	# Mineros cerca: salen volando (y si estaban muy cerca, quedan aturdidos).
	for peer: int in players:
		var ppos := player_position(peer)
		var d := ppos.distance_to(pos)
		if d > radius * 1.8:
			continue
		var dir := ppos - pos
		dir.y = maxf(dir.y, 0.0)
		dir = (dir.normalized() + Vector3.UP * 0.6).normalized()
		var strength := (1.0 - d / (radius * 1.8)) * (8.0 + charge * 3.0)
		_srv_knockback(peer, dir * strength, 1.2 if d < radius * 0.6 else 0.0)
	_send_all(&"rpc_explosion", [pos, charge])
	if in_mine:
		_srv_after_blast(pos, charge, radius)

@rpc("authority", "call_remote", "reliable")
func rpc_explosion(pos: Vector3, charge: int) -> void:
	Fx.explosion(self, pos, charge)
	Sfx.play_at("boom", pos, 4.0 + charge * 2.0, 1.1 - charge * 0.08)
	if local_player:
		var d := local_player.global_position.distance_to(pos)
		local_player.add_shake(clampf(1.6 - d / 25.0, 0.0, 1.6))

func _srv_knockback(peer: int, impulse: Vector3, stun_time: float) -> void:
	if peer == multiplayer.get_unique_id():
		rpc_knockback(impulse, stun_time)
	else:
		rpc_knockback.rpc_id(peer, impulse, stun_time)

@rpc("authority", "call_remote", "reliable")
func rpc_knockback(impulse: Vector3, stun_time: float) -> void:
	if local_player:
		local_player.apply_knockback(impulse, stun_time)

## Después de cada explosión en la mina: la zona pierde estabilidad y puede venirse abajo.
func _srv_after_blast(pos: Vector3, charge: int, radius: float) -> void:
	var zone := MineGrid.zone_of(MineGrid.world_to_cell(pos))
	var p := estimate_collapse(pos, charge)
	_srv_set_stability(zone, get_stability(zone) - Config.STABILITY_LOSS[charge])
	if debug_force_collapse or _rng.randf() < p:
		var r := radius + 2.0
		_collapses.append({"pos": pos, "radius": r, "t": Config.COLLAPSE_WARNING})
		_send_all(&"rpc_collapse_warning", [pos, r])

func _srv_set_stability(zone: Vector2i, value: float) -> void:
	stability[zone] = clampf(value, 0.0, 1.0)
	_send_clients(&"rpc_stability", [zone, stability[zone]])

@rpc("authority", "call_remote", "reliable")
func rpc_stability(zone: Vector2i, value: float) -> void:
	stability[zone] = value

@rpc("authority", "call_remote", "reliable")
func rpc_stability_all(packed: PackedFloat32Array) -> void:
	stability = _unpack_stability(packed)

@rpc("authority", "call_remote", "reliable")
func rpc_collapse_warning(pos: Vector3, radius: float) -> void:
	Sfx.play_at("creak", pos + Vector3(0, 2, 0), 6.0, 0.8)
	Sfx.play_at("rumble", pos, 2.0)
	for i in 6:
		Fx.dust(self, pos + Vector3(randf_range(-radius, radius) * 0.6, 2.8, randf_range(-radius, radius) * 0.6), 24)
	if local_player:
		var d := local_player.global_position.distance_to(pos)
		if d < radius + 6.0:
			local_player.add_shake(0.6)
			message.emit("¡Crujidos en el techo! ¡Salgan de ahí!", true)

func _srv_collapse(pos: Vector3, radius: float) -> void:
	# Celdas protegidas: donde hay mineros, el carrito y el pozo.
	var protected: Array[Vector2i] = []
	for peer: int in players:
		protected.append(MineGrid.world_to_cell(player_position(peer)))
	for e: Entity in entities.values():
		if e.kind == "cart":
			protected.append(MineGrid.world_to_cell(e.global_position))
	var changes := PackedInt32Array()
	var buried_cells: Array[Vector2i] = []
	for c in grid.cells_in_radius(pos, radius):
		if MineGrid.is_shaft(c) or grid.get_type(c) != Config.Cell.EMPTY or protected.has(c):
			continue
		if _rng.randf() < 0.6:
			grid.set_cell(c, Config.Cell.RUBBLE)
			_cell_hp.erase(c)
			changes.append_array([c.x, c.y, Config.Cell.RUBBLE])
			buried_cells.append(c)
	# Lo que quedó bajo los escombros se pierde.
	var lost := 0
	for e: Entity in entities.values().duplicate():
		if (e.kind == "ore" or e.kind == "dynamite") and MineGrid.in_mine(e.global_position) \
				and buried_cells.has(MineGrid.world_to_cell(e.global_position)):
			lost += e.ore_value()
			_srv_despawn(e.entity_id)
	# A los mineros que estaban cerca les cae algo encima.
	for peer: int in players:
		var ppos := player_position(peer)
		if MineGrid.in_mine(ppos) and Vector2(ppos.x - pos.x, ppos.z - pos.z).length() < radius:
			_srv_knockback(peer, Vector3(_rng.randf_range(-3, 3), -2.0, _rng.randf_range(-3, 3)), 2.0)
	if changes.size() > 0:
		_send_clients(&"rpc_cells", [changes, true])
	var zone := MineGrid.zone_of(MineGrid.world_to_cell(pos))
	_srv_set_stability(zone, get_stability(zone) + 0.35)   # el techo ya se asentó
	_send_all(&"rpc_collapse", [pos, radius])
	var text := "¡DERRUMBE! Quedaron %d tramos tapados de escombros." % buried_cells.size()
	if lost > 0:
		text += " Se perdieron $%d en mineral." % lost
	_broadcast_message(text, true)

@rpc("authority", "call_remote", "reliable")
func rpc_collapse(pos: Vector3, radius: float) -> void:
	Sfx.play_at("boom", pos, 2.0, 0.6)
	Sfx.play_at("rumble", pos, 6.0, 0.8)
	Fx.falling_rocks(self, pos, radius * 0.6, 22)
	for i in 8:
		Fx.dust(self, pos + Vector3(randf_range(-radius, radius) * 0.7, 2.8, randf_range(-radius, radius) * 0.7), 30)
	if local_player:
		var d := local_player.global_position.distance_to(pos)
		local_player.add_shake(clampf(2.0 - d / 15.0, 0.2, 2.0))

# ================================================================ montacargas

## Frenazo del montacargas: lo que va encima salta (y el carrito se descarrila).
func _on_lift_hard_stop(spd: float) -> void:
	var cart_hit := false
	var power := absf(spd)
	for e: Entity in entities.values():
		if e.freeze or not lift.is_on_platform(e.global_position):
			continue
		var up := _rng.randf_range(0.4, 1.0) if spd > 0.0 else 0.2
		var imp := Vector3(_rng.randf_range(-1, 1), up, _rng.randf_range(-1, 1)) * power * 0.55 * e.mass
		e.apply_central_impulse(imp)
		e.apply_torque_impulse(Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1), _rng.randf_range(-1, 1)) * e.mass * 0.6)
		if e.kind == "cart":
			cart_hit = true
	for peer: int in players:
		if lift.is_on_platform(player_position(peer)):
			_srv_knockback(peer, Vector3(_rng.randf_range(-1, 1), 0.5, _rng.randf_range(-1, 1)) * power * 0.6, 0.5)
	_send_all(&"rpc_lift_jolt", [cart_hit])

@rpc("authority", "call_remote", "reliable")
func rpc_lift_jolt(cart_hit: bool) -> void:
	var pos := Vector3(0, lift.height + 0.5, 0)
	Sfx.play_at("thud", pos, 8.0, 0.7)
	Fx.dust(self, pos, 20)
	if cart_hit:
		message.emit("¡Frenazo! El carrito se descarriló.", true)

# ================================================================ dinero y prestamista

func _srv_new_game() -> void:
	for id: int in entities.keys():
		_destroy_entity(id)
	_cell_hp.clear()
	stability.clear()
	_collapses.clear()
	grid.setup(_rng.randi_range(1, 999999))
	game = {
		"money": Config.START_MONEY,
		"debt": Config.START_DEBT,
		"day": 1,
		"time_left": Config.DAY_LENGTH,
		"strikes": 0,
	}
	# El carrito empieza arriba, sobre el montacargas.
	_srv_spawn("cart", {}, Vector3(0, lift.height + 0.05, 0))
	_game_dirty = true

func _srv_restart() -> void:
	_srv_new_game()
	_send_clients(&"rpc_reset", [_snapshot()])
	for peer: int in players:
		var pos := _spawn_point(int(player_slots[peer]))
		if peer == multiplayer.get_unique_id():
			rpc_teleport(pos)
		else:
			rpc_teleport.rpc_id(peer, pos)
	game_changed.emit()

func _srv_sell() -> void:
	var total := 0
	var count := 0
	var where := Vector3.ZERO
	for body in sell_area.get_overlapping_bodies():
		var e := body as Entity
		if e == null or e.kind != "ore" or e.held_by != 0 or not entities.has(e.entity_id):
			continue
		total += e.ore_value()
		count += 1
		where += e.global_position
		_srv_despawn(e.entity_id)
	if count == 0:
		return
	game["money"] = int(game["money"]) + total
	_game_dirty = true
	_send_all(&"rpc_sold", [where / count, total, count])

@rpc("authority", "call_remote", "reliable")
func rpc_sold(pos: Vector3, total: int, count: int) -> void:
	Sfx.play_at("coin", pos, 0.0)
	Fx.floating_text(self, pos + Vector3(0, 0.8, 0), "+$%d" % total)
	message.emit("Vendieron %d trozo%s de mineral por $%d." % [count, "" if count == 1 else "s", total], false)

func _srv_end_day() -> void:
	var day: int = game["day"]
	var quota := Config.quota_for_day(day)
	var debt: int = game["debt"]
	var due := mini(quota, debt)
	var paid := mini(int(game["money"]), due)
	game["money"] = int(game["money"]) - paid
	game["debt"] = debt - paid
	if int(game["debt"]) <= 0:
		_broadcast_message("¡Deuda saldada! El prestamista se fue refunfuñando. Pueden seguir minando para ustedes.", true)
	elif paid < due:
		var missing := due - paid
		var fee := ceili(missing * 0.5)
		game["debt"] = int(game["debt"]) + fee
		game["strikes"] = int(game["strikes"]) + 1
		_broadcast_message("Fin del día %d: el prestamista cobró $%d y faltaron $%d. Recargo de $%d. Advertencia %d de %d." \
				% [day, paid, missing, fee, game["strikes"], Config.MAX_STRIKES], true)
	else:
		_broadcast_message("Fin del día %d: el prestamista cobró la cuota de $%d." % [day, paid], true)
	if int(game["strikes"]) >= Config.MAX_STRIKES:
		_broadcast_message("El prestamista se quedó con la mina... Empiezan de nuevo.", true)
		_srv_restart()
		return
	game["day"] = day + 1
	game["time_left"] = Config.DAY_LENGTH
	_game_dirty = true

@rpc("authority", "call_remote", "reliable")
func rpc_game(state: Dictionary) -> void:
	game = state
	game_changed.emit()

# ================================================================ bucle principal

func _physics_process(delta: float) -> void:
	_time += delta
	if is_server:
		_srv_tick(delta)

func _srv_tick(delta: float) -> void:
	# Dinamita: explotar la que se quedó sin mecha.
	var to_explode: Array[Entity] = []
	for e: Entity in entities.values():
		if e.kind == "dynamite" and e.fuse <= 0.0:
			to_explode.append(e)
		elif e.global_position.y < Config.MINE_Y - 20.0:
			to_explode.append(e)   # se cayó del mundo: se elimina abajo
	for e in to_explode:
		if not entities.has(e.entity_id):
			continue
		if e.kind == "dynamite" and e.global_position.y > Config.MINE_Y - 20.0:
			_srv_explode(e)
		else:
			_srv_despawn(e.entity_id)
	# Objetos agarrados.
	for e: Entity in entities.values():
		if e.held_by == 0:
			continue
		var holder := player_position(e.held_by)
		if _time - e.hold_stamp > 0.6 or holder.distance_to(e.global_position) > 5.0:
			var peer := e.held_by
			e.held_by = 0
			if peer == multiplayer.get_unique_id():
				rpc_released(e.entity_id)
			elif _ready_peers.has(peer):
				rpc_released.rpc_id(peer, e.entity_id)
		else:
			e.server_hold_step(delta)
	# Derrumbes anunciados.
	for i in range(_collapses.size() - 1, -1, -1):
		var col := _collapses[i]
		col["t"] = float(col["t"]) - delta
		if float(col["t"]) <= 0.0:
			_collapses.remove_at(i)
			_srv_collapse(col["pos"], col["radius"])
	# Báscula.
	_sell_timer -= delta
	if _sell_timer <= 0.0:
		_sell_timer = 0.25
		_srv_sell()
	# Reloj del día.
	game["time_left"] = float(game["time_left"]) - delta
	if float(game["time_left"]) <= 0.0:
		_srv_end_day()
	_game_timer -= delta
	if _game_dirty or _game_timer <= 0.0:
		_game_timer = 1.0
		_game_dirty = false
		_send_clients(&"rpc_game", [game])
		game_changed.emit()
	# El techo se asienta de a poco.
	_stab_timer -= delta
	if _stab_timer <= 0.0:
		_stab_timer = 5.0
		for zone: Vector2i in stability.keys():
			stability[zone] = minf(float(stability[zone]) + Config.STABILITY_RECOVERY * 5.0, 1.0)
		_send_clients(&"rpc_stability_all", [_pack_stability()])
	# Sincronizar física, montacargas y mineros.
	_sync_timer -= delta
	if _sync_timer <= 0.0:
		_sync_timer = SYNC_INTERVAL
		_srv_sync()

func _srv_sync() -> void:
	if _ready_peers.size() <= 1:
		for e: Entity in entities.values():
			e.mark_sent()
		return
	var ids := PackedInt32Array()
	var positions := PackedVector3Array()
	var rots := PackedFloat32Array()
	for e: Entity in entities.values():
		if e.needs_sync(SYNC_INTERVAL):
			var q := e.global_transform.basis.get_rotation_quaternion()
			ids.append(e.entity_id)
			positions.append(e.global_position)
			rots.append_array([q.x, q.y, q.z, q.w])
			e.mark_sent()
			# Paquetes chicos: si pasan el MTU de la red se pierden mucho más.
			if ids.size() == BODIES_PER_PACKET:
				_send_clients(&"rpc_bodies", [ids, positions, rots])
				ids = PackedInt32Array()
				positions = PackedVector3Array()
				rots = PackedFloat32Array()
	if ids.size() > 0:
		_send_clients(&"rpc_bodies", [ids, positions, rots])
	_send_clients(&"rpc_lift", [lift.height, lift.speed])
	var states := []
	for peer: int in players:
		var s: Array = (players[peer] as Player).get_state()
		states.append([peer, s[0], s[1], s[2], s[3]])
	_send_clients(&"rpc_players", [states])

func _process(delta: float) -> void:
	_update_ambience(delta)
	_update_hints(delta)

## Arriba hay sol; abajo, oscuridad y niebla (solo afecta a lo que ve cada uno).
func _update_ambience(delta: float) -> void:
	if local_player == null:
		return
	var depth := clampf((-local_player.global_position.y - 3.0) / 10.0, 0.0, 1.0)
	var k := clampf(delta * 3.0, 0.0, 1.0)
	# Bajo tierra el cielo no ilumina ni se refleja (si no, todo queda azulado).
	var underground := depth > 0.5
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR if underground else Environment.AMBIENT_SOURCE_SKY
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED if underground else Environment.REFLECTION_SOURCE_BG
	env.ambient_light_energy = lerpf(env.ambient_light_energy, lerpf(0.45, 0.7, depth), k)
	env.fog_density = lerpf(env.fog_density, lerpf(0.0025, 0.03, depth), k)
	env.fog_light_color = env.fog_light_color.lerp(Color(0.72, 0.78, 0.85).lerp(Color(0.07, 0.055, 0.045), depth), k)
	sun.light_energy = lerpf(sun.light_energy, lerpf(1.0, 0.0, depth), k)

## Pistas de inestabilidad: polvo que cae y crujidos. Más seguido cuanto peor está la zona.
func _update_hints(delta: float) -> void:
	if local_player == null:
		return
	_hint_timer -= delta
	if _hint_timer > 0.0:
		return
	_hint_timer = 0.5
	var pos := local_player.global_position
	if not MineGrid.in_mine(pos):
		return
	var instability := 1.0 - get_stability(MineGrid.zone_of(MineGrid.world_to_cell(pos)))
	if instability > 0.2 and randf() < (instability - 0.15) * 0.9:
		var off := Vector3(randf_range(-3, 3), 0, randf_range(-3, 3))
		Fx.dust(self, Vector3(pos.x, Config.MINE_Y + Config.CELL_HEIGHT - 0.1, pos.z) + off, int(6 + instability * 20))
	if instability > 0.4 and randf() < (instability - 0.35) * 0.4:
		Sfx.play_at("creak", pos + Vector3(randf_range(-4, 4), 2.5, randf_range(-4, 4)), -6.0 + instability * 6.0, randf_range(0.7, 1.2))
		local_player.add_shake(0.08 + instability * 0.15)

# ================================================================ pruebas automáticas

@rpc("authority", "call_remote", "reliable")
func rpc_test_request() -> void:
	send_test_report()

func send_test_report() -> void:
	rpc_test_report.rpc_id(1, grid.checksum(), entities.size())

@rpc("any_peer", "call_remote", "reliable")
func rpc_test_report(checksum: int, entity_count: int) -> void:
	if is_server:
		test_reports[multiplayer.get_remote_sender_id()] = [checksum, entity_count]
