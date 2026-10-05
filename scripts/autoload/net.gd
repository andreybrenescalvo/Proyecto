extends Node
## Conexión multijugador. Un jugador hace de anfitrión y los demás se conectan a él:
## no hace falta pagar servidores.
##
## Dos formas de conectarse:
##  - ENet (IP directa / red local): para desarrollo y pruebas, no necesita Steam.
##  - Steam (lobbies de amigos): necesita el plugin GodotSteam con SteamMultiplayerPeer.
##    Se usa de forma dinámica, así el proyecto abre y funciona aunque el plugin no esté instalado.
## En el navegador no hay UDP ni Steam: ahí se juega solo (sin conexión).

signal session_started                  # se creó la partida (anfitrión) o se conectó (cliente)
signal session_failed(reason: String)   # no se pudo crear o unirse
signal session_ended(reason: String)    # se cortó una partida que estaba en curso
signal steam_join_requested             # un amigo nos invitó desde Steam y aceptamos

const DEFAULT_PORT := 24567
const MAX_PLAYERS := 4
## 480 = "Spacewar", la app de prueba de Valve. Cambiarla por el App ID propio al registrar el juego.
const STEAM_APP_ID := 480

# Valores de enums de Steamworks (se escriben a mano porque el plugin se carga de forma dinámica).
const STEAM_LOBBY_FRIENDS_ONLY := 1
const STEAM_RESULT_OK := 1
const STEAM_CHAT_ENTER_SUCCESS := 1

enum Mode { NONE, SOLO, ENET, STEAM }

var mode: Mode = Mode.NONE
var player_name := "Minero"
var steam: Object = null        # singleton "Steam" de GodotSteam, si está instalado
var steam_ready := false
var steam_id := 0
var lobby_id := 0
var pending_lobby_join := 0     # lobby al que entrar apenas cargue el menú (invitación)
var _joining := false

func _ready() -> void:
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	_init_steam()

func _process(_delta: float) -> void:
	if steam_ready:
		steam.call("run_callbacks")

func is_active() -> bool:
	return mode != Mode.NONE

func has_steam_peer() -> bool:
	return steam_ready and ClassDB.class_exists("SteamMultiplayerPeer")

## ¿Se puede jugar en red? (En el navegador, no.)
func can_play_online() -> bool:
	return not OS.has_feature("web")

## Partida de un solo jugador, sin conexión. El jugador local hace de anfitrión.
func host_solo() -> void:
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	mode = Mode.SOLO
	session_started.emit()

# ---------------------------------------------------------------- ENet

func host_enet(port := DEFAULT_PORT) -> void:
	if not can_play_online():
		host_solo()
		return
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, MAX_PLAYERS - 1)
	if err != OK:
		session_failed.emit("No se pudo abrir el puerto %d (error %d). ¿Ya hay una partida abierta?" % [port, err])
		return
	multiplayer.multiplayer_peer = peer
	mode = Mode.ENET
	session_started.emit()

func join_enet(address: String, port := DEFAULT_PORT) -> void:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(address, port)
	if err != OK:
		session_failed.emit("No se pudo conectar a %s:%d (error %d)." % [address, port, err])
		return
	multiplayer.multiplayer_peer = peer
	mode = Mode.ENET
	_joining = true   # session_started llega en _on_connected_to_server

# ---------------------------------------------------------------- Steam

func _init_steam() -> void:
	if not Engine.has_singleton("Steam"):
		return
	steam = Engine.get_singleton("Steam")
	OS.set_environment("SteamAppId", str(STEAM_APP_ID))
	OS.set_environment("SteamGameId", str(STEAM_APP_ID))
	var result: Dictionary = steam.call("steamInitEx")
	if int(result.get("status", -1)) != 0:
		push_warning("Steam no se pudo iniciar: %s" % result.get("verbal", "¿Steam está abierto?"))
		return
	steam_ready = true
	steam_id = steam.call("getSteamID")
	player_name = steam.call("getPersonaName")
	steam.connect("lobby_created", _on_lobby_created)
	steam.connect("lobby_joined", _on_lobby_joined)
	steam.connect("join_requested", _on_join_requested)
	# Si el juego se abrió aceptando una invitación, Steam pasa "+connect_lobby <id>".
	var args := OS.get_cmdline_args()
	var i := args.find("+connect_lobby")
	if i >= 0 and i + 1 < args.size():
		pending_lobby_join = int(args[i + 1])

func host_steam() -> void:
	if not has_steam_peer():
		session_failed.emit("Steam no está disponible. Revisa que Steam esté abierto y GodotSteam instalado.")
		return
	steam.call("createLobby", STEAM_LOBBY_FRIENDS_ONLY, MAX_PLAYERS)
	# Sigue en _on_lobby_created.

func join_steam_lobby(id: int) -> void:
	if not has_steam_peer():
		session_failed.emit("Steam no está disponible.")
		return
	_joining = true
	steam.call("joinLobby", id)
	# Sigue en _on_lobby_joined.

func invite_friends() -> void:
	if steam_ready and lobby_id != 0:
		steam.call("activateGameOverlayInviteDialog", lobby_id)

func _on_lobby_created(result: int, new_lobby_id: int) -> void:
	if result != STEAM_RESULT_OK:
		session_failed.emit("Steam no pudo crear el lobby (código %d)." % result)
		return
	lobby_id = new_lobby_id
	steam.call("setLobbyJoinable", lobby_id, true)
	steam.call("setLobbyData", lobby_id, "name", "Mina de %s" % player_name)
	var peer: MultiplayerPeer = ClassDB.instantiate("SteamMultiplayerPeer")
	var err: int = peer.call("create_host", 0)
	if err != OK:
		session_failed.emit("No se pudo crear la partida en Steam (error %d)." % err)
		return
	multiplayer.multiplayer_peer = peer
	mode = Mode.STEAM
	session_started.emit()

func _on_lobby_joined(joined_lobby_id: int, _permissions: int, _locked: bool, response: int) -> void:
	if response != STEAM_CHAT_ENTER_SUCCESS:
		_joining = false
		session_failed.emit("No se pudo entrar al lobby (código %d)." % response)
		return
	var owner_id: int = steam.call("getLobbyOwner", joined_lobby_id)
	if owner_id == steam_id:
		return   # este aviso también llega al anfitrión cuando crea su propio lobby
	lobby_id = joined_lobby_id
	var peer: MultiplayerPeer = ClassDB.instantiate("SteamMultiplayerPeer")
	var err: int = peer.call("create_client", owner_id, 0)
	if err != OK:
		_joining = false
		session_failed.emit("No se pudo conectar con el anfitrión (error %d)." % err)
		return
	multiplayer.multiplayer_peer = peer
	mode = Mode.STEAM
	# session_started llega en _on_connected_to_server.

func _on_join_requested(requested_lobby_id: int, _friend_id: int) -> void:
	if is_active():
		leave("Te uniste a la partida de un amigo.")
	pending_lobby_join = requested_lobby_id
	steam_join_requested.emit()

# ---------------------------------------------------------------- comunes

func leave(reason := "") -> void:
	var was_active := is_active()
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	if steam_ready and lobby_id != 0:
		steam.call("leaveLobby", lobby_id)
	lobby_id = 0
	mode = Mode.NONE
	_joining = false
	if was_active:
		session_ended.emit(reason)

func _on_connected_to_server() -> void:
	_joining = false
	session_started.emit()

func _on_connection_failed() -> void:
	mode = Mode.NONE
	_joining = false
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	session_failed.emit("No se pudo conectar con el anfitrión.")

func _on_server_disconnected() -> void:
	leave("Se perdió la conexión con el anfitrión.")
