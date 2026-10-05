extends Node
## Recorrido de fotos para revisar cómo se ve el juego sin jugarlo a mano:
##
##   godot --path . -- --host --tour=/carpeta/de/fotos
##
## Pone la cámara en varios lugares, dispara dinamita, provoca un derrumbe y guarda capturas.

var world: World
var out_dir := ""
var _n := 0

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(out_dir)
	await _wait(1.5)
	var me := world.local_player
	world.game["money"] = 400
	# Superficie: la torre del pozo y el campamento.
	await _shot_from(Vector3(9.0, 0.2, 12.0), Vector3(0, 4.0, 0), "superficie")
	await _shot_from(Vector3(3.0, 0.2, -4.0), Vector3(12.0, 1.0, 2.0), "bascula_prestamista")
	await _shot_from(Vector3(3.2, 0.2, 3.6), Vector3(0, -6.0, 0), "pozo_desde_arriba")
	# Bajar con el montacargas y mirar la cámara inicial.
	world.lift.height = Config.LIFT_BOTTOM
	world.lift.speed = 0.0
	for e: Entity in world.entities.values():
		if e.kind == "cart":
			e.global_position = Vector3(0, Config.LIFT_BOTTOM + 0.05, 0)
	await _wait(0.5)
	await _shot_from(Vector3(-4.5, Config.MINE_Y + 0.2, 4.5), Vector3(4.0, Config.MINE_Y + 1.0, -2.0), "mina_camara")
	await _shot_from(Vector3(4.6, Config.MINE_Y + 0.2, 4.6), Vector3(9.0, Config.MINE_Y + 1.6, 1.0), "mina_vetas")
	# Dinamita al fondo del túnel este.
	me.current_tool = Player.Tool.DYNAMITE
	me.charge = 3
	await _shot_from(Vector3(5.0, Config.MINE_Y + 0.2, -1.0), Vector3(12.0, Config.MINE_Y + 1.5, -1.0), "apuntando_dinamita")
	world._srv_dynamite(1, Vector3(11.84, Config.MINE_Y + 1.5, -1.0), Vector3(-1, 0, 0), 3)
	await _wait(2.5)
	await _shot_from(Vector3(3.0, Config.MINE_Y + 0.2, -0.5), Vector3(12.0, Config.MINE_Y + 1.2, -1.0), "mecha")
	await _wait(Config.FUSE_TIME - 2.5 - 0.05)
	await _wait(0.12)
	await _shot("explosion")
	await _wait(1.6)
	await _shot("despues_explosion")
	# Derrumbe forzado en el túnel sur.
	world.debug_force_collapse = true
	world._srv_dynamite(1, Vector3(-1.0, Config.MINE_Y + 1.5, -11.84), Vector3(0, 0, 1), 1)
	me.current_tool = Player.Tool.PICKAXE
	await _shot_from(Vector3(-1.0, Config.MINE_Y + 0.2, -2.0), Vector3(-1.0, Config.MINE_Y + 1.2, -11.0), "tunel_sur")
	await _wait(Config.FUSE_TIME + 0.4)
	await _shot("crujidos")
	await _wait(Config.COLLAPSE_WARNING + 0.6)
	await _shot("derrumbe")
	await _wait(3.0)
	await _shot("escombros")
	world.debug_force_collapse = false
	print("TOUR OK: %d fotos en %s" % [_n, out_dir])
	get_tree().quit(0)

func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout

## Pone al minero en `from` mirando hacia `target` y saca una foto.
func _shot_from(from: Vector3, target: Vector3, label: String) -> void:
	var me := world.local_player
	me.teleport(from)
	var eye := from + Vector3(0, 1.6, 0)
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
