extends Node
## NetworkManager (Autoload): conexión online, lobby y bots.
##
## Topología: un jugador hace de host (servidor + jugador, peer 1) y hasta 9
## más se conectan por IP con ENet. Los lugares libres se pueden llenar con
## bots. Más adelante se puede cambiar ENet por Steam (addon GodotSteam) sin
## tocar el resto del juego, porque todo usa la API "multiplayer" de Godot.

signal players_changed
signal connection_failed
signal disconnected_from_server
## Se emite en todos los peers cuando el host arranca la partida.
signal match_starting

const DEFAULT_PORT := 7777
const MAX_PLAYERS := 10

## peer_id -> {"character": StringName, "skin": StringName}. Lo mantiene el servidor.
var players: Dictionary[int, Dictionary] = {}
var bot_count := 0
var match_in_progress := false
var local_character: StringName = &"pessi"
var local_skin: StringName = &"clasica"
## Los argumentos de línea de comandos (--host, --join...) se aplican una sola vez.
var command_line_applied := false


func _ready() -> void:
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)


func is_online() -> bool:
	var peer := multiplayer.multiplayer_peer
	return peer is ENetMultiplayerPeer \
		and peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED


func host_game(port: int = DEFAULT_PORT) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_server(port, MAX_PLAYERS - 1)
	if error != OK:
		return error
	multiplayer.multiplayer_peer = peer
	players.clear()
	players[1] = {"character": local_character, "skin": local_skin}
	players_changed.emit()
	return OK


func join_game(address: String, port: int = DEFAULT_PORT) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_client(address, port)
	if error != OK:
		return error
	multiplayer.multiplayer_peer = peer
	return OK


## Cambia el personaje o la skin elegidos (también estando ya conectado).
func set_local_choice(character_id: StringName, skin_id: StringName) -> void:
	local_character = character_id
	local_skin = skin_id
	if not is_online():
		return
	if multiplayer.is_server():
		players[1] = {"character": character_id, "skin": skin_id}
		_broadcast_players()
	else:
		_register_player.rpc_id(1, character_id, skin_id)


## Solo el host: cuántos bots completan la partida.
func set_bot_count(count: int) -> void:
	if not multiplayer.is_server():
		return
	bot_count = clampi(count, 0, MAX_PLAYERS - maxi(players.size(), 1))
	if is_online():
		_broadcast_players()
	else:
		players_changed.emit()


## Arranca la partida para todos. Solo el host.
func start_match() -> void:
	if not multiplayer.is_server() or match_in_progress:
		return
	bot_count = clampi(bot_count, 0, MAX_PLAYERS - players.size())
	_begin_match.rpc()


## Solo el host: todos vuelven al lobby, sin desconectarse.
func return_to_lobby() -> void:
	if not multiplayer.is_server():
		return
	# Primero se borran los objetos en red (los clientes reciben el aviso mientras
	# todavía los tienen) y recién después todos recargan la escena.
	var scene := get_tree().current_scene
	if scene and scene.has_method("clear_network_objects"):
		scene.clear_network_objects()
	get_tree().create_timer(0.6).timeout.connect(func() -> void: _return_to_lobby.rpc())


func leave() -> void:
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	players.clear()
	match_in_progress = false


func _on_connected_to_server() -> void:
	_register_player.rpc_id(1, local_character, local_skin)


func _on_connection_failed() -> void:
	leave()
	connection_failed.emit()


func _on_server_disconnected() -> void:
	leave()
	disconnected_from_server.emit()


func _on_peer_disconnected(peer_id: int) -> void:
	if multiplayer.is_server():
		players.erase(peer_id)
		_broadcast_players()


## Un cliente le avisa al servidor qué personaje y skin eligió.
@rpc("any_peer", "reliable")
func _register_player(character_id: StringName, skin_id: StringName) -> void:
	if not multiplayer.is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	# No confiar en el cliente: validar lo que manda.
	if not CharacterRoster.main().has_character(character_id):
		multiplayer.multiplayer_peer.disconnect_peer(sender)
		return
	if match_in_progress and not players.has(sender):
		multiplayer.multiplayer_peer.disconnect_peer(sender)
		return
	if DataLibrary.find(DataLibrary.SKIN_DIR, skin_id) == null:
		skin_id = &"clasica"
	players[sender] = {"character": character_id, "skin": skin_id}
	bot_count = clampi(bot_count, 0, MAX_PLAYERS - players.size())
	_broadcast_players()


func _broadcast_players() -> void:
	_receive_players.rpc(players, bot_count)
	players_changed.emit()


@rpc("authority", "reliable")
func _receive_players(new_players: Dictionary, new_bot_count: int) -> void:
	players.clear()
	for peer_id: int in new_players:
		var info: Dictionary = new_players[peer_id]
		players[peer_id] = {"character": StringName(info["character"]), "skin": StringName(info["skin"])}
	bot_count = new_bot_count
	players_changed.emit()


@rpc("authority", "call_local", "reliable")
func _begin_match() -> void:
	match_in_progress = true
	match_starting.emit()


@rpc("authority", "call_local", "reliable")
func _return_to_lobby() -> void:
	match_in_progress = false
	get_tree().reload_current_scene()
