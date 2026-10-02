class_name Lobby
extends CanvasLayer
## Lobby: elegir personaje y skin, crear o unirse a una partida, sumar bots y
## arrancar. Más adelante lo reemplaza el mapa mundial de selección.
##
## Argumentos para probar rápido sin hacer clicks (en el editor: Depurar >
## Personalizar instancias de ejecución; por consola: después de "--"):
##   --character=pessi     personaje a usar
##   --skin=oro            skin de armas
##   --host                crear partida
##   --join=127.0.0.1      unirse a esa IP
##   --bots=5              (host) cantidad de bots
##   --autostart=2         (host) arrancar solo cuando haya 2 jugadores humanos

const AUTOSTART_DELAY := 3.0

var _selected: CharacterData
var _autostart_player_count := 0
var _autostart_pending := false
var _character_buttons: Dictionary[StringName, Button] = {}

@onready var character_list: VBoxContainer = %CharacterList
@onready var big_face: TextureRect = %BigFace
@onready var character_name: Label = %CharacterName
@onready var character_country: Label = %CharacterCountry
@onready var character_info: RichTextLabel = %CharacterInfo
@onready var skin_option: OptionButton = %SkinOption
@onready var bots_spin: SpinBox = %BotsSpin
@onready var address_edit: LineEdit = %AddressEdit
@onready var host_button: Button = %HostButton
@onready var join_button: Button = %JoinButton
@onready var start_button: Button = %StartButton
@onready var players_label: Label = %PlayersLabel
@onready var status_label: Label = %StatusLabel


func _ready() -> void:
	_build_character_list()
	for skin: WeaponSkin in DataLibrary.all_in(DataLibrary.SKIN_DIR):
		skin_option.add_item("%s (%s)" % [skin.display_name, WeaponData.RARITY_NAMES[skin.rarity]])
		skin_option.set_item_metadata(skin_option.item_count - 1, skin.id)
		if skin.id == NetworkManager.local_skin:
			skin_option.select(skin_option.item_count - 1)
	skin_option.item_selected.connect(func(_index: int) -> void: _push_choice())
	bots_spin.max_value = NetworkManager.MAX_PLAYERS - 1
	bots_spin.value = NetworkManager.bot_count
	bots_spin.value_changed.connect(func(value: float) -> void: NetworkManager.set_bot_count(int(value)))
	host_button.pressed.connect(_on_host_pressed)
	join_button.pressed.connect(_on_join_pressed)
	start_button.pressed.connect(NetworkManager.start_match)
	NetworkManager.players_changed.connect(_on_players_changed)
	NetworkManager.connection_failed.connect(_on_connection_failed)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	_select_character(CharacterRoster.main().get_character(NetworkManager.local_character))
	_refresh_connection_state()
	# Diferido: la arena todavía no terminó su _ready y podría perderse señales.
	_apply_command_line.call_deferred()


func _build_character_list() -> void:
	var by_country: Dictionary = {}
	var countries: Array[String] = []
	for character in CharacterRoster.main().characters:
		if not by_country.has(character.country):
			by_country[character.country] = []
			countries.append(character.country)
		by_country[character.country].append(character)
	var group := ButtonGroup.new()
	for country in countries:
		var header := Label.new()
		header.text = country.to_upper()
		header.add_theme_font_size_override("font_size", 15)
		header.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
		character_list.add_child(header)
		var row := HFlowContainer.new()
		row.add_theme_constant_override("h_separation", 8)
		row.add_theme_constant_override("v_separation", 8)
		character_list.add_child(row)
		for character: CharacterData in by_country[country]:
			var button := Button.new()
			button.toggle_mode = true
			button.button_group = group
			button.icon = character.face_texture
			button.expand_icon = true
			button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
			button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
			button.custom_minimum_size = Vector2(104, 118)
			button.text = character.display_name
			button.clip_text = true
			button.add_theme_font_size_override("font_size", 12)
			button.tooltip_text = character.display_name
			button.pressed.connect(_on_character_pressed.bind(character))
			row.add_child(button)
			_character_buttons[character.id] = button


func _on_character_pressed(character: CharacterData) -> void:
	_select_character(character)
	_push_choice()


func _select_character(character: CharacterData) -> void:
	if character == null:
		character = CharacterRoster.main().characters[0]
	_selected = character
	if _character_buttons.has(character.id):
		_character_buttons[character.id].button_pressed = true
	big_face.texture = character.face_texture
	character_name.text = character.display_name
	character_country.text = character.country
	character_info.text = _describe(character)


func _describe(character: CharacterData) -> String:
	var lines := PackedStringArray()
	lines.append("[i]%s[/i]" % character.bio)
	lines.append("")
	lines.append("[b]Vida[/b] %d   [b]Velocidad[/b] %.1f" % [character.max_health, character.move_speed])
	if character.ability:
		lines.append("[color=#ffd24d][b]Q · %s[/b][/color] (%ds): %s" % [character.ability.display_name,
			character.ability.cooldown, character.ability.description])
	for weapon: WeaponData in DataLibrary.all_in(DataLibrary.WEAPON_DIR):
		if weapon.signature_character == character.id:
			lines.append("[color=#ffb347][b]★ Arma firma: %s[/b][/color] — %s" % [weapon.display_name, weapon.signature_text])
	for relation in GameManager.RIVALRIES.entries:
		if relation.character_a != character.id and relation.character_b != character.id:
			continue
		var other_id := relation.character_b if relation.character_a == character.id else relation.character_a
		var other := CharacterRoster.main().get_character(other_id)
		if other == null:
			continue
		var is_rival := relation.kind == RivalryData.Kind.RIVAL
		lines.append("[color=%s]%s con %s: %s[/color]" % ["#ff7a6b" if is_rival else "#7ad8ff",
			"Rival" if is_rival else "Aliado", other.display_name, relation.display_name])
	if not character.tags.is_empty():
		var tags := PackedStringArray()
		for tag in character.tags:
			tags.append(String(tag).replace("_", " "))
		lines.append("[color=#9a9a9a]Tags: %s[/color]" % ", ".join(tags))
	return "\n".join(lines)


func _selected_skin() -> StringName:
	return skin_option.get_selected_metadata()


func _push_choice() -> void:
	NetworkManager.set_local_choice(_selected.id, _selected_skin())


func _set_buttons_enabled(enabled: bool) -> void:
	host_button.disabled = not enabled
	join_button.disabled = not enabled
	address_edit.editable = enabled


func _refresh_connection_state() -> void:
	var online := NetworkManager.is_online()
	var is_host := online and multiplayer.is_server()
	_set_buttons_enabled(not online)
	start_button.visible = is_host
	bots_spin.editable = is_host or not online
	if online:
		status_label.text = "Sos el host. Cuando estén todos, arrancá." if is_host else "Conectado. Esperando a que el host arranque."
		_on_players_changed()


func _on_host_pressed() -> void:
	NetworkManager.set_local_choice(_selected.id, _selected_skin())
	var error := NetworkManager.host_game()
	if error != OK:
		status_label.text = "No se pudo crear la partida (%s)." % error_string(error)
		return
	NetworkManager.set_bot_count(int(bots_spin.value))
	status_label.text = "Partida creada en el puerto %d. Esperando jugadores..." % NetworkManager.DEFAULT_PORT
	_refresh_connection_state()


func _on_join_pressed() -> void:
	NetworkManager.set_local_choice(_selected.id, _selected_skin())
	var address := address_edit.text.strip_edges()
	var error := NetworkManager.join_game(address)
	if error != OK:
		status_label.text = "No se pudo conectar (%s)." % error_string(error)
		return
	_set_buttons_enabled(false)
	status_label.text = "Conectando a %s..." % address


func _on_connected_to_server() -> void:
	_refresh_connection_state()


func _on_connection_failed() -> void:
	_set_buttons_enabled(true)
	status_label.text = "No se pudo conectar."


func _on_players_changed() -> void:
	var lines := PackedStringArray()
	for peer_id: int in NetworkManager.players:
		var info: Dictionary = NetworkManager.players[peer_id]
		var character := CharacterRoster.main().get_character(info["character"])
		var character_label := character.display_name if character else "?"
		lines.append("• %s%s" % [character_label, " (host)" if peer_id == 1 else ""])
	if NetworkManager.bot_count > 0:
		lines.append("• + %d bots" % NetworkManager.bot_count)
	players_label.text = "Jugadores (%d/%d):\n%s" % [NetworkManager.players.size() + NetworkManager.bot_count,
		NetworkManager.MAX_PLAYERS, "\n".join(lines)]
	if not bots_spin.has_focus():
		bots_spin.set_value_no_signal(NetworkManager.bot_count)
	_check_autostart()


func _check_autostart() -> void:
	if _autostart_pending or _autostart_player_count <= 0 or not multiplayer.is_server():
		return
	if NetworkManager.players.size() < _autostart_player_count or NetworkManager.match_in_progress:
		return
	_autostart_pending = true
	status_label.text = "Arrancando en %d segundos..." % AUTOSTART_DELAY
	get_tree().create_timer(AUTOSTART_DELAY).timeout.connect(NetworkManager.start_match)


func _apply_command_line() -> void:
	var args := {}
	for arg in OS.get_cmdline_user_args():
		var parts := arg.trim_prefix("--").split("=", true, 1)
		args[parts[0]] = parts[1] if parts.size() > 1 else ""
	# La autoarrancada sigue valiendo después de volver al lobby (partidas en loop).
	_autostart_player_count = String(args.get("autostart", "0")).to_int()
	if NetworkManager.command_line_applied:
		_check_autostart()
		return
	NetworkManager.command_line_applied = true

	if args.has("character"):
		_select_character(CharacterRoster.main().get_character(StringName(args["character"])))
	if args.has("skin"):
		for index in skin_option.item_count:
			if skin_option.get_item_metadata(index) == StringName(args["skin"]):
				skin_option.select(index)
	if args.has("bots"):
		bots_spin.value = String(args["bots"]).to_int()
	if args.has("host"):
		_on_host_pressed()
	elif args.has("join"):
		if args["join"] != "":
			address_edit.text = args["join"]
		_on_join_pressed()
