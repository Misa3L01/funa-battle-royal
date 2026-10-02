extends Node3D
## Escena de la partida: isla, zona, jugadores, objetos, lobby y HUD.
##
## El lobby vive acá como overlay: así todos los peers ya tienen la arena
## cargada cuando el host arranca, y los MultiplayerSpawner pueden crear los
## personajes y objetos sin sincronizar un cambio de escena.

const PLAYER_SCENE := preload("res://player/player.tscn")
## Los bots usan ids a partir de acá (no chocan con ids de peers reales).
const BOT_ID_OFFSET := 100000
## Atajos de prueba: solo el host y solo en builds de debug.
const DEBUG_EVENT_KEYS := {
	KEY_F1: &"nuclear_strike",
	KEY_F2: &"covid",
	KEY_F3: &"natural_death",
	KEY_F4: &"apagon",
	KEY_F5: &"hiperinflacion",
	KEY_F6: &"lluvia_empanadas",
}

var _overview_angle := 0.0
var _blackout_tween: Tween
## Luz del sol, del cielo y ambiente antes del apagón, para restaurarlas.
var _daylight: Array[float] = [1.2, 1.0, 1.0]

@onready var island: IslandGenerator = $Island
@onready var zone: InflationZone = $Zone
@onready var players_root: Node3D = $Players
@onready var player_spawner: MultiplayerSpawner = $PlayerSpawner
@onready var world_spawner: MultiplayerSpawner = $WorldSpawner
@onready var lobby: Lobby = $Lobby
@onready var hud: Hud = $HUD
@onready var overview_camera: Camera3D = $OverviewCamera
@onready var sun: DirectionalLight3D = $Sun
@onready var world_environment: WorldEnvironment = $WorldEnvironment


func _ready() -> void:
	island.generate()
	GameManager.bind_arena(island, zone, world_spawner)
	# Las funciones de spawn se registran en todos los peers: el servidor llama a
	# spawn(datos) y cada peer construye el objeto con esos mismos datos.
	player_spawner.spawn_function = _spawn_player
	world_spawner.spawn_function = _spawn_world_object
	NetworkManager.match_starting.connect(_on_match_starting)
	NetworkManager.disconnected_from_server.connect(_on_disconnected_from_server)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	GameManager.event_warning.connect(_on_event_warning)
	GameManager.event_triggered.connect(_on_event_triggered)
	hud.hide()


func _exit_tree() -> void:
	GameManager.unbind_arena()


func _process(delta: float) -> void:
	if overview_camera.current:
		_overview_angle += delta * 0.04
		overview_camera.position = Vector3(sin(_overview_angle) * 115.0, 60.0, cos(_overview_angle) * 115.0)
		overview_camera.look_at(Vector3(0, 4, 0))


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo or not OS.is_debug_build() or not multiplayer.is_server():
		return
	if DEBUG_EVENT_KEYS.has(key.keycode):
		GameManager.debug_trigger(DEBUG_EVENT_KEYS[key.keycode])
	elif key.keycode >= KEY_1 and key.keycode <= KEY_9:
		_debug_spawn_weapon(key.keycode - KEY_1)


func _on_match_starting() -> void:
	lobby.hide()
	hud.show()
	if not multiplayer.is_server():
		return

	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var entries: Array[Dictionary] = []
	var used: Dictionary = {}
	var peer_ids := NetworkManager.players.keys()
	peer_ids.sort()
	for peer_id: int in peer_ids:
		var info: Dictionary = NetworkManager.players[peer_id]
		entries.append({"peer_id": peer_id, "bot": false, "character": info["character"], "skin": info["skin"]})
		used[info["character"]] = true
	var skins := DataLibrary.all_in(DataLibrary.SKIN_DIR)
	for i in NetworkManager.bot_count:
		var character := _pick_bot_character(rng, used)
		used[character] = true
		var skin: WeaponSkin = skins[rng.randi() % skins.size()]
		entries.append({"peer_id": BOT_ID_OFFSET + i, "bot": true, "character": character, "skin": skin.id})

	var spawn_points := island.spawn_points.duplicate()
	spawn_points.shuffle()
	var spawned: Array[Player] = []
	for i in entries.size():
		entries[i]["position"] = spawn_points[i % spawn_points.size()]
		spawned.append(player_spawner.spawn(entries[i]) as Player)
	GameManager.start_match(spawned)


func _pick_bot_character(rng: RandomNumberGenerator, used: Dictionary) -> StringName:
	var free: Array[StringName] = []
	for character in CharacterRoster.main().characters:
		if not used.has(character.id):
			free.append(character.id)
	if free.is_empty():
		var all := CharacterRoster.main().characters
		return all[rng.randi() % all.size()].id
	return free[rng.randi() % free.size()]


## Corre en todos los peers con los mismos datos.
func _spawn_player(data: Dictionary) -> Node:
	var player: Player = PLAYER_SCENE.instantiate()
	var character := CharacterRoster.main().get_character(data["character"])
	player.setup(data["peer_id"], character, data["position"], data["bot"], data["skin"])
	player.ready.connect(_on_player_ready.bind(player), CONNECT_ONE_SHOT)
	return player


func _on_player_ready(player: Player) -> void:
	GameManager.register_player(player)
	if player.is_local_human():
		hud.bind_player(player)


func _spawn_world_object(data: Dictionary) -> Node:
	match data["type"]:
		&"projectile":
			var projectile := Projectile.new()
			projectile.setup(data)
			return projectile
		&"pickup":
			var pickup := Pickup.new()
			pickup.setup(data)
			return pickup
		&"wall":
			var wall := WallProp.new()
			wall.setup(data)
			return wall
	push_error("Arena: tipo de objeto desconocido: %s" % data["type"])
	return Node3D.new()


func _on_peer_disconnected(peer_id: int) -> void:
	# El servidor borra al personaje; el spawner lo borra solo en los clientes.
	if multiplayer.is_server():
		var player := GameManager.get_player(peer_id)
		if player:
			player.health.kill(&"desconexion")
			player.queue_free()


func _on_disconnected_from_server() -> void:
	get_tree().reload_current_scene()


## Solo el servidor: borra personajes y objetos en red antes de volver al lobby.
func clear_network_objects() -> void:
	GameManager.end_match()
	for root in [players_root, $World]:
		for child in root.get_children():
			child.queue_free()


func _on_event_warning(event_id: StringName, _text: String, _seconds: float) -> void:
	if event_id == &"nuclear_strike":
		Fx.play(&"siren", Vector3.INF)


func _on_event_triggered(event_id: StringName, _text: String) -> void:
	var event := GameManager.get_event(event_id)
	if event is BlackoutEvent:
		_blackout((event as BlackoutEvent).duration)
	elif event_id == &"nuclear_strike":
		hud.flash_white()


## Se hace de noche un rato y cada personaje lleva una linterna.
func _blackout(duration: float) -> void:
	var environment := world_environment.environment
	if _blackout_tween:
		_blackout_tween.kill()
	else:
		_daylight = [sun.light_energy, environment.background_energy_multiplier, environment.ambient_light_energy]
	for player in GameManager.get_alive_players():
		player.lamp.show()
	_blackout_tween = create_tween()
	_blackout_tween.tween_property(sun, "light_energy", 0.02, 1.5)
	_blackout_tween.parallel().tween_property(environment, "background_energy_multiplier", 0.05, 1.5)
	_blackout_tween.parallel().tween_property(environment, "ambient_light_energy", 0.08, 1.5)
	_blackout_tween.tween_interval(duration)
	_blackout_tween.tween_property(sun, "light_energy", _daylight[0], 2.0)
	_blackout_tween.parallel().tween_property(environment, "background_energy_multiplier", _daylight[1], 2.0)
	_blackout_tween.parallel().tween_property(environment, "ambient_light_energy", _daylight[2], 2.0)
	_blackout_tween.tween_callback(func() -> void:
		for player in GameManager.get_players():
			player.lamp.hide())


func _debug_spawn_weapon(index: int) -> void:
	var weapons := DataLibrary.all_in(DataLibrary.WEAPON_DIR)
	var host := GameManager.get_player(1)
	if host == null or index >= weapons.size():
		return
	var weapon: WeaponData = weapons[index]
	GameManager.spawn_pickup(&"weapon", weapon.id, host.global_position - host.global_basis.z * 1.5, weapon.ammo)
