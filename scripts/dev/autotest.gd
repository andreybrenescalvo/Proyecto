extends Node
## Prueba automática de punta a punta, pensada para correr sin pantalla:
##
##   godot --headless --path . -- --host --autotest --expect=1
##   godot --headless --path . -- --join=127.0.0.1 --autotest
##
## El anfitrión recorre las mecánicas principales (el dueño oye la voz y las puertas, cargar el
## camión, romper algo frágil, cargar el sillón entre dos, despertarlo, que persiga y eche a
## alguien, irse, otra noche) y compara lo que ve cada cliente. Imprime "AUTOTEST OK" o
## "AUTOTEST FALLÓ" y cierra el juego.

var world: World
var expect_clients := 0
var _failures: Array[String] = []

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

func _find(item: String) -> Entity:
	for e: Entity in world.entities.values():
		if e.item_id == item:
			return e
	return null

func _talk(level: float, seconds: float) -> void:
	Voice.debug_level = level
	await _wait(seconds)
	Voice.debug_level = 0.0

# ---------------------------------------------------------------- anfitrión

func _run_host() -> void:
	Voice.debug_level = 0.0
	var start := Time.get_ticks_msec()
	while world.players.size() < expect_clients + 1:
		if Time.get_ticks_msec() - start > 30000:
			_check(false, "llegaron los clientes esperados (%d)" % expect_clients)
			_finish()
			return
		await _wait(0.2)
	_say("jugadores en la partida: %d" % world.players.size())
	var me := world.local_player
	var don := world.homeowner

	# 1. La casa.
	_check(world.doors.size() == 5, "la casa tiene 5 puertas")
	_check(world.entities.size() == HouseBuilder._items().size(), "aparecieron los %d objetos" % HouseBuilder._items().size())
	_check(don.state == HouseOwner.State.SLEEP, "Don Ramón está dormido")
	await _wait(2.5)
	_check(don.alert < 3.0, "los objetos se acomodan sin despertarlo (alerta %.1f)" % don.alert)

	# 2. La voz: hablar en la pieza lo despierta de a poco; un susurro en la sala, no.
	me.teleport(Vector3(4.0, 0.1, 3.5))
	await _wait(0.3)
	await _talk(0.5, 1.5)
	var after_talk := don.alert
	_check(after_talk > 20.0 and after_talk < Config.ALERT_WAKE, "hablar en la pieza sube la alerta (%.1f)" % after_talk)
	await _wait(2.0)
	_check(don.alert < after_talk, "en silencio la alerta baja (%.1f -> %.1f)" % [after_talk, don.alert])
	don.alert = 0.0
	me.teleport(Vector3(-4.0, 0.1, 1.5))
	await _wait(0.3)
	await _talk(0.15, 2.0)
	_check(don.alert < 3.0, "un susurro en la sala casi no se oye (%.1f)" % don.alert)

	# 3. Las puertas: cerradas tapan el paso; abiertas, se puede pasar de verdad.
	var front := world.doors[0]
	_check(_door_blocks(front), "la puerta de calle cerrada tapa el paso")
	world.srv_set_door(0, true, 1)
	await _wait(1.0)
	_check(not _door_blocks(front), "la puerta de calle abierta deja pasar")
	world.srv_set_door(0, false, 1)
	await _wait(1.0)
	_check(_door_blocks(front), "y al cerrarla vuelve a tapar")
	don.alert = 0.0
	# La puerta del dormitorio chilla (y el cliente la ve abierta).
	don.alert = 0.0
	world.srv_set_door(2, true, 1)
	_check(world.doors[2].is_open, "se abrió la puerta del dormitorio")
	_check(don.alert >= 10.0, "la puerta que chilla se oyó (alerta %.1f)" % don.alert)
	don.alert = 0.0

	# 4. Cargar el joyero en el camión.
	var jewelry := _find("jewelry")
	me.teleport(Vector3(7.0, 0.1, 2.9))
	await _wait(0.3)
	_check(world._srv_grab(1, jewelry.entity_id), "se agarró el joyero")
	await _wait(0.3)
	_check(me.holding_id == jewelry.entity_id, "el jugador lo tiene en la mano")
	# Adentro de la caja del camión, mirando hacia la cabina.
	me.teleport(Vector3(-8.6, 0.65, 18.7))
	me.yaw = PI * 0.5
	jewelry.global_position = Vector3(-9.8, 1.6, 18.7)
	await _wait(0.8)
	world.request_release(jewelry.entity_id, Vector3.ZERO)
	me.holding_id = 0
	await _wait(1.2)
	_check(int(world.game["truck"]) >= jewelry.value(), "el camión cuenta el joyero ($%d)" % world.game["truck"])
	_check(int(world._stats[1]["loot"]) >= jewelry.value(), "se le acreditó al que lo cargó")

	# 5. Lanzar el jarrón contra la pared: se rompe.
	don.alert = 0.0
	var vase := _find("vase")
	var vase_id := vase.entity_id
	me.teleport(Vector3(-5.2, 0.1, 4.4))
	await _wait(0.3)
	_check(world._srv_grab(1, vase_id), "se agarró el jarrón")
	await _wait(0.4)
	world._srv_release(1, vase_id, Vector3(-1, 0, 0))
	me.holding_id = 0
	await _wait(1.0)
	_check(not world.entities.has(vase_id), "el jarrón se rompió contra la pared")
	_check(int(world._stats[1]["broken"]) == 1, "la rotura quedó anotada")
	_say("alerta después del CRASH en la sala: %.1f" % don.alert)
	don.alert = 0.0

	# 6. El sillón: entre dos se levanta; solo, se arrastra.
	var sofa := _find("sofa")
	if expect_clients > 0:
		var other: int = world.players.keys().filter(func(p: int) -> bool: return p != 1)[0]
		me.teleport(Vector3(-4.4, 0.1, 3.0))
		await _wait(0.4)
		var rest_y := sofa.global_position.y
		_check(world._srv_grab(1, sofa.entity_id), "el anfitrión agarró el sillón")
		_check(world._srv_grab(other, sofa.entity_id), "el cliente agarró el sillón")
		await _wait(1.5)
		_check(sofa.carriers == 2, "lo cargan dos (%d)" % sofa.carriers)
		_check(sofa.global_position.y > rest_y + 0.2, "entre dos se levanta (%.2f -> %.2f)" % [rest_y, sofa.global_position.y])
		world._srv_release(1, sofa.entity_id, Vector3.ZERO)
		me.holding_id = 0
		await _wait(1.0)
		_check(sofa.carriers == 1 and sofa.global_position.y < rest_y + 0.15, "con uno solo vuelve al piso (%.2f)" % sofa.global_position.y)
		var dragged := false
		for i in 30:
			dragged = dragged or sofa.dragging
			await get_tree().physics_frame
		_check(dragged, "uno solo lo arrastra (y hace ruido)")
		sofa.holders.clear()
		world._srv_carriers_changed(sofa)
		world.rpc_released.rpc_id(other, sofa.entity_id)
	don.alert = 0.0

	# 7. Despertarlo: se levanta, ve al anfitrión en el pasillo, lo persigue y lo echa a la calle.
	me.teleport(Vector3(1.0, 0.1, 4.2))
	me.yaw = 0.0
	await _wait(0.3)
	don.alert = Config.ALERT_WAKE
	var t0 := Time.get_ticks_msec()
	var saw_chase := false
	var anyone_caught := false
	while Time.get_ticks_msec() - t0 < 25000:
		saw_chase = saw_chase or don.state == HouseOwner.State.CHASE
		for peer: int in world._stats:
			anyone_caught = anyone_caught or int(world._stats[peer]["caught"]) > 0
		if anyone_caught:
			break
		await _wait(0.1)
	_check(don.wakes == 1, "Don Ramón se despertó")
	_check(saw_chase, "persiguió a alguien")
	_check(anyone_caught, "atrapó a alguien y lo echó")
	_check(world.police_coming(), "llamó a la policía (%.0f s)" % float(world.game["police"]))
	me.yaw = 0.0
	await _wait(0.6)
	if int(world._stats[1]["caught"]) > 0:
		_check(not HouseBuilder.in_house(me.global_position), "el anfitrión terminó afuera de la casa (%s)" % me.global_position.snapped(Vector3(0.1, 0.1, 0.1)))

	# 8. Irse con el camión.
	await _wait(1.0)
	me.teleport(Vector3(-13.0, 0.1, 16.8))
	await _wait(0.3)
	world._srv_leave(1)
	await _wait(0.5)
	_check(world.night_over() and not world.results.is_empty(), "terminó la noche al irse")
	_check(int(world.results.get("value", 0)) >= jewelry.value(), "el resultado cuenta el botín ($%d)" % world.results.get("value", 0))
	_check(world.results.get("players", []).size() == expect_clients + 1, "hay una fila por jugador")
	_say("premios: %s" % [world.results.get("titles", [])])

	# 9. ¿Los clientes ven lo mismo?
	if expect_clients > 0:
		await _compare_clients(true, 1)

	# 10. Otra noche.
	world.srv_next_night()
	await _wait(1.5)
	_check(int(world.game["night"]) == 2, "empezó la noche 2")
	_check(don.state == HouseOwner.State.SLEEP and don.alert == 0.0, "Don Ramón volvió a dormir")
	_check(don.sleep_mult > 1.0, "y tiene el sueño más liviano (x%.2f)" % don.sleep_mult)
	_check(world.entities.size() == HouseBuilder._items().size(), "volvieron todos los objetos")
	_check(world.results.is_empty() and not world.night_over(), "se borraron los resultados")
	if expect_clients > 0:
		await _compare_clients(false, 2)
	_finish()

## ¿Hay una hoja de puerta en el medio del vano? (Una cápsula del tamaño de un jugador.)
func _door_blocks(d: Door) -> bool:
	var shape := CapsuleShape3D.new()
	shape.radius = 0.3
	shape.height = 1.6
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = shape
	q.transform = Transform3D(Basis(), d.center() + Vector3(0, 1.0, 0))
	q.collision_mask = Config.L_DOOR
	return not world.get_world_3d().direct_space_state.intersect_shape(q, 1).is_empty()

func _compare_clients(results_expected: bool, night: int) -> void:
	await _wait(1.0)
	world.test_reports.clear()
	world._send_clients(&"rpc_test_request", [])
	await _wait(1.5)
	_check(world.test_reports.size() == expect_clients, "respondieron %d de %d clientes" % [world.test_reports.size(), expect_clients])
	var door_bits := 0
	for d in world.doors:
		door_bits |= (1 << d.door_id) if d.is_open else 0
	for peer: int in world.test_reports:
		var rep: Array = world.test_reports[peer]
		_check(int(rep[0]) == world.entities.size(), "el cliente tiene los mismos objetos (%d vs %d)" % [rep[0], world.entities.size()])
		_check(int(rep[1]) == door_bits, "el cliente ve las mismas puertas abiertas (%d vs %d)" % [rep[1], door_bits])
		_check(int(rep[2]) == int(world.homeowner.state), "el cliente ve a Don Ramón igual (%d vs %d)" % [rep[2], world.homeowner.state])
		_check(bool(rep[3]) == results_expected, "el cliente %s los resultados" % ("ve" if results_expected else "ya no ve"))
		_check(int(rep[4]) == night, "el cliente está en la noche %d" % night)

func _finish() -> void:
	Voice.debug_level = -1.0
	if _failures.is_empty():
		print("AUTOTEST OK")
	else:
		print("AUTOTEST FALLÓ: ", ", ".join(_failures))
	get_tree().quit(0 if _failures.is_empty() else 1)

# ---------------------------------------------------------------- cliente

func _run_client() -> void:
	Voice.debug_level = 0.0
	var start := Time.get_ticks_msec()
	while world.local_player == null:
		if Time.get_ticks_msec() - start > 20000:
			print("AUTOTEST FALLÓ: el cliente no entró a la partida")
			get_tree().quit(1)
			return
		await _wait(0.2)
	_say("dentro de la partida; hay %d objetos y %d puertas" % [world.entities.size(), world.doors.size()])
	# Pararse al lado del sillón (el anfitrión lo va a cargar con este jugador).
	world.local_player.teleport(Vector3(-1.6, 0.1, 3.0))
	# Quedarse esperando: el anfitrión pide los informes y después cierra (eso termina la sesión).
	await _wait(150.0)
	print("AUTOTEST FALLÓ: el cliente esperó demasiado")
	get_tree().quit(1)
