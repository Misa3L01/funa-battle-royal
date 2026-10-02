class_name Hud
extends CanvasLayer
## HUD de la partida: vida, efectos, arma, habilidad, zona, bajas, anuncios de
## eventos, pantallas de muerte y de fin de partida.

const EVENT_ANNOUNCEMENT_SECONDS := 5.0
const KILL_FEED_LINES := 5
const KILL_FEED_SECONDS := 7.0

var _player: Player
var _announcement_tween: Tween
## Un tween por overlay: si compartieran uno, un destello cortaría al otro a mitad de camino.
var _flash_tweens: Dictionary = {}
var _status_refresh := 0.0
var _end_countdown := -1.0

@onready var announcement_label: Label = %AnnouncementLabel
@onready var alive_label: Label = %AliveLabel
@onready var zone_label: Label = %ZoneLabel
@onready var kill_feed: VBoxContainer = %KillFeed
@onready var face_rect: TextureRect = %FaceRect
@onready var name_label: Label = %NameLabel
@onready var health_bar: ProgressBar = %HealthBar
@onready var status_text: RichTextLabel = %StatusText
@onready var weapon_label: Label = %WeaponLabel
@onready var weapon_info: Label = %WeaponInfo
@onready var ability_label: Label = %AbilityLabel
@onready var ability_bar: ProgressBar = %AbilityBar
@onready var pickup_prompt: Label = %PickupPrompt
@onready var crosshair: Label = %Crosshair
@onready var dizzy_overlay: ColorRect = %DizzyOverlay
@onready var zone_overlay: ColorRect = %ZoneOverlay
@onready var damage_flash: ColorRect = %DamageFlash
@onready var white_flash: ColorRect = %WhiteFlash
@onready var death_label: Label = %DeathLabel
@onready var end_panel: PanelContainer = %EndPanel
@onready var end_title: Label = %EndTitle
@onready var end_stats: Label = %EndStats
@onready var end_countdown: Label = %EndCountdown


func _ready() -> void:
	announcement_label.text = ""
	pickup_prompt.text = ""
	death_label.hide()
	end_panel.hide()
	dizzy_overlay.hide()
	zone_overlay.hide()
	GameManager.event_warning.connect(_on_event_warning)
	GameManager.event_triggered.connect(_on_event_triggered)
	GameManager.announcement.connect(show_announcement)
	GameManager.kill_feed.connect(_add_kill_feed_line)
	GameManager.alive_count_changed.connect(_on_alive_count_changed)
	GameManager.match_over.connect(_on_match_over)


func bind_player(player: Player) -> void:
	_player = player
	face_rect.texture = player.character.face_texture
	name_label.text = player.character.display_name
	player.health.health_changed.connect(_on_health_changed)
	player.health.health_delta.connect(_on_health_delta)
	player.health.died.connect(_on_local_died)
	player.combat.weapon_changed.connect(func(_weapon: WeaponData) -> void: _refresh_weapon())
	player.combat.ammo_changed.connect(func(_ammo: int) -> void: _refresh_weapon())
	player.status.changed.connect(_refresh_statuses)
	_on_health_changed(player.health.current_health, player.health.max_health)
	_refresh_weapon()
	var ability := player.character.ability
	ability_label.text = "[Q] %s" % ability.display_name if ability else ""


func show_announcement(text: String, duration: float, color: Color = Color(1, 0.85, 0.2)) -> void:
	if _announcement_tween:
		_announcement_tween.kill()
	announcement_label.text = text
	announcement_label.modulate = color
	_announcement_tween = create_tween()
	_announcement_tween.tween_interval(duration)
	_announcement_tween.tween_property(announcement_label, "modulate:a", 0.0, 0.5)


func flash_white() -> void:
	_flash(white_flash, 1.0, 2.5)


func _process(delta: float) -> void:
	_update_zone_label()
	if _end_countdown >= 0.0:
		_end_countdown = maxf(_end_countdown - delta, 0.0)
		end_countdown.text = "Volviendo al lobby en %d..." % ceili(_end_countdown)
	if _player == null or not is_instance_valid(_player):
		return
	_status_refresh -= delta
	if _status_refresh <= 0.0:
		_status_refresh = 0.25
		_refresh_statuses()

	var ability := _player.character.ability
	if ability:
		var remaining := maxf(_player.combat.local_ability_ready_at - CombatComponent.now(), 0.0)
		ability_bar.value = 1.0 - remaining / ability.cooldown
		ability_label.modulate = Color.WHITE if remaining <= 0.0 else Color(0.6, 0.6, 0.6)

	var alive := _player.health.is_alive()
	var dizzy := alive and _player.status.has_flag(StatusEffect.Flag.DIZZY)
	dizzy_overlay.visible = dizzy
	if dizzy:
		(dizzy_overlay.material as ShaderMaterial).set_shader_parameter("intensity", 0.8)
	zone_overlay.visible = alive and GameManager.zone != null and GameManager.zone.is_active() \
		and GameManager.zone.distance_outside(_player.global_position) > 0.0
	crosshair.visible = alive

	pickup_prompt.text = ""
	if alive:
		var pickup := GameManager.find_nearest_pickup(_player.global_position, CombatComponent.PICKUP_RANGE, &"weapon")
		if pickup:
			var weapon := DataLibrary.weapon(pickup.item_id)
			var tag := " ★ ¡ARMA FIRMA!" if weapon.is_signature_for(_player.character) else ""
			pickup_prompt.text = "[E] Agarrar %s%s" % [weapon.display_name, tag]


func _update_zone_label() -> void:
	var zone := GameManager.zone
	if zone == null or not zone.is_active():
		zone_label.text = ""
		return
	var seconds := ceili(zone.seconds_to_next_change())
	var time := "%d:%02d" % [floori(seconds / 60.0), seconds % 60]
	if zone.is_shrinking():
		zone_label.text = "¡LA INFLACIÓN AVANZA! %s  (-%d/s afuera)" % [time, roundi(zone.damage_per_second)]
		zone_label.modulate = Color(1.0, 0.45, 0.9)
	else:
		zone_label.text = "La inflación se acelera en %s" % time
		zone_label.modulate = Color(0.9, 0.8, 1.0)


func _refresh_weapon() -> void:
	var combat := _player.combat
	var weapon := combat.weapon
	weapon_label.text = weapon.display_name + ("  ★ FIRMA" if combat.is_signature() else "")
	weapon_label.modulate = weapon.get_rarity_color()
	var details := PackedStringArray()
	if weapon.uses_ammo():
		details.append("Usos: %d" % combat.ammo)
	if weapon.signature_character != &"" and weapon.signature_text != "":
		details.append(weapon.signature_text)
	weapon_info.text = "  ·  ".join(details)


func _refresh_statuses() -> void:
	if _player == null:
		return
	var parts := PackedStringArray()
	for active in _player.status.get_active_effects():
		if active.effect.display_name == "":
			continue
		parts.append("[color=#%s]%s %ds[/color]" % [active.effect.color.to_html(false), active.effect.display_name,
			ceili(maxf(active.remaining, 0.0))])
	status_text.text = "  ".join(parts)


func _on_health_changed(current: float, maximum: float) -> void:
	health_bar.max_value = maximum
	health_bar.value = current


func _on_health_delta(amount: float, _attacker_id: int) -> void:
	if amount > 0.0:
		_flash(damage_flash, clampf(amount / 40.0, 0.15, 0.5), 0.35)


func _on_local_died(cause: StringName, killer_id: int) -> void:
	var killer := GameManager.get_player(killer_id)
	var reason := GameManager.describe_cause(cause)
	if killer and killer != _player:
		death_label.text = "TE FUNARON\n%s (%s)\nClick: mirar a otro jugador" % [killer.get_display_name(), reason]
	else:
		death_label.text = "TE FUNARON\n%s\nClick: mirar a otro jugador" % reason
	death_label.show()


func _on_event_warning(_event_id: StringName, text: String, seconds: float) -> void:
	show_announcement(text, seconds, Color(1.0, 0.3, 0.2))


func _on_event_triggered(_event_id: StringName, text: String) -> void:
	show_announcement(text, EVENT_ANNOUNCEMENT_SECONDS)


func _on_alive_count_changed(alive: int, total: int) -> void:
	alive_label.text = "Vivos: %d / %d" % [alive, total]


func _add_kill_feed_line(text: String) -> void:
	var line := Label.new()
	line.text = text
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	line.add_theme_color_override("font_outline_color", Color.BLACK)
	line.add_theme_constant_override("outline_size", 6)
	kill_feed.add_child(line)
	while kill_feed.get_child_count() > KILL_FEED_LINES:
		kill_feed.get_child(0).free()
	var tween := line.create_tween()
	tween.tween_interval(KILL_FEED_SECONDS)
	tween.tween_property(line, "modulate:a", 0.0, 0.6)
	tween.tween_callback(line.queue_free)


func _on_match_over(winner_name: String, standings: Array) -> void:
	death_label.hide()
	end_title.text = "¡GANÓ %s!" % winner_name.to_upper()
	var lines := PackedStringArray()
	for i in standings.size():
		var entry: Dictionary = standings[i]
		var kills: int = entry["kills"]
		lines.append("%d. %s — %d %s" % [i + 1, entry["name"], kills, "funa" if kills == 1 else "funas"])
	end_stats.text = "\n".join(lines)
	_end_countdown = GameManager.RETURN_TO_LOBBY_SECONDS
	end_panel.show()
	Fx.play(&"win", Vector3.INF)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _flash(rect: ColorRect, alpha: float, duration: float) -> void:
	var previous: Tween = _flash_tweens.get(rect)
	if previous:
		previous.kill()
	rect.modulate.a = alpha
	var tween := create_tween()
	tween.tween_property(rect, "modulate:a", 0.0, duration)
	_flash_tweens[rect] = tween
