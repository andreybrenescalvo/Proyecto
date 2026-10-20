extends Node
## Recorrido de fotos para revisar cómo se ve el juego sin jugarlo a mano:
##
##   godot --path . -- --host --tour=/carpeta/de/fotos
##
## Pone la cámara en varios lugares de la casa, despierta a Don Ramón, sale manejando el camión
## (eso termina la noche) y guarda capturas. Con `--tour-quick` saca solo dos fotos del frente (para probar cambios rápido).

var world: World
var out_dir := ""
var _n := 0

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
	if OS.get_cmdline_user_args().has("--tour-drive"):
		await _drive_out()
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

## El lomo de burro de la calle, y salir manejando el camión (eso termina la noche).
func _drive_out() -> void:
	await _shot_from(Vector3(-21.0, 0.1, 19.5), Vector3(-28.0, 0.0, 21.0), "lomo_de_burro")
	var truck := world.truck
	world.local_player.teleport(truck.door_position("truck_drive"))
	await _wait(0.3)
	print("subirse: ", world.srv_seat(1, "truck_drive"), " chofer ", truck.driver)
	await _wait(1.0)
	await _shot("al_volante")
	await _drive(1.0, 1.8)
	await _shot("manejando")
	var t0 := Time.get_ticks_msec()
	while not world.night_over() and Time.get_ticks_msec() - t0 < 20000:
		await _drive(1.0, 0.25)
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
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	_n += 1
	var path := "%s/%02d_%s.png" % [out_dir, _n, label]
	img.save_png(path)
	print("foto: ", path)
