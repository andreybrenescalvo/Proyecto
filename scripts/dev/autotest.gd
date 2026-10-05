extends Node
## Prueba automática de punta a punta, pensada para correr sin pantalla:
##
##   godot --headless --path . -- --host --autotest --expect=1
##   godot --headless --path . -- --join=127.0.0.1 --autotest
##
## El anfitrión recorre las mecánicas principales (montacargas, pico, dinamita, derrumbe,
## venta, agarrar y lanzar, puntal, fin del día, frenazo) y al final compara la mina con la
## de cada cliente. Imprime "AUTOTEST OK" o "AUTOTEST FALLÓ" y cierra el juego.

var world: World
var expect_clients := 0
var _failures: Array[String] = []
var _hard_stops := 0

func _ready() -> void:
	await _wait(0.5)
	if world.is_server:
		await _run_host()
	else:
		await _run_client()

func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout

func _say(text: String) -> void:
	print("[autotest %s] %s" % ["anfitrión" if world.is_server else "cliente", text])

func _check(ok: bool, what: String) -> void:
	_say(("OK    " if ok else "FALLA ") + what)
	if not ok:
		_failures.append(what)

func _count_kind(kind: String) -> int:
	var n := 0
	for e: Entity in world.entities.values():
		if e.kind == kind:
			n += 1
	return n

func _cart() -> Entity:
	for e: Entity in world.entities.values():
		if e.kind == "cart":
			return e
	return null

# ---------------------------------------------------------------- anfitrión

func _run_host() -> void:
	var start := Time.get_ticks_msec()
	while world.players.size() < expect_clients + 1:
		if Time.get_ticks_msec() - start > 30000:
			_check(false, "llegaron los clientes esperados (%d)" % expect_clients)
			_finish()
			return
		await _wait(0.2)
	_say("jugadores en la partida: %d" % world.players.size())
	world.game["money"] = 500
	world.lift.hard_stop.connect(func(_s: float) -> void: _hard_stops += 1)
	var me := world.local_player

	# 1. Montacargas: subirse arriba y bajar rápido hasta el fondo, con el carrito.
	me.teleport(Vector3(1.2, 0.3, 1.2))
	await _wait(0.5)
	var t := 0.0
	while t < 7.0 and world.lift.height > Config.LIFT_BOTTOM + 0.01:
		world.send_lift_input(-1, "top")
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
	await _wait(0.6)
	_check(world.lift.height <= Config.LIFT_BOTTOM + 0.01, "el montacargas llegó al fondo (%.1f m)" % world.lift.height)
	_check(me.global_position.y < Config.MINE_Y + 1.5, "el minero bajó parado en el montacargas (y=%.1f)" % me.global_position.y)
	var cart := _cart()
	_check(cart != null and cart.global_position.y < Config.MINE_Y + 1.5, "el carrito bajó en el montacargas")

	# 2. Pico: romper una columna junto a la cámara inicial.
	me.teleport(Vector3(5.0, Config.MINE_Y + 0.2, 5.0))
	await _wait(0.3)
	var target := Vector2i(3, 2)
	var t0 := world.grid.get_type(target)
	var hp: int = Config.CELL_INFO[t0]["hp"]
	for i in hp:
		world._pick_times.clear()
		world._srv_pick(1, target)
	_check(world.grid.get_type(target) == Config.Cell.EMPTY, "el pico rompió la celda %s (%s, %d golpes)" % [target, Config.CELL_INFO[t0]["name"], hp])

	# 3. Dinamita: tres cartuchos al final del túnel este.
	me.teleport(Vector3(-4.0, Config.MINE_Y + 0.2, -4.0))
	var empty_before := world.grid.count_type(Config.Cell.EMPTY)
	var money_before: int = world.game["money"]
	var dyn := world._srv_dynamite(1, Vector3(11.84, Config.MINE_Y + 1.5, -1.0), Vector3(-1, 0, 0), 3)
	_check(dyn != null, "se puso la dinamita")
	_check(int(world.game["money"]) == money_before - 3 * Config.DYNAMITE_COST, "la dinamita costó $%d" % (3 * Config.DYNAMITE_COST))
	var ore_before := _count_kind("ore")
	await _wait(Config.FUSE_TIME + 0.6)
	var empty_after := world.grid.count_type(Config.Cell.EMPTY)
	_check(_count_kind("dynamite") == 0, "la dinamita explotó")
	_check(empty_after >= empty_before + 4, "la explosión abrió %d celdas" % (empty_after - empty_before))
	_say("trozos de mineral sueltos: %d (antes %d)" % [_count_kind("ore"), ore_before])

	# 4. Derrumbe (forzado) con un cartucho en el túnel sur.
	world.debug_force_collapse = true
	var rubble_before := world.grid.count_type(Config.Cell.RUBBLE)
	world._srv_dynamite(1, Vector3(-1.0, Config.MINE_Y + 1.5, -11.84), Vector3(0, 0, 1), 1)
	await _wait(Config.FUSE_TIME + Config.COLLAPSE_WARNING + 0.8)
	world.debug_force_collapse = false
	var rubble_after := world.grid.count_type(Config.Cell.RUBBLE)
	_check(rubble_after > rubble_before, "el derrumbe dejó escombros (%d celdas)" % (rubble_after - rubble_before))
	var zone := MineGrid.zone_of(MineGrid.world_to_cell(Vector3(-1.0, 0, -11.84)))
	_say("estabilidad de la zona después del derrumbe: %.2f" % world.get_stability(zone))
	_check(world.estimate_collapse(Vector3(-1.0, Config.MINE_Y + 1.5, -11.0), 4) > world.estimate_collapse(Vector3(-1.0, Config.MINE_Y + 1.5, -11.0), 1),
			"más cartuchos = más riesgo")

	# 5. Puntal: baja el riesgo.
	var risk_before := world.estimate_collapse(Vector3(-5.0, Config.MINE_Y + 1.0, 3.0), 3)
	var support := world._srv_support(1, Vector3(-5.0, Config.MINE_Y, 3.0))
	_check(support != null, "se puso un puntal")
	var risk_after := world.estimate_collapse(Vector3(-5.0, Config.MINE_Y + 1.0, 3.0), 3)
	_check(risk_after < risk_before, "el puntal bajó el riesgo (%.2f -> %.2f)" % [risk_before, risk_after])

	# 6. Venta en la báscula.
	var money0: int = world.game["money"]
	for i in 3:
		world._srv_spawn("ore", {"ore": "iron"}, Config.SELL_ZONE_POS + Vector3(-0.5 + i * 0.5, 1.2, 0))
	await _wait(1.5)
	var expected := 3 * int(Config.ORES["iron"]["value"])
	_check(int(world.game["money"]) == money0 + expected, "la báscula pagó $%d (dinero %d -> %d)" % [expected, money0, world.game["money"]])

	# 7. Agarrar y lanzar.
	me.teleport(Vector3(5.0, 0.2, 6.0))
	await _wait(0.3)
	var chunk := world._srv_spawn("ore", {"ore": "coal"}, me.global_position + Vector3(0, 1.0, -1.2))
	await _wait(0.2)
	_check(world._srv_grab(1, chunk.entity_id), "se pudo agarrar un trozo de mineral")
	await _wait(0.6)
	_check(me.holding_id == chunk.entity_id, "el minero lo tiene en la mano")
	world._srv_release(1, chunk.entity_id, Vector3(1, 0, 0))
	me.holding_id = 0
	await get_tree().physics_frame
	_check(chunk.linear_velocity.x > 4.0, "salió volando al lanzarlo (%.1f m/s)" % chunk.linear_velocity.x)

	# 8. Frenazo del montacargas a toda velocidad.
	t = 0.0
	while t < 3.5:
		world.send_lift_input(1, "top")
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
	var stops_before := _hard_stops
	await _wait(0.5)
	_check(_hard_stops > stops_before, "soltar el botón a toda velocidad provoca un frenazo")

	# 9. Fin del día: el prestamista cobra.
	var day0: int = world.game["day"]
	var debt0: int = world.game["debt"]
	world.game["time_left"] = 0.05
	await _wait(0.4)
	_check(int(world.game["day"]) == day0 + 1, "pasó al día %d" % (day0 + 1))
	_check(int(world.game["debt"]) < debt0, "la deuda bajó (%d -> %d)" % [debt0, world.game["debt"]])

	# 10. ¿Todos ven la misma mina?
	if expect_clients > 0:
		await _wait(1.0)
		world.test_reports.clear()
		world._send_clients(&"rpc_test_request", [])
		await _wait(1.5)
		_check(world.test_reports.size() == expect_clients, "respondieron %d de %d clientes" % [world.test_reports.size(), expect_clients])
		var mine := world.grid.checksum()
		for peer: int in world.test_reports:
			var rep: Array = world.test_reports[peer]
			_check(int(rep[0]) == mine, "el cliente %d ve la misma mina (%d vs %d)" % [peer, rep[0], mine])
			_check(int(rep[1]) == world.entities.size(), "el cliente %d tiene los mismos objetos (%d vs %d)" % [peer, rep[1], world.entities.size()])
		_check(world.grid.get_type(Vector2i(-4, 0)) == Config.Cell.EMPTY, "el pico del cliente rompió la celda (-4, 0)")
	_finish()

func _finish() -> void:
	if _failures.is_empty():
		print("AUTOTEST OK")
	else:
		print("AUTOTEST FALLÓ: ", ", ".join(_failures))
	get_tree().quit(0 if _failures.is_empty() else 1)

# ---------------------------------------------------------------- cliente

func _run_client() -> void:
	var start := Time.get_ticks_msec()
	while world.local_player == null:
		if Time.get_ticks_msec() - start > 20000:
			print("AUTOTEST FALLÓ: el cliente no entró a la partida")
			get_tree().quit(1)
			return
		await _wait(0.2)
	_say("dentro de la partida; la mina tiene %d celdas visibles" % world.grid.node_count())
	# Bajar a la mina por las escaleras... digo, teletransportándose, y picar una celda.
	world.local_player.teleport(Vector3(-5.0, Config.MINE_Y + 0.2, 1.0))
	await _wait(0.5)
	for i in 10:
		world.request_pick(Vector2i(-4, 0))
		await _wait(Config.PICK_COOLDOWN + 0.05)
	_say("tipo de la celda (-4, 0) después de picar: %d" % world.grid.get_type(Vector2i(-4, 0)))
	# Quedarse esperando: el anfitrión pide el informe y después cierra (eso termina la sesión).
	await _wait(120.0)
	print("AUTOTEST FALLÓ: el cliente esperó demasiado")
	get_tree().quit(1)
