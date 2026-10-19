extends Node
## Recorrido de fotos para revisar cómo se ve el juego sin jugarlo a mano:
##
##   godot --path . -- --host --tour=/carpeta/de/fotos
##
## Pone la cámara en varios lugares de la casa, despierta a Don Ramón, termina la noche
## y guarda capturas.

var world: World
var out_dir := ""
var _n := 0

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(out_dir)
	Voice.debug_level = 0.0
	await _wait(2.0)
	var don := world.homeowner
	# Afuera: la casa y el camión.
	await _shot_from(Vector3(-11.0, 0.1, 15.5), Vector3(-2.0, 1.6, 6.0), "casa_y_camion")
	await _shot_from(Vector3(-4.0, 0.1, 7.0), Vector3(-4.0, 1.0, 12.0), "camion_por_dentro")
	# Adentro, con la linterna.
	world.srv_set_door(0, true, 0)
	await _wait(0.6)
	await _shot_from(Vector3(-4.0, 0.1, 8.5), Vector3(-4.0, 1.2, 2.0), "puerta_de_calle")
	await _shot_from(Vector3(-0.8, 0.1, 0.8), Vector3(-7.0, 0.8, 3.5), "sala")
	await _shot_from(Vector3(-0.8, 0.1, -0.8), Vector3(-5.0, 0.9, -5.5), "cocina")
	await _shot_from(Vector3(1.0, 0.1, -5.0), Vector3(1.0, 1.2, 4.0), "pasillo")
	world.srv_set_door(2, true, 0)
	await _wait(0.8)
	await _shot_from(Vector3(1.0, 0.1, 2.4), Vector3(7.0, 0.8, 4.2), "dormitorio_dormido")
	await _shot_from(Vector3(5.0, 0.1, 2.0), Vector3(7.2, 0.9, 4.2), "don_ramon_de_cerca")
	await _shot_from(Vector3(2.6, 0.1, -0.6), Vector3(7.5, 0.8, -1.5), "estudio")
	# Despertarlo y dejar que salga a buscar.
	world.local_player.flashlight_on = true
	world.local_player.teleport(Vector3(-3.0, 0.1, 1.0))
	don.alert = Config.ALERT_WAKE
	await _wait(2.2)
	await _shot_from(Vector3(3.0, 0.1, 1.2), Vector3(6.0, 1.3, 4.2), "se_desperto")
	await _wait(1.5)
	await _shot_from(Vector3(1.0, 0.1, -3.0), Vector3(1.5, 1.5, 3.0), "te_busca")
	# Fin de la noche.
	world.local_player.teleport(Vector3(-5.6, 0.1, 14.0))
	world._srv_end_night("leave")
	await _wait(1.0)
	await _shot("resultados")
	print("TOUR OK: %d fotos en %s" % [_n, out_dir])
	get_tree().quit(0)

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
