extends Node
## Recorrido de fotos para revisar cómo se ve el juego sin jugarlo a mano:
##
##   godot --path . -- --host --tour=/carpeta/de/fotos
##
## Pone la cámara en varios lugares de la casa y de la ciudad, despierta a Don Ramón, maneja el
## camión hasta el Galpón 7 (eso termina la noche) y guarda capturas. Con `--tour-quick` saca solo
## dos fotos del frente (para probar cambios rápido); con `--tour-city`, solo la ciudad; con
## `--tour-drive`, solo el viaje en camión; con `--tour-ui`, las pantallas de la interfaz (menú,
## pausa, cuadro de avisos, computadora del galpón y resultados) para revisar la spec de UX.

var world: World
var out_dir := ""
var _n := 0
var _keep_notices := false   # --tour-ui: no borrar el cuadro de avisos antes de cada foto

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(out_dir)
	Voice.debug_level = 0.0
	await _wait(2.0)
	var don := world.homeowner
	if OS.get_cmdline_user_args().has("--tour-quick"):
		world._show_style(77)
		await _shot_from(Vector3(-3.0, 0.1, 17.0), Vector3(-4.0, 2.0, 6.0), "rapido_frente")
		await _shot_from(Vector3(-15.0, 0.1, 20.5), Vector3(-4.0, 1.8, 6.0), "rapido_casa_y_camion")
		get_tree().quit(0)
		return
	if OS.get_cmdline_user_args().has("--tour-ui"):
		await _ui()
		print("TOUR OK: %d fotos en %s" % [_n, out_dir])
		get_tree().quit(0)
		return
	if OS.get_cmdline_user_args().has("--tour-drive"):
		await _drive_out()
		get_tree().quit(0)
		return
	if OS.get_cmdline_user_args().has("--tour-walls"):
		world.local_player.flashlight_on = true
		world.local_player._update_light()
		world.srv_set_door(0, true, 0)
		await _wait(0.5)
		await _shot_from(Vector3(-4.0, 0.1, 2.0), Vector3(-8.0, 1.4, 2.0), "pared_sala_de_cerca")
		await _shot_from(Vector3(-2.0, 0.1, 3.0), Vector3(-8.0, 1.2, 0.5), "pared_sala_de_costado")
		await _shot_from(Vector3(-4.0, 0.1, -2.5), Vector3(-4.0, 1.4, -6.0), "pared_cocina")
		await _shot_from(Vector3(1.0, 0.1, -1.0), Vector3(1.0, 1.2, -6.0), "pared_pasillo")
		await _shot_from(Vector3(5.0, 0.1, 2.0), Vector3(8.0, 1.4, 1.0), "pared_dormitorio")
		await _shot_from(Vector3(-4.0, 0.1, 9.0), Vector3(-4.0, 1.5, 6.0), "fachada_de_cerca")
		get_tree().quit(0)
		return
	if OS.get_cmdline_user_args().has("--tour-warehouse"):
		await _warehouse()
		print("TOUR OK: %d fotos en %s" % [_n, out_dir])
		get_tree().quit(0)
		return
	if OS.get_cmdline_user_args().has("--tour-city"):
		await _city()
		print("TOUR OK: %d fotos en %s" % [_n, out_dir])
		get_tree().quit(0)
		return
	# Los mudanceros (los de los demás jugadores, como se los ve en el juego).
	var crew: Array[CharacterModel] = []
	for i in CharacterModel.PLAYER_MODELS.size():
		var m := CharacterModel.create(CharacterModel.PLAYER_MODELS[i])
		world.add_child(m)
		m.global_position = Vector3(-4.6 + i * 1.0, 0.05, 16.4)
		m.rotation.y = PI + (i - 1) * 0.25
		m.play(["Idle", "Idle_Torch", "Walk"][i])
		crew.append(m)
	await _shot_from(Vector3(-3.6, 0.1, 19.8), Vector3(-3.6, 1.0, 16.4), "los_mudanceros")
	for m in crew:
		m.queue_free()
	# Afuera: la casa, el camión en la calle y el barrio.
	await _shot_from(Vector3(-15.0, 0.1, 20.5), Vector3(-4.0, 1.8, 6.0), "casa_y_camion")
	await _shot_from(Vector3(-3.0, 0.1, 17.0), Vector3(-4.0, 2.0, 6.0), "frente_de_la_casa")
	await _shot_from(Vector3(-5.6, 0.1, 18.7), Vector3(-11.0, 1.0, 18.7), "camion_por_dentro")
	await _shot_from(Vector3(6.0, 0.1, 19.0), Vector3(-14.0, 2.5, 30.0), "barrio")
	await _city()
	# Adentro, con la linterna.
	world.srv_set_door(0, true, 0)
	await _wait(0.6)
	await _shot_from(Vector3(-4.0, 0.1, 9.0), Vector3(-4.0, 1.2, 2.0), "puerta_de_calle")
	await _shot_from(Vector3(-0.8, 0.1, 0.8), Vector3(-7.0, 0.8, 3.5), "sala")
	await _shot_from(Vector3(-0.8, 0.1, -0.8), Vector3(-5.0, 0.9, -5.5), "cocina")
	await _shot_from(Vector3(1.0, 0.1, -5.0), Vector3(1.0, 1.2, 4.0), "pasillo")
	world.srv_set_door(2, true, 0)
	world.srv_set_door(4, true, 0)
	await _wait(0.8)
	await _shot_from(Vector3(1.0, 0.1, 2.4), Vector3(7.0, 0.8, 4.2), "dormitorio_dormido")
	await _shot_from(Vector3(5.0, 0.1, 2.0), Vector3(7.2, 0.9, 4.2), "don_ramon_de_cerca")
	await _shot_from(Vector3(2.6, 0.1, -0.6), Vector3(7.5, 0.8, -1.5), "estudio")
	await _shot_from(Vector3(2.6, 0.1, -4.5), Vector3(7.5, 0.8, -4.5), "baño")
	# Otro estilo de casa (como si fuera otra noche).
	world._show_style(4242)
	await _wait(0.3)
	await _shot_from(Vector3(-3.0, 0.1, 17.0), Vector3(-4.0, 2.0, 6.0), "otro_estilo_frente")
	await _shot_from(Vector3(-0.8, 0.1, 0.8), Vector3(-7.0, 0.8, 3.5), "otro_estilo_sala")
	world._show_style(77)
	await _wait(0.3)
	await _shot_from(Vector3(-3.0, 0.1, 17.0), Vector3(-4.0, 2.0, 6.0), "tercer_estilo_frente")
	await _shot_from(Vector3(5.0, 0.1, 2.0), Vector3(7.2, 0.9, 4.2), "tercer_estilo_dormitorio")
	# Despertarlo y dejar que salga a buscar.
	world.local_player.flashlight_on = true
	world.local_player.teleport(Vector3(-3.0, 0.1, 1.0))
	don.alert = Config.ALERT_WAKE
	await _wait(2.2)
	await _shot_from(Vector3(3.0, 0.1, 1.2), Vector3(6.0, 1.3, 4.2), "se_desperto")
	await _wait(1.5)
	await _shot_from(Vector3(1.0, 0.1, -3.0), Vector3(1.5, 1.5, 3.0), "te_busca")
	await _drive_out()
	print("TOUR OK: %d fotos en %s" % [_n, out_dir])
	get_tree().quit(0)

## La ciudad: desde arriba y a pie por cada barrio, la avenida, la plaza y la zona industrial.
func _city() -> void:
	await _aerial(Vector3(60.0, 95.0, 150.0), Vector3(-20.0, 0.0, 40.0), "ciudad_desde_arriba")
	await _aerial(Vector3(-150.0, 70.0, 110.0), Vector3(-260.0, 0.0, 20.0), "zona_industrial_desde_arriba")
	await _aerial(Vector3(25.0, 30.0, 45.0), Vector3(-5.0, 0.0, 10.0), "lo_de_don_ramon_desde_arriba")
	await _shot_from(Vector3(-20.0, 0.1, 76.5), Vector3(-60.0, 2.5, 82.0), "avenida")
	await _shot_from(Vector3(30.0, 0.1, 76.5), Vector3(70.0, 3.0, 70.0), "estacion_de_servicio")
	await _shot_from(Vector3(-5.0, 0.1, 90.0), Vector3(-5.0, 3.0, 112.0), "plaza")
	await _shot_from(Vector3(-100.0, 0.1, 25.5), Vector3(-140.0, 2.0, 18.0), "villa_esperanza")
	await _shot_from(Vector3(100.0, 0.1, 25.5), Vector3(130.0, 2.0, 15.0), "las_lomas")
	await _shot_from(Vector3(-45.0, 0.1, 16.5), Vector3(-60.0, 2.0, 40.0), "esquina_san_jose")
	await _shot_from(Vector3(-175.0, 0.1, 76.0), Vector3(-200.0, 2.0, 81.0), "paso_a_nivel")
	await _shot_from(Vector3(-258.0, 0.1, 30.0), Vector3(-280.0, 3.0, 0.0), "galpon_7")
	await _shot_from(Vector3(-280.5, 0.1, 2.0), Vector3(-294.0, 1.0, -2.0), "galpon_7_por_dentro")

## Adentro del Galpón 7: el taller, la oficina y un mudancero escribiendo en la computadora.
func _warehouse() -> void:
	var c := CityBuilder.WAREHOUSE
	await _shot_from(Vector3(c.x + 10.5, 0.1, c.z + 1.0), Vector3(c.x - 6.0, 1.5, c.z + 3.0), "galpon_taller")
	await _shot_from(Vector3(c.x + 9.0, 0.1, c.z - 2.0), Vector3(c.x - 6.0, 1.0, c.z - 7.0), "galpon_oficina")
	await _shot_from(Vector3(c.x - 3.0, 0.1, c.z - 1.0), Vector3(c.x - 12.0, 3.5, c.z), "galpon_cartel")
	var typist := CharacterModel.create(CharacterModel.PLAYER_MODELS[1])
	world.add_child(typist)
	typist.global_position = CityBuilder.COMPUTER_SEAT + Vector3(0, Player.COMPUTER_SEAT_HEIGHT, 0)
	typist.play("Sitting_Idle")
	typist.set_typing(true)
	await _shot_from(CityBuilder.COMPUTER_SEAT + Vector3(1.6, 0.0, 0.9), CityBuilder.COMPUTER_DESK + Vector3(0, 0.9, 0.3), "escribiendo")
	await _shot_from(CityBuilder.COMPUTER_SEAT + Vector3(-1.4, 0.0, 0.3), CityBuilder.COMPUTER_SEAT + Vector3(0, 0.8, -0.3), "escribiendo_de_costado")
	typist.queue_free()

## Las pantallas de la interfaz (design/ux/menus-y-venta.md): menú (PC, con error y web), cuadro
## de avisos (normal, urgente, solo ayuda), la casa con la mira, pausa, computadora del galpón
## (escritorio, Mercado lleno, con algo vendido, camión afuera, las dos confirmaciones) y los
## resultados (vendido, cancelado, y los cuatro motivos con la tabla llena).
func _ui() -> void:
	_keep_notices = true
	var hud := world.hud
	var main := get_parent()
	var menu: Menu = main.get("menu")
	menu.open("")
	await _wait(0.8)
	await _shot("ui_menu")
	menu.open("Se perdió la conexión con el anfitrión.")
	await _wait(0.6)
	await _shot("ui_menu_con_error")
	menu.close()
	var web := Menu.new()
	web.web_preview = true
	main.add_child(web)
	await _wait(0.8)
	await _shot("ui_menu_web")
	web.queue_free()
	await _wait(0.5)
	# En la casa, mirando algo que se puede agarrar (mira en anillo, barra de Don Ramón y ayuda).
	hud.hide_banner()
	var target: Entity = null
	for e: Entity in world.entities.values():
		if HouseBuilder.in_house(e.global_position) and e.global_position.y < 1.2 and not e.is_heavy():
			target = e
			break
	if target:
		var at := target.global_position
		for dir: Vector3 in [Vector3(1.3, 0, 0), Vector3(-1.3, 0, 0), Vector3(0, 0, 1.3), Vector3(0, 0, -1.3)]:
			await _shot_from_quiet(Vector3(at.x + dir.x, 0.1, at.z + dir.z), at)
			if String(world.local_player.look.get("kind", "")) == "entity":
				break
	world.message.emit("Noche 1: la casa de Don Ramón. Carguen al menos $1800 y lleven el camión al Galpón 7 antes de que amanezca.", World.MSG_NOTICE)
	world.message.emit("Al camión: lámpara ($60).", World.MSG_SMALL)
	await _wait(0.6)
	await _shot("ui_casa_aviso_y_ayuda")
	# Pausa y su confirmación.
	hud.hide_banner()
	hud.set_paused(true)
	await _wait(0.5)
	await _shot("ui_pausa")
	hud._ask_leave_from_pause()
	await _wait(0.5)
	await _shot("ui_pausa_confirmar_salida")
	hud.set_paused(false)
	await _wait(0.4)
	# Manejando: aviso normal con otro en fila, urgente y solo ayuda.
	var truck := world.truck
	world.local_player.teleport(truck.door_position("truck_drive"))
	await _wait(0.3)
	world.srv_seat(1, "truck_drive")
	await _wait(0.8)
	hud.hide_banner()
	world.message.emit("¡Salieron del barrio! Ahora, al Galpón 7: sigan la flecha.", World.MSG_NOTICE)
	world.message.emit("El Flaco los espera en el Galpón 7, en la zona industrial.", World.MSG_NOTICE)
	await _wait(0.6)
	await _shot("ui_aviso_normal")
	world.message.emit("Don Ramón llamó a la policía: llega en 90 segundos. ¡Carguen lo que puedan y váyanse!", World.MSG_URGENT)
	await _wait(0.7)
	await _shot("ui_aviso_urgente")
	hud.hide_banner()
	await _wait(0.3)
	await _shot("ui_solo_ayuda")
	world.srv_seat(1, "exit")
	await _wait(0.5)
	# El camión en el galpón con cosas en la caja.
	truck.park(Vector3(-288.5, 0, 0), -90.0)
	await _wait(0.6)
	var spots := [Vector3(0, 0.95, 1.2), Vector3(-0.6, 0.75, -0.9), Vector3(0.6, 0.65, -0.9), Vector3(-0.6, 0.7, 0.1),
			Vector3(0.6, 0.7, 0.1), Vector3(0, 0.7, -0.4), Vector3(0, 0.9, 0.6)]
	for e: Entity in world.entities.values():
		if spots.is_empty():
			break
		if e.is_heavy() or e.value() <= 0:
			continue
		e.global_transform = Transform3D(truck.global_transform.basis, truck.to_global(spots.pop_front()))
		e.linear_velocity = Vector3.ZERO
		e.ignore_next_impacts(30)
	await _wait(1.5)
	world.local_player.teleport(CityBuilder.COMPUTER_SEAT + Vector3(0, 0.1, 0.9))
	await _wait(0.4)
	print("sentarse en la compu: ", world.srv_computer(1, "sit"))
	await _wait(1.0)
	var pc := hud.computer()
	await _shot("ui_compu_escritorio")
	pc.open_app("market")
	await _wait(0.6)
	await _shot("ui_mercado_lleno")
	if not pc._mk_order.is_empty():
		pc._sell(pc._mk_order[0])
		await _wait(0.15)
		await _shot("ui_mercado_vendiendo")
		await _wait(1.0)
	await _shot("ui_mercado_con_algo_vendido")
	pc.ask_close_night()
	await _wait(0.6)
	await _shot("ui_confirmar_sin_cuota")
	pc._close_modal()
	truck.park(HouseBuilder.TRUCK_POS, HouseBuilder.TRUCK_ROT)
	await _wait(1.2)
	world.message.emit("¡Amanece en 1 minuto! Cierren la noche en la computadora.", World.MSG_URGENT)
	await _wait(0.6)
	await _shot("ui_mercado_camion_afuera")
	# Con la cuota cumplida (para la foto se baja la cuota a lo vendido).
	world.game["quota"] = maxi(int(world.game.get("sold", 0)), 1)
	world.game_changed.emit()
	pc.ask_close_night()
	await _wait(0.6)
	await _shot("ui_confirmar_con_cuota")
	world.request_close_night()
	await _wait(2.0)
	await _shot("ui_resultados_vendido")
	# Otra noche: se sienta y cierra sin vender nada (cancelado).
	world.srv_next_night()
	await _wait(1.5)
	world.local_player.teleport(CityBuilder.COMPUTER_SEAT + Vector3(0, 0.1, 0.9))
	await _wait(0.4)
	world.srv_computer(1, "sit")
	await _wait(0.6)
	world.request_close_night()
	await _wait(2.0)
	await _shot("ui_resultados_cancelado")
	# Tabla llena: 4 jugadores, 5 premios, 20 objetos, con cada motivo.
	for reason in ["sold", "police", "dawn"]:
		hud._show_results(_fake_results(reason))
		await _wait(1.8)
		await _shot("ui_resultados_lleno_" + reason)

func _fake_results(reason: String) -> Dictionary:
	var names := ["Televisor", "Microondas", "Lámpara", "Jarrón", "Notebook", "Reloj", "Joyero", "Consola", "Radio", "Silla",
			"Cuadro", "Tostadora", "Licuadora", "Bicicleta", "Ventilador", "Espejo", "Plancha", "Cafetera", "Velador", "Alfombra"]
	var items := []
	for i in names.size():
		items.append([names[i], 600 - i * 25, i % 4])
	var sold := items if reason == "sold" else []
	return {"reason": reason, "night": 3, "value": 2950 if reason == "sold" else 0, "quota": 2600,
			"stars": 1 if reason == "sold" else 0, "fines": 300 if reason == "sold" else 0, "total": 2650 if reason == "sold" else 0,
			"bank": 5400, "wakes": 2,
			"players": [{"name": "Ana", "noise": 12, "broken": 0, "loot": 800, "caught": 0, "wakes": 0, "left": false},
				{"name": "Beto", "noise": 48, "broken": 3, "loot": 650, "caught": 1, "wakes": 1, "left": true},
				{"name": "Caro", "noise": 20, "broken": 1, "loot": 900, "caught": 0, "wakes": 1, "left": false},
				{"name": "Dani", "noise": 5, "broken": 0, "loot": 600, "caught": 0, "wakes": 0, "left": false}],
			"titles": [["El más ruidoso", "Beto"], ["Despertador humano", "Beto"], ["Manos de mantequilla", "Beto"],
				["Imán de abuelos", "Beto"], ["Empleado del mes", "Caro"]],
			"sold": sold, "left_in_truck": [] if reason == "sold" else items}

## Como `_shot_from`, pero sin sacar la foto (para acomodar al jugador).
func _shot_from_quiet(from: Vector3, target: Vector3) -> void:
	var me := world.local_player
	me.teleport(from)
	var eye := from + Vector3(0, Player.EYE_STAND, 0)
	var d := target - eye
	me.yaw = atan2(-d.x, -d.z)
	me.pitch = atan2(d.y, Vector2(d.x, d.z).length())
	await _wait(0.5)

## Foto desde una cámara en el aire.
func _aerial(from: Vector3, target: Vector3, label: String) -> void:
	var cam := Camera3D.new()
	cam.fov = 60.0
	cam.far = 600.0
	world.add_child(cam)
	cam.global_position = from
	cam.look_at(target, Vector3.UP)
	cam.make_current()
	await _wait(0.6)
	await _shot(label)
	cam.queue_free()
	world.local_player.camera.make_current()

## El lomo de burro de la calle, y manejar el camión hasta el Galpón 7 (eso termina la noche).
func _drive_out() -> void:
	await _shot_from(Vector3(-21.0, 0.1, 19.5), Vector3(-28.0, 0.0, 21.0), "lomo_de_burro")
	var truck := world.truck
	world.local_player.teleport(truck.door_position("truck_drive"))
	await _wait(0.3)
	print("subirse: ", world.srv_seat(1, "truck_drive"), " chofer ", truck.driver)
	await _wait(1.0)
	await _shot("al_volante")
	# Cargar unas cuantas cosas en la caja (para que el Flaco tenga qué comprar).
	var spots := {"safe": Vector3(0, 0.95, 1.2), "jewelry": Vector3(-0.6, 0.75, -0.9), "laptop": Vector3(0.6, 0.65, -0.9),
			"console": Vector3(-0.6, 0.7, 0.1), "watch": Vector3(0.6, 0.7, 0.1)}
	for e: Entity in world.entities.values():
		if spots.has(e.item_id):
			e.global_transform = Transform3D(truck.global_transform.basis, truck.to_global(spots[e.item_id]))
			e.linear_velocity = Vector3.ZERO
			e.ignore_next_impacts(30)
			spots.erase(e.item_id)
	await _wait(1.5)
	var pilot := Autopilot.new(Autopilot.ROUTE_TO_WAREHOUSE)
	var shots := {3: "manejando", 8: "por_la_avenida", 13: "por_la_zona_industrial", 16: "entrando_al_galpon"}
	var t0 := Time.get_ticks_msec()
	var frames := 0
	while not world.night_over() and frames < 150 * Engine.physics_ticks_per_second:
		frames += 1
		var cmd := pilot.step(truck)
		world._srv_drive_input(truck.driver, cmd[0], cmd[1], cmd[2])
		await get_tree().physics_frame
		if shots.has(pilot.index):
			var label: String = shots[pilot.index]
			shots.erase(pilot.index)
			await _shot(label)
	print("viaje: %.0f s, camión en %s" % [(Time.get_ticks_msec() - t0) / 1000.0, truck.global_position.snapped(Vector3.ONE)])
	await _wait(1.0)
	await _shot("resultados")

## Maneja el camión un rato (no hay teclado: se le pasa el acelerador a mano).
func _drive(throttle: float, seconds: float) -> void:
	var t := 0.0
	while t < seconds:
		world._srv_drive_input(world.truck.driver, throttle, 0.0, false)
		await get_tree().physics_frame
		t += 1.0 / Engine.physics_ticks_per_second

func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout

## Pone al jugador en `from` mirando hacia `target` y saca una foto.
func _shot_from(from: Vector3, target: Vector3, label: String) -> void:
	var me := world.local_player
	me.teleport(from)
	var eye := from + Vector3(0, Player.EYE_STAND, 0)
	var d := target - eye
	me.yaw = atan2(-d.x, -d.z)
	me.pitch = atan2(d.y, Vector2(d.x, d.z).length())
	await _wait(0.6)
	await _shot(label)

func _shot(label: String) -> void:
	if not _keep_notices:
		world.hud.hide_banner()
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	_n += 1
	var path := "%s/%02d_%s.png" % [out_dir, _n, label]
	img.save_png(path)
	print("foto: %s  (%d dibujos, %d objetos)" % [path, RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME)])
