extends Node
## Escena principal: muestra el menú y crea o destruye el mundo según la conexión.
##
## Opciones de línea de comandos (después de "--"), útiles para probar rápido:
##   --name=Ana        nombre del jugador
##   --host            crear partida al abrir
##   --solo            jugar solo, sin conexión (es lo que usa la versión de navegador)
##   --join=1.2.3.4    unirse a esa IP al abrir
##   --autotest        correr la prueba automática (ver scripts/dev/autotest.gd)
##   --expect=1        (con --autotest) cuántos clientes espera el anfitrión
##   --tour=carpeta    sacar fotos de distintos lugares (ver scripts/dev/photo_tour.gd)

const Autotest := preload("res://scripts/dev/autotest.gd")
const PhotoTour := preload("res://scripts/dev/photo_tour.gd")

var world: World
var menu: Menu
var _autotest := false
var _expect_clients := 0
var _tour_dir := ""

func _ready() -> void:
	Net.session_started.connect(_on_session_started)
	Net.session_failed.connect(_on_session_failed)
	Net.session_ended.connect(_on_session_ended)
	Net.steam_join_requested.connect(_on_steam_join_requested)
	menu = Menu.new()
	add_child(menu)
	_parse_args()
	if Net.pending_lobby_join != 0:
		_on_steam_join_requested()

func _parse_args() -> void:
	var join_ip := ""
	var host := false
	var solo := false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--name="):
			Net.player_name = arg.get_slice("=", 1)
		elif arg == "--host":
			host = true
		elif arg == "--solo":
			solo = true
		elif arg.begins_with("--join="):
			join_ip = arg.get_slice("=", 1)
		elif arg == "--autotest":
			_autotest = true
		elif arg.begins_with("--expect="):
			_expect_clients = int(arg.get_slice("=", 1))
		elif arg.begins_with("--tour="):
			_tour_dir = arg.get_slice("=", 1)
	if solo:
		Net.host_solo()
	elif host:
		Net.host_enet()
	elif join_ip != "":
		Net.join_enet(join_ip)

func _on_session_started() -> void:
	if world != null:
		return
	menu.close()
	world = World.new()
	world.name = "World"
	add_child(world)
	if _autotest:
		var test: Node = Autotest.new()
		test.set("world", world)
		test.set("expect_clients", _expect_clients)
		test.name = "Autotest"
		add_child(test)
	elif _tour_dir != "":
		var tour: Node = PhotoTour.new()
		tour.set("world", world)
		tour.set("out_dir", _tour_dir)
		tour.name = "Autotest"
		add_child(tour)

func _on_session_failed(reason: String) -> void:
	_close_world()
	menu.open(reason)
	if _autotest:
		print("AUTOTEST: no se pudo conectar: ", reason)
		get_tree().quit(1)

func _on_session_ended(reason: String) -> void:
	_close_world()
	menu.open(reason)
	if _autotest:
		print("AUTOTEST: sesión terminada: ", reason)
		get_tree().quit(0)

func _on_steam_join_requested() -> void:
	var id := Net.pending_lobby_join
	Net.pending_lobby_join = 0
	if id == 0:
		return
	menu.show_status("Entrando a la partida de un amigo...")
	Net.join_steam_lobby(id)

func _close_world() -> void:
	if world == null:
		return
	remove_child(world)
	world.queue_free()
	world = null
	var test := get_node_or_null("Autotest")
	if test:
		test.queue_free()
