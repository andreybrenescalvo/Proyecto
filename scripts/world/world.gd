class_name World
extends Node3D
## El mundo de una partida: una noche robando la casa de Don Ramón.
##
## El anfitrión es la autoridad: simula la física, el dueño, las puertas, el ruido, el camión
## y la policía. Los clientes mueven su propio jugador, mandan su nivel de voz y pedidos
## ("quiero agarrar esto", "abrir esta puerta") y reciben los resultados.
##
## Todos los mensajes de red pasan por este nodo (que tiene el mismo camino en todas las
## computadoras) con RPC propios en vez de MultiplayerSpawner. Así es simple entrar a una
## partida empezada (se manda una "foto" completa) y empezar otra noche.

signal game_changed                              # tiempo, botín, policía...
signal message(text: String, important: bool)    # avisos para el HUD
signal players_changed
signal night_finished(results: Dictionary)
signal night_started

const SYNC_INTERVAL := 0.05     # 20 actualizaciones por segundo
const BODIES_PER_PACKET := 30   # 30 objetos * 32 bytes entran en un paquete de red
const DOORS_OPEN_AT_START := [false, false, false, true, false]

var hud: Hud
var env: Environment
var moon: DirectionalLight3D
var truck: Truck
var truck_area: Area3D
var bedroom_lamp: OmniLight3D
var homeowner: HouseOwner
var house_refs: Dictionary     # lo que armó HouseBuilder (para cambiar el estilo de la casa)
var _style_shown := -1
var doors: Array[Door] = []
var boards: Array = []
var item_spawns: Array = []
var entities_root: Node3D
var players_root: Node3D

var entities := {}          # id -> Entity
var players := {}           # peer -> Player
var player_names := {}      # peer -> String
var player_slots := {}      # peer -> número de jugador (color)
var game := {}              # night, time_left, quota, truck, police, over, bank
var results := {}           # resultados de la última noche (vacío mientras se juega)
var local_player: Player
var is_server := false
var test_reports := {}      # pruebas automáticas: peer -> informe
var debug_noises: Array = []  # (anfitrión) últimos ruidos que oyó el dueño, para F3
var cargo_hits := 0         # (anfitrión) golpes de lo que va en la caja (para las pruebas)
var jolts: Array[float] = []  # (anfitrión) fuerza de los sacudones de esta noche (para las pruebas)

# --- solo en el anfitrión ---
var _rng := RandomNumberGenerator.new()
var _next_id := 1
var _ready_peers := {}      # peers que ya recibieron la foto inicial
var _time := 0.0
var _sync_timer := 0.0
var _game_timer := 0.0
var _truck_timer := 0.0
var _game_dirty := false
var _step_timers := {}      # peer -> segundos hasta el próximo paso
var _on_board := {}         # peer -> tabla que está pisando (-1 = ninguna)
var _stats := {}            # peer -> {noise, broken, loot, caught, wakes}
var _scrape_timers := {}    # entidad -> segundos hasta el próximo chirrido de arrastre
var _impact_times := {}     # entidad -> último golpe (para no repetir el ruido)
var _loaded := {}           # entidad que está en el camión -> peer al que se le acreditó
var _eject_timers := {}     # peer -> segundos que le quedan "a salvo" después de que lo echaron
var _engine_timer := 0.0

# --- en cada computadora ---
var _siren: AudioStreamPlayer3D
var _siren_light: OmniLight3D

func _ready() -> void:
	is_server = multiplayer.is_server()
	var refs := HouseBuilder.build(self)
	house_refs = refs
	env = refs["env"]
	moon = refs["moon"]
	truck = refs["truck"]
	truck.setup(is_server)
	for x: float in HouseBuilder.SPEED_BUMPS_X:
		var size := HouseBuilder.SPEED_BUMP_SIZE
		truck.bumps.append(Rect2(x - size.x * 0.5, 21.0 - size.z * 0.5, size.x, size.z))
	if is_server:
		truck.jolted.connect(_srv_on_truck_jolt)
	truck_area = refs["truck_area"]
	bedroom_lamp = refs["bedroom_lamp"]
	boards = refs["boards"]
	item_spawns = refs["items"]
	for d: Door in refs["doors"]:
		doors.append(d)
	_show_style(0)
	homeowner = HouseOwner.new()
	homeowner.setup(self, is_server)
	add_child(homeowner)
	entities_root = Node3D.new()
	entities_root.name = "Entities"
	add_child(entities_root)
	players_root = Node3D.new()
	players_root.name = "Players"
	add_child(players_root)
	_build_siren()
	hud = Hud.new()
	hud.name = "Hud"
	hud.world = self
	add_child(hud)
	if is_server:
		_rng.randomize()
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)
		homeowner.woke_up.connect(_on_owner_woke)
		homeowner.spotted.connect(_on_owner_spotted)
		homeowner.caught.connect(_on_owner_caught)
		_ready_peers[1] = true
		_srv_new_night(1, 0)
		_add_player(1, Net.player_name, HouseBuilder.SPAWNS[0], 0)
		message.emit(_intro_text(), true)
	else:
		hud.show_banner("Llegando a la casa...")
		rpc_hello.rpc_id(1, Net.player_name)

## Cada noche la casa tiene otro estilo (fachada, techo, pinturas, pisos). La semilla viaja en `game`.
func _show_style(seed: int) -> void:
	if seed == _style_shown:
		return
	_style_shown = seed
	HouseBuilder.apply_style(house_refs, seed)

func _intro_text() -> String:
	return "Noche %d: la casa de Don Ramón. Carguen en el camión al menos $%d antes de que amanezca. ¡Y no lo despierten!" \
			% [int(game.get("night", 1)), int(game.get("quota", 0))]

func _build_siren() -> void:
	var holder := Node3D.new()
	holder.position = Vector3(-30.0, 1.5, 21.0)
	add_child(holder)
	_siren = Sfx.make_loop("siren", holder, -30.0)
	_siren.unit_size = 30.0
	_siren.max_distance = 120.0
	_siren_light = OmniLight3D.new()
	_siren_light.omni_range = 18.0
	_siren_light.light_energy = 0.0
	holder.add_child(_siren_light)

# ================================================================ consultas

func get_entity(id: int) -> Entity:
	return entities.get(id)

func get_door(id: int) -> Door:
	return doors[id] if id >= 0 and id < doors.size() else null

func player_position(peer: int) -> Vector3:
	if not players.has(peer):
		return Vector3.INF
	var p: Player = players[peer]
	return p.get_state()[0]

func night_over() -> bool:
	return bool(game.get("over", false))

func police_coming() -> bool:
	return float(game.get("police", -1.0)) >= 0.0

## Cuántos jugadores no se subieron al camión (para avisar antes de arrancar).
func players_away_from_truck() -> int:
	var n := 0
	for peer: int in players:
		if not is_seated(peer):
			n += 1
	return n

func is_seated(peer: int) -> bool:
	return truck.seats.has(peer)

## ¿No hay nada entre a y b? Con `furniture` también cuentan los muebles (para la vista);
## sin eso, solo paredes y puertas (para buscar caminos).
func line_clear(a: Vector3, b: Vector3, furniture := true) -> bool:
	var mask := (Config.L_WORLD | Config.L_DOOR | Config.L_BIG) if furniture else (Config.L_WALL | Config.L_DOOR)
	var query := PhysicsRayQueryParameters3D.create(a, b, mask)
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()

## Cuántas paredes o puertas cerradas hay entre a y b (tapan el sonido).
func count_walls(a: Vector3, b: Vector3) -> int:
	var space := get_world_3d().direct_space_state
	var exclude: Array[RID] = []
	var n := 0
	while n < 5:
		var query := PhysicsRayQueryParameters3D.create(a, b, Config.L_WALL | Config.L_DOOR, exclude)
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			break
		exclude.append(hit["rid"])
		n += 1
	return n

func debug_text() -> String:
	var t := "FPS %d   objetos %d\n" % [Engine.get_frames_per_second(), entities.size()]
	t += "Don Ramón: %s   alerta %.0f   sueño x%.2f   despertadas %d\n" \
			% [HouseOwner.State.keys()[homeowner.state], homeowner.alert, homeowner.sleep_mult, homeowner.wakes]
	if local_player:
		t += "pos %s   voz %.2f (%s)\n" % [local_player.global_position.snapped(Vector3(0.1, 0.1, 0.1)), Voice.level, Voice.level_word(Voice.level)]
	t += "camión %.1f km/h   conductor %s   golpes en la caja %d\n" % [truck.speed * 3.6, _name(truck.driver) if truck.driver != 0 else "-", cargo_hits]
	for n: String in debug_noises:
		t += n + "\n"
	return t

# ================================================================ jugadores

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
	if is_server and not _stats.has(peer):
		_stats[peer] = _empty_stats()
	if p.is_local:
		local_player = p
		if DisplayServer.get_name() != "headless":
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	players_changed.emit()

static func _empty_stats() -> Dictionary:
	return {"noise": 0.0, "broken": 0, "loot": 0, "caught": 0, "wakes": 0}

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
		pname = "Mudancero %d" % (players.size() + 1)
	var slot := _free_slot()
	var spawn: Vector3 = HouseBuilder.SPAWNS[slot % HouseBuilder.SPAWNS.size()]
	rpc_welcome.rpc_id(peer, _snapshot())
	_ready_peers[peer] = true
	_add_player(peer, pname, spawn, slot)
	_send_clients(&"rpc_add_player", [peer, pname, spawn, slot])
	_broadcast_message("%s llegó en el camión." % pname)

@rpc("authority", "call_remote", "reliable")
func rpc_welcome(snap: Dictionary) -> void:
	_apply_snapshot(snap)
	hud.hide_banner()
	if results.is_empty():
		message.emit(_intro_text(), true)

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
	if truck.seats.has(peer):
		var seats: Dictionary = truck.seats.duplicate()
		seats.erase(peer)
		_send_all(&"rpc_seats", [seats])
	for e: Entity in entities.values():
		if e.holders.has(peer):
			e.holders.erase(peer)
			_srv_carriers_changed(e)
	var pname: String = player_names.get(peer, "Alguien")
	_remove_player(peer)
	_send_clients(&"rpc_remove_player", [peer])
	_broadcast_message("%s se fue de la partida." % pname)

## Cada computadora manda la posición de su jugador (y su nivel de voz); el anfitrión la reparte.
func send_player_state(pos: Vector3, yaw: float, pitch: float, flags: int, level: float) -> void:
	if not is_server:
		rpc_player_state.rpc_id(1, pos, yaw, pitch, flags, level)

@rpc("any_peer", "call_remote", "unreliable_ordered")
func rpc_player_state(pos: Vector3, yaw: float, pitch: float, flags: int, level: float) -> void:
	if not is_server:
		return
	var peer := multiplayer.get_remote_sender_id()
	if players.has(peer):
		(players[peer] as Player).set_net_state(pos, yaw, pitch, flags, clampf(level, 0.0, 1.0))

@rpc("authority", "call_remote", "unreliable_ordered")
func rpc_players(states: Array) -> void:
	var me := multiplayer.get_unique_id()
	for s: Array in states:
		var peer: int = s[0]
		if peer != me and players.has(peer):
			(players[peer] as Player).set_net_state(s[1], s[2], s[3], s[4], s[5])

# ================================================================ foto completa

func _snapshot() -> Dictionary:
	var ents := []
	for e: Entity in entities.values():
		ents.append([e.entity_id, e.kind, e.info.duplicate(), e.global_position, e.global_transform.basis.get_rotation_quaternion(), e.carriers])
	var pl := []
	for peer: int in players:
		pl.append([peer, player_names[peer], player_position(peer), player_slots[peer]])
	var door_states := []
	for d in doors:
		door_states.append(d.is_open)
	return {
		"game": game.duplicate(),
		"results": results.duplicate(true),
		"entities": ents,
		"players": pl,
		"doors": door_states,
		"owner": homeowner.get_net_state() + [homeowner.sleep_mult],
		"truck": truck.get_net_state(),
		"seats": truck.seats.duplicate(),
	}

func _apply_snapshot(snap: Dictionary) -> void:
	for id: int in entities.keys():
		_destroy_entity(id)
	game = snap["game"]
	results = snap["results"]
	_show_style(int(game.get("style", 0)))
	for d: Array in snap["entities"]:
		var e := _create_entity(d[0], d[1], d[2], d[3], d[4])
		e.carriers = d[5]
	for d: Array in snap["players"]:
		_add_player(d[0], d[1], d[2], d[3])
	var door_states: Array = snap["doors"]
	for i in mini(door_states.size(), doors.size()):
		doors[i].set_open(door_states[i])
	var o: Array = snap["owner"]
	homeowner.global_position = o[0]
	homeowner.set_net_state(o[0], o[1], o[2], o[3])
	homeowner.sleep_mult = o[4]
	var t: Array = snap["truck"]
	truck.park(t[0], 0.0)
	truck.global_transform = Transform3D(Basis(t[1] as Quaternion), t[0])
	truck.set_net_state(t[0], t[1], t[2])
	rpc_seats(snap["seats"])
	game_changed.emit()
	if results.is_empty():
		night_started.emit()
	else:
		night_finished.emit(results)

@rpc("authority", "call_remote", "reliable")
func rpc_reset(snap: Dictionary) -> void:
	_apply_snapshot(snap)
	message.emit(_intro_text(), true)

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

@rpc("authority", "call_remote", "reliable")
func rpc_sound(sound: String, pos: Vector3, volume_db: float, pitch: float) -> void:
	Sfx.play_at(sound, pos, volume_db, pitch)

func _srv_sound(sound: String, pos: Vector3, volume_db := 0.0, pitch := 1.0) -> void:
	_send_all(&"rpc_sound", [sound, pos, volume_db, pitch])

func _name(peer: int) -> String:
	return player_names.get(peer, "Alguien")

# ================================================================ entidades

func _srv_spawn(kind: String, info: Dictionary, pos: Vector3, rot := Quaternion.IDENTITY) -> Entity:
	if entities.size() >= Config.MAX_ENTITIES:
		return null
	var id := _next_id
	_next_id += 1
	var e := _create_entity(id, kind, info, pos, rot)
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
	if is_server:
		e.quiet_until = _time + 2.0
		e.impact.connect(_srv_on_impact)
	return e

func _destroy_entity(id: int) -> void:
	var e: Entity = entities.get(id)
	entities.erase(id)
	_loaded.erase(id)
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

@rpc("authority", "call_remote", "reliable")
func rpc_carriers(id: int, n: int) -> void:
	var e: Entity = entities.get(id)
	if e:
		e.carriers = n

func _srv_carriers_changed(e: Entity) -> void:
	if e.carriers != e.holders.size():
		_send_all(&"rpc_carriers", [e.entity_id, e.holders.size()])

# ================================================================ pedidos de los jugadores
# Cada pedido tiene tres partes: la función pública (la llama el jugador local), el RPC que
# llega al anfitrión y la versión _srv_ que hace el trabajo con el número de jugador.

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
	var ok := e != null and not night_over() and not (players.has(peer) and (players[peer] as Player).ejected)
	if ok:
		var size: Vector3 = e.data.get("size", Vector3.ONE * 0.3)
		var reach := Config.INTERACT_RANGE + maxf(size.x, maxf(size.y, size.z)) * 0.5 + 1.5
		ok = player_position(peer).distance_to(e.global_position) < reach
		# Lo chico se agarra de a uno; lo pesado, entre varios.
		if ok and not e.is_heavy() and not e.holders.is_empty() and not e.holders.has(peer):
			ok = false
	if ok:
		for other: Entity in entities.values():
			if other != e and other.holders.has(peer):
				other.holders.erase(peer)
				_srv_carriers_changed(other)
		e.holders[peer] = [e.global_position, _time]
		e.last_holder = peer
		if e.freeze:
			e.freeze = false   # el cuadro estaba colgado de la pared
			e.info["hung"] = false
		e.sleeping = false
		_srv_carriers_changed(e)
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
	if e and e.holders.has(peer):
		e.holders[peer] = [target, _time]

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
	if e == null or not e.holders.has(peer):
		return
	e.holders.erase(peer)
	_srv_carriers_changed(e)
	if e.holders.is_empty() and throw_dir.length() > 0.1 and not e.is_heavy():
		var speed := Config.THROW_SPEED * (0.5 if e.mass > 5.0 else 1.0)
		e.linear_velocity = throw_dir.normalized() * speed + Vector3(0, 1.2, 0)
		e.angular_velocity = Vector3(_rng.randf_range(-6, 6), _rng.randf_range(-6, 6), _rng.randf_range(-6, 6))
		e.ignore_next_impacts()

func request_door(id: int) -> void:
	if is_server:
		_srv_door(1, id)
	else:
		rpc_req_door.rpc_id(1, id)

@rpc("any_peer", "call_remote", "reliable")
func rpc_req_door(id: int) -> void:
	if is_server:
		_srv_door(multiplayer.get_remote_sender_id(), id)

func _srv_door(peer: int, id: int) -> void:
	var d := get_door(id)
	if d == null or player_position(peer).distance_to(d.center()) > Config.INTERACT_RANGE + 1.5:
		return
	srv_set_door(id, not d.is_open, peer)

## Abre o cierra una puerta (peer 0 = la abre el dueño, que no hace ruido "contra sí mismo").
func srv_set_door(id: int, open: bool, peer: int) -> void:
	var d := get_door(id)
	if d == null or d.is_open == open:
		return
	_send_all(&"rpc_door", [id, open])
	if peer != 0:
		_srv_noise(d.center() + Vector3(0, 1.8, 0), d.creak, 1.0, peer, "puerta")

@rpc("authority", "call_remote", "reliable")
func rpc_door(id: int, open: bool) -> void:
	var d := get_door(id)
	if d == null:
		return
	d.set_open(open)
	Sfx.play_at("door", d.center() + Vector3(0, 1.8, 0), linear_to_db(0.3 + d.creak), 1.25 - d.creak * 0.5)

## Manejar, subirse o bajarse del camión. `action`: "truck_drive", "truck_ride" o "exit".
func request_seat(action: String) -> void:
	if is_server:
		srv_seat(1, action)
	else:
		rpc_req_seat.rpc_id(1, action)

@rpc("any_peer", "call_remote", "reliable")
func rpc_req_seat(action: String) -> void:
	if is_server:
		srv_seat(multiplayer.get_remote_sender_id(), action)

func srv_seat(peer: int, action: String) -> bool:
	if not players.has(peer) or night_over():
		return false
	var seats: Dictionary = truck.seats.duplicate()
	if action == "exit":
		if not seats.has(peer) or truck.speed > Config.TRUCK_EXIT_SPEED:
			return false
		seats.erase(peer)
	else:
		if seats.has(peer) or (players[peer] as Player).ejected:
			return false
		if player_position(peer).distance_to(truck.door_position(action)) > Config.INTERACT_RANGE + 1.5:
			return false
		var seat := 0 if action == "truck_drive" and truck.driver == 0 else truck.free_seat()
		if seat < 0:
			return false
		seats[peer] = seat
		# Lo que tenía en la mano se queda donde está.
		for e: Entity in entities.values():
			if e.holders.has(peer):
				e.holders.erase(peer)
				_srv_carriers_changed(e)
	_send_all(&"rpc_seats", [seats])
	_srv_sound("thud", truck.global_position + Vector3(0, 1.2, 0), -4.0, 1.4)
	if truck.driver != 0 and action == "truck_drive":
		_broadcast_message("%s se subió a manejar. Súbanse todos antes de arrancar." % _name(peer))
	return true

@rpc("authority", "call_remote", "reliable")
func rpc_seats(seats: Dictionary) -> void:
	truck.set_seats(seats)
	for peer: int in players:
		(players[peer] as Player).set_seat(int(seats.get(peer, -1)))

## El conductor manda acelerador, volante y freno de mano.
func send_drive_input(throttle: float, steer: float, handbrake: bool) -> void:
	if is_server:
		_srv_drive_input(1, throttle, steer, handbrake)
	else:
		rpc_drive_input.rpc_id(1, throttle, steer, handbrake)

@rpc("any_peer", "call_remote", "unreliable_ordered")
func rpc_drive_input(throttle: float, steer: float, handbrake: bool) -> void:
	if is_server:
		_srv_drive_input(multiplayer.get_remote_sender_id(), throttle, steer, handbrake)

func _srv_drive_input(peer: int, throttle: float, steer: float, handbrake: bool) -> void:
	if truck.driver == peer and not night_over():
		truck.set_input(throttle, steer, handbrake)

@rpc("authority", "call_remote", "unreliable_ordered")
func rpc_truck(pos: Vector3, rot: Quaternion, steer: float) -> void:
	truck.set_net_state(pos, rot, steer)

## Lo que va en la caja viaja pegado al camión: se manda su posición relativa al camión.
@rpc("authority", "call_remote", "unreliable_ordered")
func rpc_cargo(ids: PackedInt32Array, positions: PackedVector3Array, rots: PackedFloat32Array) -> void:
	for i in ids.size():
		var e: Entity = entities.get(ids[i])
		if e:
			e.set_net_local(positions[i], Quaternion(rots[i * 4], rots[i * 4 + 1], rots[i * 4 + 2], rots[i * 4 + 3]), truck)

# ================================================================ ruido

## Un ruido que puede oír el dueño. `who` es para el panel de depuración.
func _srv_noise(pos: Vector3, loudness: float, weight: float, peer: int, who: String) -> void:
	var add := homeowner.hear(pos, loudness, weight, peer)
	if _stats.has(peer):
		_stats[peer]["noise"] = float(_stats[peer]["noise"]) + add
	if add > 0.5 or weight >= 1.0:
		debug_noises.push_front("%s (%s) en %s: %.2f -> +%.1f" % [who, _name(peer) if peer != 0 else "-", HouseBuilder.room_name(pos), loudness, add])
		if debug_noises.size() > 6:
			debug_noises.pop_back()

func _srv_on_impact(e: Entity, speed: float) -> void:
	if _time < e.quiet_until or not entities.has(e.entity_id):
		return
	if _loaded.has(e.entity_id):
		cargo_hits += 1
	if e.is_fragile() and speed > float(e.data.get("break", 5.0)):
		_srv_break(e)
		return
	if _time - float(_impact_times.get(e.entity_id, -1.0)) < 0.15:
		return
	_impact_times[e.entity_id] = _time
	var loud := clampf(speed * sqrt(e.mass) * Config.NOISE_IMPACT_K, 0.0, 1.0)
	if loud < 0.06:
		return
	_srv_noise(e.global_position, loud, 1.0, e.last_holder, "golpe de %s" % e.data.get("name", "algo"))
	var sound := "thud"
	if e.item_id in ["pot", "safe", "trophy"]:
		sound = "clang"
	elif e.item_id == "duck":
		sound = "duck"
	_srv_sound(sound, e.global_position, linear_to_db(clampf(loud * 1.6, 0.05, 1.5)), 1.4 - minf(e.mass / 60.0, 0.7))

func _srv_break(e: Entity) -> void:
	var pos := e.global_position
	var peer := e.last_holder
	if _stats.has(peer):
		_stats[peer]["broken"] = int(_stats[peer]["broken"]) + 1
	var what: String = e.data.get("name", "algo")
	var lost := e.value()
	_srv_despawn(e.entity_id)
	_send_all(&"rpc_broken", [pos, e.main_color])
	_srv_noise(pos, Config.NOISE_CRASH[0], Config.NOISE_CRASH[1], peer, "se rompió %s" % what)
	var text := "¡CRASH! Se rompió: %s" % what.to_lower()
	if lost > 1:
		text += " ($%d menos)" % lost
	if peer != 0:
		text += ". Culpa de %s." % _name(peer)
	_broadcast_message(text)

@rpc("authority", "call_remote", "reliable")
func rpc_broken(pos: Vector3, c: Color) -> void:
	Fx.shards(self, pos, c)
	Sfx.play_at("crash", pos, 6.0)
	if local_player:
		local_player.add_shake(clampf(0.6 - local_player.global_position.distance_to(pos) / 15.0, 0.0, 0.6))

## Pasos, voz, tablas que crujen y cosas arrastradas: lo que hacen los jugadores en cada paso de física.
func _srv_player_noises(delta: float) -> void:
	for peer: int in players:
		var p: Player = players[peer]
		var pos := player_position(peer)
		var flags := p.net_flags
		# Voz (el micrófono de cada uno).
		if p.voice > 0.05:
			_srv_noise(pos + Vector3(0, 1.5, 0), p.voice * Config.VOICE_LOUDNESS, delta, peer, "voz")
		# Pasos.
		var t := float(_step_timers.get(peer, 0.0)) - delta
		if (flags & Player.F_MOVING) != 0:
			if t <= 0.0:
				var noise: Array = Config.NOISE_STEP_WALK
				t = Config.STEP_INTERVAL_WALK
				if (flags & Player.F_CROUCH) != 0:
					noise = Config.NOISE_STEP_CROUCH
					t = Config.STEP_INTERVAL_CROUCH
				elif (flags & Player.F_SPRINT) != 0:
					noise = Config.NOISE_STEP_SPRINT
					t = Config.STEP_INTERVAL_SPRINT
				if HouseBuilder.in_house(pos):
					_srv_noise(pos, noise[0], noise[1], peer, "pasos")
		else:
			t = 0.1
		_step_timers[peer] = t
		# Tablas que crujen.
		var board := -1
		for i in boards.size():
			if (boards[i] as Rect2).has_point(Vector2(pos.x, pos.z)) and pos.y < 0.5:
				board = i
				break
		if board != -1 and board != int(_on_board.get(peer, -1)):
			var crouch := (flags & Player.F_CROUCH) != 0
			var n: Array = Config.NOISE_BOARD_CROUCH if crouch else Config.NOISE_BOARD
			_srv_noise(pos, n[0], n[1], peer, "tabla que cruje")
			_srv_sound("squeak", pos, -6.0 if crouch else 2.0, _rng.randf_range(0.85, 1.15))
		_on_board[peer] = board
	# Muebles pesados arrastrados por una sola persona.
	for e: Entity in entities.values():
		if not e.dragging:
			continue
		var st := float(_scrape_timers.get(e.entity_id, 0.0)) - delta
		if st <= 0.0:
			st = 0.3
			var peer: int = e.holders.keys()[0] if not e.holders.is_empty() else e.last_holder
			_srv_noise(e.global_position, Config.NOISE_SCRAPE[0], Config.NOISE_SCRAPE[1], peer, "arrastre")
			_srv_sound("scrape", e.global_position, 0.0, _rng.randf_range(0.8, 1.2))
		_scrape_timers[e.entity_id] = st

# ================================================================ el dueño

func _on_owner_woke(blame: int) -> void:
	if _stats.has(blame):
		_stats[blame]["wakes"] = int(_stats[blame]["wakes"]) + 1
	var text := "¡DON RAMÓN SE DESPERTÓ!"
	if blame != 0 and player_names.has(blame):
		text = "¡%s despertó a Don Ramón!" % _name(blame)
	_broadcast_message(text + " Escóndanse o salgan de ahí.", true)

func _on_owner_spotted(peer: int) -> void:
	_broadcast_message("¡Don Ramón vio a %s!" % _name(peer), false)

func _on_owner_caught(peer: int) -> void:
	if not players.has(peer) or night_over():
		return
	var p: Player = players[peer]
	p.ejected = true
	_eject_timers[peer] = 6.0
	for e: Entity in entities.values():
		if e.holders.has(peer):
			e.holders.erase(peer)
			_srv_carriers_changed(e)
			if peer == multiplayer.get_unique_id():
				rpc_released(e.entity_id)
			else:
				rpc_released.rpc_id(peer, e.entity_id)
	if _stats.has(peer):
		_stats[peer]["caught"] = int(_stats[peer]["caught"]) + 1
	var pos := HouseBuilder.EJECT_POS + Vector3(_rng.randf_range(-1.0, 1.0), 0, _rng.randf_range(-0.5, 0.5))
	if peer == multiplayer.get_unique_id():
		rpc_ejected(pos)
	else:
		rpc_ejected.rpc_id(peer, pos)
	_srv_sound("thud", pos, 6.0, 0.7)
	_broadcast_message("¡Don Ramón agarró a %s y lo tiró a la calle!" % _name(peer), true)
	if not police_coming():
		game["police"] = Config.POLICE_DELAY
		_game_dirty = true
		_broadcast_message("Don Ramón llamó a la policía: llega en %d segundos. ¡Carguen lo que puedan y váyanse!" % int(Config.POLICE_DELAY), true)

@rpc("authority", "call_remote", "reliable")
func rpc_ejected(pos: Vector3) -> void:
	if local_player:
		local_player.teleport(pos)
		local_player.apply_knockback(Vector3(0, 3.0, 4.0), Config.CAUGHT_STUN)
		local_player.holding_id = 0

@rpc("authority", "call_remote", "unreliable_ordered")
func rpc_owner(pos: Vector3, yaw: float, state: int, alert: float) -> void:
	homeowner.set_net_state(pos, yaw, state, alert)

# ================================================================ la noche

func _srv_new_night(night: int, bank: int) -> void:
	for id: int in entities.keys():
		_destroy_entity(id)
	_loaded.clear()
	_impact_times.clear()
	_scrape_timers.clear()
	_on_board.clear()
	for peer: int in _stats:
		_stats[peer] = _empty_stats()
	results = {}
	debug_noises.clear()
	for i in doors.size():
		doors[i].set_open(DOORS_OPEN_AT_START[i])
	truck.park(HouseBuilder.TRUCK_POS, HouseBuilder.TRUCK_ROT)
	rpc_seats({})
	cargo_hits = 0
	jolts.clear()
	homeowner.reset()
	# Cada noche Don Ramón tiene el sueño un poco más liviano.
	homeowner.sleep_mult = 1.0 + 0.12 * (night - 1)
	for s: Array in item_spawns:
		var data := Config.item(s[0])
		var info := {"item": s[0]}
		if data.get("hang", false):
			info["hung"] = true
		var rot := Quaternion(Vector3.UP, deg_to_rad(float(s[2]) + _rng.randf_range(-4.0, 4.0)))
		_srv_spawn("item", info, s[1], rot)
	game = {
		"night": night,
		"time_left": Config.NIGHT_LENGTH,
		"quota": Config.quota_for_night(night),
		"truck": 0,
		"police": -1.0,
		"over": false,
		"bank": bank,
		"style": _rng.randi_range(1, 999999),
	}
	_show_style(int(game["style"]))
	_game_dirty = true
	night_started.emit()

## Empieza otra noche (la llama el anfitrión desde la pantalla de resultados).
func srv_next_night() -> void:
	if not is_server:
		return
	_srv_new_night(int(game.get("night", 1)) + 1, int(game.get("bank", 0)))
	_send_clients(&"rpc_reset", [_snapshot()])
	for peer: int in players:
		var pos: Vector3 = HouseBuilder.SPAWNS[int(player_slots[peer]) % HouseBuilder.SPAWNS.size()]
		if peer == multiplayer.get_unique_id():
			rpc_teleport(pos)
		else:
			rpc_teleport.rpc_id(peer, pos)
	message.emit(_intro_text(), true)
	game_changed.emit()

## Lo que hay en el camión (se revisa cuatro veces por segundo).
func _srv_check_truck() -> void:
	var inside := {}
	for body in truck_area.get_overlapping_bodies():
		var e := body as Entity
		if e and entities.has(e.entity_id) and e.value() > 0:
			inside[e.entity_id] = e
	var total := 0
	for id: int in inside:
		var e: Entity = inside[id]
		total += e.value()
		if not _loaded.has(id):
			_loaded[id] = e.last_holder
			if _stats.has(e.last_holder):
				_stats[e.last_holder]["loot"] = int(_stats[e.last_holder]["loot"]) + e.value()
			_send_all(&"rpc_loaded", [e.global_position, e.value(), String(e.data.get("name", ""))])
	for id: int in _loaded.keys():
		if not inside.has(id):
			var peer: int = _loaded[id]
			var e: Entity = entities.get(id)
			if e and _stats.has(peer):
				_stats[peer]["loot"] = int(_stats[peer]["loot"]) - e.value()
			_loaded.erase(id)
	if total != int(game["truck"]):
		game["truck"] = total
		_game_dirty = true

@rpc("authority", "call_remote", "reliable")
func rpc_loaded(pos: Vector3, value: int, what: String) -> void:
	Sfx.play_at("coin", pos, -2.0)
	Fx.floating_text(self, pos + Vector3(0, 0.6, 0), "+$%d" % value)
	message.emit("Al camión: %s ($%d)." % [what.to_lower(), value], false)

func _srv_end_night(reason: String) -> void:
	if night_over():
		return
	var value := int(game["truck"])
	var quota := int(game["quota"])
	var rows := []
	var detained := 0
	# Si se van sin llegar a la cuota, el encargo se cancela y se pierde todo lo cargado.
	var canceled := reason == "leave" and value < quota
	if canceled:
		reason = "cancel"
	for peer: int in players:
		var st: Dictionary = _stats.get(peer, _empty_stats())
		var left_behind := not is_seated(peer)
		if reason != "leave" and reason != "cancel":
			left_behind = left_behind and not HouseBuilder.at_truck(player_position(peer))
		if left_behind:
			detained += 1
		rows.append({"name": _name(peer), "noise": roundi(float(st["noise"])), "broken": st["broken"],
				"loot": st["loot"], "caught": st["caught"], "wakes": st["wakes"], "left": left_behind})
	var fines := 0 if canceled else detained * Config.ARREST_FINE
	var total := 0 if canceled else maxi(value - fines, 0)
	game["over"] = true
	game["bank"] = int(game.get("bank", 0)) + total
	truck.locked = true
	results = {
		"reason": reason,
		"night": game["night"],
		"value": value,
		"quota": quota,
		"stars": 0 if canceled else Config.stars(value, quota),
		"fines": fines,
		"total": total,
		"bank": game["bank"],
		"wakes": homeowner.wakes,
		"players": rows,
		"titles": _titles(rows),
	}
	for e: Entity in entities.values():
		e.holders.clear()
		_srv_carriers_changed(e)
	_send_all(&"rpc_night_over", [results, game])

## Los "premios" de la noche (para reírse del que hizo más ruido).
static func _titles(rows: Array) -> Array:
	var out := []
	var cats := [
		["noise", "El más ruidoso", 5],
		["wakes", "Despertador humano", 1],
		["broken", "Manos de mantequilla", 1],
		["caught", "Imán de abuelos", 1],
		["loot", "Empleado del mes", 1],
	]
	for c: Array in cats:
		var best := ""
		var best_v := 0
		for r: Dictionary in rows:
			var v := int(r[c[0]])
			if v >= int(c[2]) and v > best_v:
				best_v = v
				best = r["name"]
		if best != "":
			out.append([c[1], best])
	return out

@rpc("authority", "call_remote", "reliable")
func rpc_night_over(res: Dictionary, state: Dictionary) -> void:
	results = res
	game = state
	if local_player and local_player.holding_id != 0:
		local_player.holding_id = 0
	game_changed.emit()
	night_finished.emit(results)

@rpc("authority", "call_remote", "reliable")
func rpc_game(state: Dictionary) -> void:
	game = state
	_show_style(int(game.get("style", 0)))
	game_changed.emit()

# ================================================================ bucle principal

func _physics_process(delta: float) -> void:
	_time += delta
	if is_server:
		_srv_tick(delta)

func _srv_tick(delta: float) -> void:
	var playing := not night_over()
	# Objetos agarrados (y los que se cayeron del mundo).
	for e: Entity in entities.values().duplicate():
		if e.global_position.y < -10.0:
			_srv_despawn(e.entity_id)
			continue
		if e.holders.is_empty():
			e.dragging = false
			continue
		var max_d := 4.0 if e.is_heavy() else 3.0
		for peer: int in e.holders.keys():
			var h: Array = e.holders[peer]
			if _time - float(h[1]) > Entity.HOLD_TIMEOUT or player_position(peer).distance_to(e.global_position) > max_d:
				e.holders.erase(peer)
				if peer == multiplayer.get_unique_id():
					rpc_released(e.entity_id)
				elif _ready_peers.has(peer):
					rpc_released.rpc_id(peer, e.entity_id)
		_srv_carriers_changed(e)
		if e.holders.is_empty():
			e.dragging = false
		else:
			e.server_hold_step(delta)
	if playing:
		_srv_player_noises(delta)
		for peer: int in _eject_timers.keys():
			_eject_timers[peer] = float(_eject_timers[peer]) - delta
			if float(_eject_timers[peer]) <= 0.0:
				_eject_timers.erase(peer)
				if players.has(peer):
					(players[peer] as Player).ejected = false
		_truck_timer -= delta
		if _truck_timer <= 0.0:
			_truck_timer = 0.25
			_srv_check_truck()
		_srv_truck_tick(delta)
		# Reloj de la noche y policía.
		game["time_left"] = float(game["time_left"]) - delta
		if float(game["time_left"]) <= 0.0:
			_broadcast_message("Amaneció. Don Ramón se levanta temprano...", true)
			_srv_end_night("dawn")
		elif police_coming():
			game["police"] = float(game["police"]) - delta
			if float(game["police"]) <= 0.0:
				game["police"] = 0.0
				_broadcast_message("¡LLEGÓ LA POLICÍA!", true)
				_srv_end_night("police")
	_game_timer -= delta
	if _game_dirty or _game_timer <= 0.0:
		_game_timer = 1.0
		_game_dirty = false
		_send_clients(&"rpc_game", [game])
		game_changed.emit()
	_sync_timer -= delta
	if _sync_timer <= 0.0:
		_sync_timer = SYNC_INTERVAL
		_srv_sync()

## El motor hace ruido (Don Ramón lo puede oír), lo de la caja no se duerme mientras el camión
## anda, y si se alejan lo suficiente, se escaparon.
## Un sacudón del camión golpea todo lo que va suelto en la caja (y lo frágil se puede romper).
## La culpa es del que maneja.
func _srv_on_truck_jolt(strength: float) -> void:
	if night_over():
		return
	jolts.append(snappedf(strength, 0.1))
	for id: int in _loaded.keys():
		var e: Entity = entities.get(id)
		if e and e.holders.is_empty():
			if truck.driver != 0:
				e.last_holder = truck.driver
			_srv_on_impact(e, strength)

func _srv_truck_tick(delta: float) -> void:
	if truck.driver == 0:
		return
	_engine_timer -= delta
	if _engine_timer <= 0.0:
		_engine_timer = 0.5
		var loud: float = Config.NOISE_ENGINE[0] + Config.NOISE_ENGINE[1] * truck.speed
		_srv_noise(truck.global_position + Vector3(0, 1.0, 0), loud, Config.NOISE_ENGINE_WEIGHT, truck.driver, "motor del camión")
	if truck.is_moving():
		for id: int in _loaded:
			var e: Entity = entities.get(id)
			if e:
				e.sleeping = false
	if truck.global_position.distance_to(HouseBuilder.TRUCK_POS) > Config.ESCAPE_DISTANCE and not night_over():
		_broadcast_message("¡Salieron del barrio!", true)
		_srv_end_night("leave")

func _srv_sync() -> void:
	if _ready_peers.size() <= 1:
		for e: Entity in entities.values():
			e.mark_sent()
		return
	var ids := PackedInt32Array()
	var positions := PackedVector3Array()
	var rots := PackedFloat32Array()
	var inv := truck.global_transform.affine_inverse()
	var cargo_ids := PackedInt32Array()
	var cargo_pos := PackedVector3Array()
	var cargo_rots := PackedFloat32Array()
	for e: Entity in entities.values():
		if _loaded.has(e.entity_id) and e.holders.is_empty():
			var local := inv * e.global_transform
			var lq := local.basis.get_rotation_quaternion()
			cargo_ids.append(e.entity_id)
			cargo_pos.append(local.origin)
			cargo_rots.append_array([lq.x, lq.y, lq.z, lq.w])
			e.mark_sent()
			continue
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
	if cargo_ids.size() > 0:
		_send_clients(&"rpc_cargo", [cargo_ids, cargo_pos, cargo_rots])
	var ts := truck.get_net_state()
	_send_clients(&"rpc_truck", [ts[0], ts[1], ts[2]])
	var o := homeowner.get_net_state()
	_send_clients(&"rpc_owner", [o[0], o[1], o[2], o[3]])
	var states := []
	for peer: int in players:
		var s: Array = (players[peer] as Player).get_state()
		states.append([peer, s[0], s[1], s[2], s[3], s[4]])
	_send_clients(&"rpc_players", [states])

func _process(delta: float) -> void:
	_update_ambience(delta)

## La luz del velador (cuando Don Ramón está despierto), la sirena y el amanecer.
func _update_ambience(delta: float) -> void:
	var k := clampf(delta * 3.0, 0.0, 1.0)
	bedroom_lamp.light_energy = lerpf(bedroom_lamp.light_energy, 1.6 if homeowner.is_awake() else 0.0, k)
	# Sirena: se escucha cada vez más cerca.
	var police := float(game.get("police", -1.0))
	if police >= 0.0 and not night_over():
		if not _siren.playing:
			_siren.play()
		var closeness := 1.0 - clampf(police / Config.POLICE_DELAY, 0.0, 1.0)
		_siren.volume_db = lerpf(-24.0, 6.0, closeness)
		_siren_light.light_energy = closeness * 4.0 * (0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.012))
		_siren_light.light_color = Color(1, 0.15, 0.15) if int(Time.get_ticks_msec() / 250) % 2 == 0 else Color(0.2, 0.35, 1)
	elif _siren.playing:
		_siren.stop()
		_siren_light.light_energy = 0.0
	# El último minuto empieza a clarear.
	var left := float(game.get("time_left", Config.NIGHT_LENGTH))
	var dawn := 1.0 - clampf(left / 60.0, 0.0, 1.0)
	moon.light_color = Color(0.6, 0.7, 1.0).lerp(Color(1.0, 0.75, 0.55), dawn)
	moon.light_energy = 0.35 + dawn * 0.6
	env.ambient_light_energy = 0.36 + dawn * 0.25

# ================================================================ pruebas automáticas

@rpc("authority", "call_remote", "reliable")
func rpc_test_request() -> void:
	send_test_report()

func send_test_report() -> void:
	var door_bits := 0
	for d in doors:
		door_bits |= (1 << d.door_id) if d.is_open else 0
	rpc_test_report.rpc_id(1, [entities.size(), door_bits, int(homeowner.state), not results.is_empty(), int(game.get("night", 0)),
			truck.global_position, truck.seats.duplicate()])

@rpc("any_peer", "call_remote", "reliable")
func rpc_test_report(report: Array) -> void:
	if is_server:
		test_reports[multiplayer.get_remote_sender_id()] = report
