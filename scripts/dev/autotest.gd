extends Node
## Prueba automática de punta a punta, pensada para correr sin pantalla:
##
##   godot --headless --path . -- --host --autotest --expect=1
##   godot --headless --path . -- --join=127.0.0.1 --autotest
##
## El anfitrión recorre las mecánicas principales (el dueño oye la voz y las puertas, cargar el
## camión, romper algo frágil, cargar el sillón entre dos, despertarlo, que persiga y eche a
## alguien, manejar el camión hasta el Galpón 7 y vender, otra noche, la policía) y compara lo que
## ve cada cliente. Imprime "AUTOTEST OK" o
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

	# 8. El camión: subirse a manejar, arrancar, frenar, un acompañante, los lomos de burro (lo de
	# la caja se golpea) y manejar por la ciudad hasta el Galpón 7, donde el reducidor compra todo.
	# Al que echaron no se puede subir enseguida: esperar a que se le pase.
	var t_ej := Time.get_ticks_msec()
	while world.players.values().any(func(p: Player) -> bool: return p.ejected) and Time.get_ticks_msec() - t_ej < 8000:
		await _wait(0.2)
	var truck := world.truck
	var tv := _find("tv")
	var tv_id := tv.entity_id
	tv.global_transform = Transform3D(Basis(), truck.to_global(Vector3(0, 1.1, -1.2)))
	tv.linear_velocity = Vector3.ZERO
	await _wait(1.0)
	_check(world._loaded.has(tv_id), "el televisor quedó cargado en la caja")
	me.teleport(truck.door_position("truck_drive"))
	await _wait(0.3)
	_check(world.srv_seat(1, "truck_drive"), "el anfitrión se subió a manejar")
	await _wait(0.2)
	_check(truck.driver == 1 and me.seat == 0, "quedó al volante (asiento %d)" % me.seat)
	_check(not world.srv_seat(1, "truck_drive"), "no se puede subir dos veces")
	var other_peer := 0
	if expect_clients > 0:
		other_peer = world.players.keys().filter(func(p: int) -> bool: return p != 1)[0]
		world.rpc_teleport.rpc_id(other_peer, truck.door_position("truck_ride"))
		await _wait(0.8)
		_check(world.srv_seat(other_peer, "truck_ride"), "el cliente se subió de acompañante")
		await _wait(0.2)
		_check(int(truck.seats.get(other_peer, -1)) == 1, "va en el asiento del acompañante")
	var start_x := truck.global_position.x
	# Arrancar y frenar en seco (antes del primer lomo de burro).
	await _drive(1.0, 0.0, false, 1.6)
	_check(truck.speed > 5.0, "el camión arranca (%.1f m/s)" % truck.speed)
	_check(truck.global_position.x < start_x - 3.0, "y va hacia la salida del barrio (x %.1f)" % truck.global_position.x)
	_check(absf(truck.global_position.z - HouseBuilder.TRUCK_POS.z) < 1.0, "derecho por la calle (z %.1f)" % truck.global_position.z)
	_check(truck.global_transform.basis.y.y > 0.9, "sin volcar")
	_check(not world.srv_seat(1, "exit"), "andando no se puede bajar")
	await _drive(0.0, 0.0, true, 2.0)
	_check(truck.speed < 0.6, "con el freno de mano se detiene (%.2f m/s)" % truck.speed)
	_check(world.entities.has(tv_id), "un frenazo despacio no rompe el televisor")
	_check(world.srv_seat(1, "exit"), "parado se puede bajar")
	await _wait(0.2)
	_check(truck.driver == 0 and me.seat == -1, "se bajó del camión")
	_check(me.global_position.distance_to(truck.exit_position(0)) < 1.0, "quedó parado al lado de la puerta")
	await _wait(1.5)
	_check(truck.speed < 0.2, "sin nadie al volante queda frenado")
	me.teleport(truck.door_position("truck_drive"))
	await _wait(0.3)
	_check(world.srv_seat(1, "truck_drive"), "se volvió a subir a manejar")
	# Despacio por el primer lomo de burro: no se rompe nada.
	var bump: float = CityBuilder.SPEED_BUMPS_X[0]
	var t_slow := Time.get_ticks_msec()
	while truck.global_position.x > bump - 2.5 and Time.get_ticks_msec() - t_slow < 20000:
		await _drive(1.0 if truck.speed < 2.0 else 0.0, 0.0, false, 0.05)
	_say("sacudones despacio: %s" % [world.jolts])
	_check(truck.global_position.x < bump - 2.5, "pasó el lomo de burro despacio")
	_check(world.entities.has(tv_id), "despacio, el televisor pasa entero")
	# A toda velocidad por el segundo: lo de la caja salta, lo frágil se rompe y lo demás se golpea.
	var bump2: float = CityBuilder.SPEED_BUMPS_X[1]
	var t_fast := Time.get_ticks_msec()
	while truck.global_position.x > bump2 - 4.0 and Time.get_ticks_msec() - t_fast < 15000:
		await _drive(1.0, 0.0, false, 0.05)
	_say("sacudones rápido: %s" % [world.jolts])
	_check(world.cargo_hits > 0, "el lomo de burro sacudió lo de la caja (%d golpes)" % world.cargo_hits)
	_check(not world.entities.has(tv_id), "a toda velocidad, el lomo de burro rompió el televisor")
	_check(jewelry.dents() >= 1 and jewelry.value() < int(jewelry.data["value"]), "y el joyero quedó golpeado: vale $%d" % jewelry.value())
	await _wait(0.4)
	_check(int(world.game["truck"]) == jewelry.value(), "el camión cuenta el precio con golpes ($%d)" % world.game["truck"])
	_check(not world.night_over(), "salir del barrio ya no termina la noche")
	# Las cuentas de la venta (sin manejar): sin cuota no se cobra, y si amanece o llega la policía, tampoco.
	_check(World.payout("sold", 100, 1800, 0)["reason"] == "cancel" and World.payout("sold", 100, 1800, 0)["total"] == 0, "vender sin llegar a la cuota cancela el encargo")
	_check(World.payout("sold", 2000, 1800, 300)["total"] == 1700, "vendiendo con la cuota se cobra todo menos las multas")
	_check(World.payout("dawn", 5000, 1800, 0)["total"] == 0 and World.payout("police", 5000, 1800, 0)["total"] == 0, "si amanece o llega la policía se pierde todo")
	# Para probar la venta, esta noche la cuota es más baja (solo llevan el joyero).
	world.game["quota"] = 100
	var pilot := Autopilot.new(Autopilot.ROUTE_TO_WAREHOUSE)
	var away_seen := false
	var t_drive := Time.get_ticks_msec()
	var last_index := -1
	while not pilot.done() and not world.night_over() and Time.get_ticks_msec() - t_drive < 120000:
		var cmd := pilot.step(truck)
		world._srv_drive_input(truck.driver, cmd[0], cmd[1], cmd[2])
		await get_tree().physics_frame
		if pilot.index != last_index:
			last_index = pilot.index
			_say("  rumbo al punto %d (camión en %s, %.1f m/s, joyero con %d golpes)" % [pilot.index, truck.global_position.snapped(Vector3(0.1, 0.1, 0.1)), truck.speed, jewelry.dents()])
		away_seen = away_seen or bool(world.game.get("away", false))
		if truck.global_transform.basis.y.y < 0.7:
			break
	_say("viaje al galpón: %.0f s, camión en %s, punto %d de %d" % [(Time.get_ticks_msec() - t_drive) / 1000.0,
			truck.global_position.snapped(Vector3(0.1, 0.1, 0.1)), pilot.index, pilot.route.size()])
	_check(away_seen, "al alejarse avisa que salieron del barrio")
	_check(truck.global_transform.basis.y.y > 0.9, "el camión llegó sin volcar")
	await _drive(0.0, 0.0, true, 1.5)
	_check(CityBuilder.in_warehouse_zone(truck.global_position), "el camión está adentro del Galpón 7")
	_check(not world.night_over(), "llegar al galpón ya no termina la noche (se vende en la computadora)")
	await _wait(0.5)
	_check(bool(world.game.get("truck_in", false)), "la partida sabe que el camión está adentro")
	var cargo: Array = world.cargo_for_sale()
	_check(cargo.size() == 1 and int(cargo[0][0]) == jewelry.entity_id, "la computadora ve el joyero en la caja (%s)" % [cargo])
	# Bajarse e ir a la computadora.
	_check(world.srv_seat(1, "exit"), "se bajó del camión en el galpón")
	await _wait(0.3)
	_check(not world.srv_computer(1, "sit"), "desde lejos no se puede usar la computadora")
	me.teleport(CityBuilder.COMPUTER_SEAT + Vector3(0, 0.1, 1.2))
	await _wait(0.3)
	_check(world.srv_computer(1, "sit"), "se sentó en la computadora")
	await _wait(0.3)
	_check(world.computer_user() == 1 and me.at_computer, "quedó sentado en la computadora")
	_check(me.global_position.distance_to(CityBuilder.COMPUTER_SEAT) < 0.6, "está en la silla (%s)" % me.global_position.snapped(Vector3(0.1, 0.1, 0.1)))
	_check(me.model.current == "Sitting_Idle", "sentado (%s)" % me.model.current)
	if expect_clients > 0:
		_check(not world.srv_computer(other_peer, "sit"), "si está ocupada, otro no se puede sentar")
	# Levantarse y volver a sentarse.
	_check(world.srv_computer(1, "stand"), "se levantó de la computadora")
	await _wait(0.3)
	_check(world.computer_user() == 0 and not me.at_computer, "la computadora quedó libre")
	_check(world.srv_computer(1, "sit"), "se volvió a sentar")
	await _wait(0.3)
	var jewel_value := jewelry.value()
	var jewel_id := jewelry.entity_id
	_check(world.srv_sell(1, PackedInt32Array([jewel_id])) == jewel_value, "le vendió el joyero al Flaco ($%d)" % jewel_value)
	await _wait(0.5)
	_check(not world.entities.has(jewel_id), "el joyero ya no está en el camión")
	_check(int(world.game.get("sold", 0)) == jewel_value and world.cargo_for_sale().is_empty(), "lo vendido suma y la caja quedó vacía")
	_check(world.srv_sell(1, PackedInt32Array()) == 0, "no se puede vender dos veces")
	_check(world.srv_close_night(1), "cerró la noche desde la computadora")
	await _wait(0.5)
	_check(world.night_over() and not world.results.is_empty(), "terminó la noche en el galpón")
	_check(world.computer_user() == 0, "al terminar, la computadora queda libre")
	_check(world.results.get("reason", "") == "sold", "el reducidor compró todo (%s)" % world.results.get("reason", ""))
	var sold: Array = world.results.get("sold", [])
	_check(sold.size() == 1 and sold[0][0] == "Joyero" and int(sold[0][2]) >= 1, "la lista de lo vendido tiene el joyero golpeado (%s)" % [sold])
	_check(int(world.results.get("total", -1)) == jewel_value and int(world.game.get("bank", 0)) == jewel_value, "cobraron el joyero con el descuento ($%d)" % world.results.get("total", -1))
	_check(world.results.get("players", []).size() == expect_clients + 1, "hay una fila por jugador")
	var left_rows: Array = (world.results.get("players", []) as Array).filter(func(r: Dictionary) -> bool: return r["left"])
	_check(left_rows.is_empty(), "nadie quedó atrás (todos en el galpón)")
	_say("premios: %s" % [world.results.get("titles", [])])
	await _wait(2.0)
	_check(truck.speed < 0.5, "al terminar la noche el camión queda frenado (%.2f m/s)" % truck.speed)

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
	_check(world.truck.global_position.distance_to(HouseBuilder.TRUCK_POS) < 0.5 and world.truck.seats.is_empty(), "el camión volvió a estacionarse vacío")
	_check(me.seat == -1, "el anfitrión ya no está sentado")
	if expect_clients > 0:
		await _compare_clients(false, 2)
	# 11. La policía llega con el camión todavía en el barrio: se pierde todo.
	var bank := int(world.game.get("bank", 0))
	world.game["police"] = 0.3
	await _wait(1.0)
	_check(world.night_over() and world.results.get("reason", "") == "police", "la policía los agarró con el camión en el barrio (%s)" % world.results.get("reason", ""))
	_check(int(world.results.get("total", -1)) == 0 and int(world.game.get("bank", -1)) == bank, "y esa noche no se cobra nada")
	# 12. Irse del barrio sin la cuota: la misión se cancela sola y el anfitrión termina la noche.
	world.srv_next_night()
	await _wait(1.0)
	world.truck.park(Vector3(-40.0, 0.0, 81.0), -90.0)
	await _wait(0.6)
	_check(not world.mission_canceled(), "a 81 m de la casa todavía no se cancela (%.0f m)" % world.truck.global_position.length())
	world.truck.park(Vector3(-120.0, 0.0, 81.0), -90.0)
	await _wait(0.6)
	_check(world.mission_canceled() and not world.night_over(), "lejos y sin la cuota, la misión se cancela pero la noche sigue")
	_check(not world.srv_computer(1, "sit"), "con la misión cancelada no se puede vender")
	_check(world.srv_finish_canceled(), "el anfitrión termina la noche")
	await _wait(0.5)
	_check(world.results.get("reason", "") == "cancel" and bool(world.results.get("left_without_quota", false)), "resultado: misión cancelada por irse sin la cuota")
	_check(int(world.results.get("total", -1)) == 0, "y no se cobra nada")
	_finish()

## ¿Hay una hoja de puerta en el medio del vano? (Una cápsula del tamaño de un jugador.)
## Maneja el camión durante `seconds` (en la prueba no hay teclado: se le pasa el mando a mano).
func _drive(throttle: float, steer: float, handbrake: bool, seconds: float) -> void:
	var t := 0.0
	while t < seconds:
		world._srv_drive_input(world.truck.driver, throttle, steer, handbrake)
		await get_tree().physics_frame
		t += 1.0 / Engine.physics_ticks_per_second

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
		var tpos: Vector3 = rep[5]
		_check(tpos.distance_to(world.truck.global_position) < 1.0, "el cliente ve el camión en el mismo lugar (%.2f m)" % tpos.distance_to(world.truck.global_position))
		_check(rep[6] == world.truck.seats, "el cliente ve los mismos asientos (%s vs %s)" % [rep[6], world.truck.seats])

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
	await _wait(400.0)
	print("AUTOTEST FALLÓ: el cliente esperó demasiado")
	get_tree().quit(1)
