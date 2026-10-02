class_name CombatComponent
extends Node
## Armas, ataques (con combos), habilidad y objetos de un personaje.
##
## El dueño (o el bot, en el servidor) pide acciones con request_*. El dueño ve
## su animación al instante (predicción) y el servidor valida cooldowns y
## estados, calcula los golpes y avisa a los demás qué animación reproducir.
## Como su autoridad de red es siempre el servidor, también es el canal
## servidor → peers del personaje: empujones, dashes y globos de texto.

signal weapon_changed(weapon: WeaponData)
signal ammo_changed(ammo: int)
signal action_played(animation: StringName, kind: PlayerStateMachine.State, duration: float)

## Tiempo máximo entre golpes livianos para seguir el combo.
const COMBO_WINDOW := 0.9
## El tercer golpe del combo pega más fuerte y empuja el doble.
const COMBO_FINISHER_MULTIPLIER := 1.5
const DIZZY_EXTRA_SPREAD := 14.0
const PICKUP_RANGE := 2.4
const HELD_STATUS_INTERVAL := 0.5
## Tolerancia de cooldown en el servidor (latencia y relojes distintos).
const COOLDOWN_TOLERANCE := 0.08
const CONE_FX_INTERVAL := 0.2
const FISTS: WeaponData = preload("res://weapons/data/punos.tres")

var weapon: WeaponData = FISTS
var ammo: int = -1
## Momento (CombatComponent.now()) en que la habilidad vuelve a estar lista, según el dueño.
var local_ability_ready_at := 0.0

# Predicción local del dueño.
var _local_next_attack := 0.0
var _local_combo := 0
var _local_last_light := -10.0

# Estado en el servidor.
var _next_attack := 0.0
var _next_ability := 0.0
var _combo := 0
var _last_light := -10.0
var _held_status_timer := 0.0
var _last_cone_fx := 0.0
var _sweeps: Array[Sweep] = []
var _landing_callback := Callable()
var _landing_deadline := 0.0
var _rng := RandomNumberGenerator.new()

@onready var player: Player = get_parent()


## Área que daña a quien toque durante un rato (dashes).
class Sweep:
	var remaining: float
	var radius: float
	var damage: float
	var knockback: float
	var status: StatusEffect
	var cause: StringName
	var already_hit: Dictionary = {}


static func now() -> float:
	return Time.get_ticks_msec() / 1000.0


func _ready() -> void:
	_rng.randomize()
	# Los hijos corren _ready antes que el Player: se busca el nodo directamente.
	if multiplayer.is_server():
		(get_parent().get_node("Health") as HealthComponent).died.connect(_on_died)


func _physics_process(delta: float) -> void:
	if not multiplayer.is_server():
		return
	_process_sweeps(delta)
	if _landing_callback.is_valid() and now() > _landing_deadline:
		_server_landed()
	_held_status_timer -= delta
	if _held_status_timer <= 0.0:
		_held_status_timer = HELD_STATUS_INTERVAL
		var held := get_held_status()
		if held and player.health.is_alive():
			player.status.apply(held, player.peer_id, HELD_STATUS_INTERVAL * 2.5)


# --- Consultas ---------------------------------------------------------------

func is_signature() -> bool:
	return weapon.is_signature_for(player.character)


func get_attack_cooldown(heavy: bool) -> float:
	var seconds := weapon.cooldown
	if heavy:
		seconds *= weapon.heavy_cooldown_multiplier
	if is_signature():
		seconds *= weapon.signature_cooldown_multiplier
	return seconds


func get_damage(heavy: bool) -> float:
	var base := weapon.projectile.damage if weapon.kind == WeaponData.Kind.RANGED else weapon.damage
	if heavy:
		base *= weapon.heavy_damage_multiplier
	if weapon.signature_character != &"":
		base *= weapon.signature_damage_multiplier if is_signature() else weapon.non_signature_damage_multiplier
	return base


func get_hit_status() -> StatusEffect:
	if is_signature() and weapon.signature_hit_status:
		return weapon.signature_hit_status
	if weapon.hit_status:
		return weapon.hit_status
	if weapon.projectile:
		return weapon.projectile.hit_status
	return null


func get_held_status() -> StatusEffect:
	if weapon.signature_character == &"" or is_signature():
		return null
	return weapon.non_signature_held_status


# --- Pedidos del dueño -------------------------------------------------------

func request_attack(heavy: bool, aim: Vector3) -> void:
	var t := now()
	if t < _local_next_attack or not player.can_attack():
		return
	_local_next_attack = t + get_attack_cooldown(heavy)
	var combo := 1
	if not heavy and weapon.kind == WeaponData.Kind.MELEE:
		_local_combo = (_local_combo % 3) + 1 if t - _local_last_light <= COMBO_WINDOW else 1
		_local_last_light = t
		combo = _local_combo
	_play_action(_attack_animation(heavy, combo), _attack_kind(heavy), _action_duration(heavy))
	if multiplayer.is_server():
		_server_attack(heavy, aim)
	else:
		_rpc_attack.rpc_id(1, heavy, aim)


func request_ability(aim: Vector3) -> void:
	var ability := player.character.ability
	if ability == null:
		return
	var t := now()
	if t < local_ability_ready_at or not player.can_use_ability():
		return
	local_ability_ready_at = t + ability.cooldown
	_play_action(ability.animation, PlayerStateMachine.State.SPECIAL, ability.action_duration)
	if multiplayer.is_server():
		_server_ability(aim)
	else:
		_rpc_ability.rpc_id(1, aim)


func request_interact() -> void:
	if multiplayer.is_server():
		server_try_pickup()
	else:
		_rpc_interact.rpc_id(1)


## Lo llama el dueño al aterrizar después de un súper salto.
func notify_landed() -> void:
	if multiplayer.is_server():
		_server_landed()
	else:
		_rpc_landed.rpc_id(1)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_attack(heavy: bool, aim: Vector3) -> void:
	if _is_from_owner():
		_server_attack(heavy, aim)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_ability(aim: Vector3) -> void:
	if _is_from_owner():
		_server_ability(aim)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_interact() -> void:
	if _is_from_owner():
		server_try_pickup()


@rpc("any_peer", "call_remote", "reliable")
func _rpc_landed() -> void:
	if _is_from_owner():
		_server_landed()


func _is_from_owner() -> bool:
	return multiplayer.is_server() and multiplayer.get_remote_sender_id() == player.peer_id


# --- Servidor: ataques --------------------------------------------------------

func _server_attack(heavy: bool, aim: Vector3) -> void:
	var t := now()
	if t < _next_attack - COOLDOWN_TOLERANCE or not player.can_attack():
		return
	_next_attack = t + get_attack_cooldown(heavy)
	if weapon.uses_ammo():
		if ammo <= 0:
			return
		ammo -= 1
		_sync_ammo.rpc(ammo)

	var combo := 1
	if not heavy and weapon.kind == WeaponData.Kind.MELEE:
		_combo = (_combo % 3) + 1 if t - _last_light <= COMBO_WINDOW else 1
		_last_light = t
		combo = _combo
	aim = _sanitize_aim(aim)
	_broadcast_action.rpc(_attack_animation(heavy, combo), _attack_kind(heavy), _action_duration(heavy),
		player.get_multiplayer_authority())

	match weapon.kind:
		WeaponData.Kind.MELEE:
			_after(weapon.windup * (1.6 if heavy else 1.0), _resolve_melee.bind(heavy, aim, combo))
		WeaponData.Kind.CONE:
			_resolve_melee(heavy, aim, 1)
			if t - _last_cone_fx >= CONE_FX_INTERVAL:
				_last_cone_fx = t
				Fx.broadcast(&"cone", player.get_muzzle_position(aim), atan2(aim.x, aim.z), _cone_color())
		WeaponData.Kind.RANGED:
			_after(0.05, _shoot.bind(heavy, aim))

	if weapon.uses_ammo() and ammo <= 0:
		say("¡Se me rompió!", 1.5)
		_after(0.3, server_equip.bind(FISTS, -1))


func _resolve_melee(heavy: bool, aim: Vector3, combo: int) -> void:
	if not player.health.is_alive():
		return
	var reach := weapon.reach * (weapon.signature_range_multiplier if is_signature() else 1.0)
	var damage := get_damage(heavy) * (COMBO_FINISHER_MULTIPLIER if combo == 3 else 1.0)
	var knockback := weapon.knockback * (weapon.heavy_knockback_multiplier if heavy else 1.0) * (2.0 if combo == 3 else 1.0)
	var status := get_hit_status()
	var origin := player.get_chest_position()
	var flat_aim := Vector3(aim.x, 0.0, aim.z).normalized()
	var hit_someone := false

	for target in GameManager.get_alive_players():
		if target == player:
			continue
		var to_target := target.global_position - player.global_position
		if absf(to_target.y) > 2.2:
			continue
		to_target.y = 0.0
		var distance := to_target.length()
		if distance > reach + CombatSystem.TARGET_RADIUS:
			continue
		if distance > 0.4 and rad_to_deg(flat_aim.angle_to(to_target / distance)) > weapon.arc_degrees * 0.5:
			continue
		if not CombatSystem.has_line_of_sight(player.get_world_3d(), origin, target.get_chest_position()):
			continue
		var push := (to_target.normalized() + Vector3.UP * 0.35).normalized() * knockback
		CombatSystem.deal_damage(player, target, damage, weapon.id, false, push, status)
		hit_someone = true

	if not hit_someone and weapon.kind == WeaponData.Kind.MELEE and weapon.cooldown >= 0.3:
		Fx.broadcast(&"swing", origin)


func _shoot(heavy: bool, aim: Vector3) -> void:
	if not player.health.is_alive():
		return
	var spec := weapon.projectile
	var spread := weapon.spread_degrees * (weapon.signature_spread_multiplier if is_signature() else 1.0)
	if player.status.has_flag(StatusEffect.Flag.DIZZY):
		spread += DIZZY_EXTRA_SPREAD
	var damage_multiplier := get_damage(heavy) / maxf(spec.damage, 0.001)
	var origin := player.get_muzzle_position(aim)
	for i in weapon.projectile_count:
		var direction := _apply_spread(aim, spread)
		GameManager.spawn_projectile(spec, player, origin, direction, damage_multiplier, weapon.id,
			get_hit_status(), player.skin_id)
	Fx.broadcast(&"shoot", origin)


# --- Servidor: habilidad, objetos, movimiento forzado -------------------------

func _server_ability(aim: Vector3) -> void:
	var ability := player.character.ability
	var t := now()
	if ability == null or t < _next_ability - COOLDOWN_TOLERANCE or not player.can_use_ability():
		return
	_next_ability = t + ability.cooldown
	_broadcast_action.rpc(ability.animation, PlayerStateMachine.State.SPECIAL, ability.action_duration,
		player.get_multiplayer_authority())
	if ability.shout != "":
		say(ability.shout, 2.5)
	ability.activate(player, _sanitize_aim(aim))


func server_try_pickup() -> bool:
	if not player.health.is_alive():
		return false
	var pickup := GameManager.find_nearest_pickup(player.global_position, PICKUP_RANGE, &"weapon")
	if pickup == null:
		return false
	pickup.taken = true
	if weapon != FISTS:
		GameManager.spawn_pickup(&"weapon", weapon.id, player.global_position + Vector3(0.6, 0.0, 0.6), ammo)
	server_equip(DataLibrary.weapon(pickup.item_id), pickup.ammo)
	pickup.queue_free()
	Fx.broadcast(&"pickup", player.get_chest_position(), 0.0, weapon.get_rarity_color())
	if is_signature():
		say("¡Esta es MÍA!", 2.0)
	return true


func server_equip(new_weapon: WeaponData, new_ammo: int = -1) -> void:
	if new_weapon == null:
		new_weapon = FISTS
	if new_ammo < 0 and new_weapon.uses_ammo():
		new_ammo = new_weapon.ammo
	_sync_weapon.rpc(new_weapon.id, new_ammo)


## Empuja al personaje (lo aplica su dueño, que es quien lo mueve).
func push(impulse: Vector3) -> void:
	_receive_forced_motion.rpc_id(player.get_multiplayer_authority(), impulse, 0.0, 0)


func dash(velocity: Vector3, duration: float) -> void:
	_receive_forced_motion.rpc_id(player.get_multiplayer_authority(), velocity, duration, 1)


func launch(velocity: Vector3) -> void:
	_receive_forced_motion.rpc_id(player.get_multiplayer_authority(), velocity, 0.0, 2)


## Llama a callback cuando el personaje aterrice (o a los pocos segundos).
func await_landing(callback: Callable, timeout: float = 4.0) -> void:
	_landing_callback = callback
	_landing_deadline = now() + timeout


func add_sweep(duration: float, radius: float, damage: float, knockback: float, status: StatusEffect, cause: StringName) -> void:
	var sweep := Sweep.new()
	sweep.remaining = duration
	sweep.radius = radius
	sweep.damage = damage
	sweep.knockback = knockback
	sweep.status = status
	sweep.cause = cause
	_sweeps.append(sweep)


## Muestra un globo de texto sobre el personaje en todos los peers.
func say(text: String, seconds: float = 3.0) -> void:
	if multiplayer.is_server():
		_say.rpc(text, seconds)


func _server_landed() -> void:
	if not _landing_callback.is_valid():
		return
	var callback := _landing_callback
	_landing_callback = Callable()
	callback.call()


func _process_sweeps(delta: float) -> void:
	for sweep in _sweeps:
		sweep.remaining -= delta
		for target in CombatSystem.players_in_radius(player.global_position, sweep.radius, player):
			if sweep.already_hit.has(target):
				continue
			sweep.already_hit[target] = true
			var away := target.global_position - player.global_position
			away.y = 0.0
			var push := (away.normalized() + Vector3.UP * 0.4).normalized() * sweep.knockback
			CombatSystem.deal_damage(player, target, sweep.damage, sweep.cause, false, push, sweep.status)
	_sweeps.assign(_sweeps.filter(func(sweep: Sweep) -> bool: return sweep.remaining > 0.0))


func _on_died(_cause: StringName, _killer_id: int) -> void:
	_sweeps.clear()
	_landing_callback = Callable()
	if weapon != FISTS:
		GameManager.spawn_pickup(&"weapon", weapon.id, player.global_position, ammo)
		server_equip(FISTS)


# --- Utilidades ---------------------------------------------------------------

func _attack_kind(heavy: bool) -> PlayerStateMachine.State:
	return PlayerStateMachine.State.HEAVY_ATTACK if heavy else PlayerStateMachine.State.LIGHT_ATTACK


func _attack_animation(heavy: bool, combo: int) -> StringName:
	if weapon.kind != WeaponData.Kind.MELEE:
		return &"holding-both-shoot" if weapon.two_handed else &"holding-right-shoot"
	if heavy:
		return &"attack-kick-right" if weapon == FISTS else &"attack-melee-right"
	match combo:
		2:
			return &"attack-melee-left" if weapon == FISTS else &"attack-melee-right"
		3:
			return &"attack-kick-left"
	return &"attack-melee-right"


func _action_duration(heavy: bool) -> float:
	return clampf(get_attack_cooldown(heavy), 0.15, 0.6)


func _sanitize_aim(aim: Vector3) -> Vector3:
	if aim.length() < 0.1:
		return -player.global_basis.z
	aim = aim.normalized()
	aim.y = clampf(aim.y, -0.6, 0.6)
	return aim.normalized()


func _apply_spread(direction: Vector3, degrees: float) -> Vector3:
	if degrees <= 0.0:
		return direction
	var angle := deg_to_rad(degrees)
	var side := direction.cross(Vector3.UP).normalized()
	return direction.rotated(Vector3.UP, _rng.randf_range(-angle, angle)) \
		.rotated(side, _rng.randf_range(-angle, angle) * 0.5).normalized()


func _cone_color() -> Color:
	return Color(1.0, 0.45, 0.1) if weapon.visual == &"flamethrower" else Color(1.0, 0.95, 0.3, 0.7)


func _after(seconds: float, callback: Callable) -> void:
	get_tree().create_timer(seconds, false).timeout.connect(callback)


func _play_action(animation: StringName, kind: PlayerStateMachine.State, duration: float) -> void:
	action_played.emit(animation, kind, duration)


# --- RPC servidor → peers ------------------------------------------------------

## predicted_by: peer que ya la reprodujo por predicción (no la repite).
@rpc("authority", "call_local", "reliable")
func _broadcast_action(animation: StringName, kind: int, duration: float, predicted_by: int) -> void:
	if predicted_by != multiplayer.get_unique_id():
		_play_action(animation, kind as PlayerStateMachine.State, duration)


@rpc("authority", "call_local", "reliable")
func _sync_weapon(weapon_id: StringName, new_ammo: int) -> void:
	var new_weapon := DataLibrary.weapon(weapon_id)
	weapon = new_weapon if new_weapon else FISTS
	ammo = new_ammo
	_combo = 0
	_local_combo = 0
	weapon_changed.emit(weapon)
	ammo_changed.emit(ammo)


@rpc("authority", "call_local", "reliable")
func _sync_ammo(new_ammo: int) -> void:
	ammo = new_ammo
	ammo_changed.emit(ammo)


## mode: 0 = empujón, 1 = dash, 2 = súper salto.
@rpc("authority", "call_local", "reliable")
func _receive_forced_motion(velocity: Vector3, duration: float, mode: int) -> void:
	match mode:
		0:
			player.apply_knockback(velocity)
		1:
			player.start_dash(velocity, duration)
		2:
			player.start_launch(velocity)


@rpc("authority", "call_local", "reliable")
func _say(text: String, seconds: float) -> void:
	player.show_bubble(text, seconds)
