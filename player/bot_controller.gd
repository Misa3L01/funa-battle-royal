class_name BotController
extends PlayerController
## IA de bot. Corre solo en el servidor (dueño de los bots).
##
## Prioridades, de mayor a menor: volver a la zona, curarse si tiene poca vida,
## conseguir un arma si anda a las piñas, pelear con el enemigo más
## conveniente y, si no hay nadie, pasear dentro de la zona. Cada bot tiene una
## "habilidad" (skill) al azar que afecta su puntería y sus reflejos.

const THINK_MIN := 0.2
const THINK_MAX := 0.45
const SIGHT_RANGE := 45.0
const LOOT_SEARCH_RANGE := 30.0
const RANGED_PREFERRED_DISTANCE := 11.0

var skill := 0.6

var _rng := RandomNumberGenerator.new()
var _think_timer := 0.0
var _target: Player
var _goal := Vector3.ZERO
var _has_goal := false
var _goal_is_weapon := false
var _strafe_sign := 1.0
var _stuck_time := 0.0
var _detour_until := 0.0
var _detour_direction := Vector3.ZERO


func _ready() -> void:
	_rng.randomize()
	skill = _rng.randf_range(0.35, 0.85)
	_strafe_sign = 1.0 if _rng.randf() < 0.5 else -1.0


func update(delta: float) -> void:
	wants_jump = false
	wants_attack = false
	wants_heavy_attack = false
	wants_ability = false
	wants_interact = false
	_think_timer -= delta
	if _think_timer <= 0.0:
		_think_timer = _rng.randf_range(THINK_MIN, THINK_MAX) * (1.6 - skill)
		_think()
	_steer(delta)
	_fight()


func _think() -> void:
	var me := player.global_position
	_goal_is_weapon = false
	if _target and (not is_instance_valid(_target) or not _target.health.is_alive()):
		_target = null

	var zone := GameManager.zone
	if zone and zone.is_active() and zone.distance_outside(me) > -4.0:
		_target = _find_target(12.0)
		_set_goal(zone.center)
		return

	if player.health.get_ratio() < 0.4:
		var food := GameManager.find_nearest_pickup(me, LOOT_SEARCH_RANGE, &"consumable")
		if food:
			_target = null
			_set_goal(food.global_position)
			return

	_target = _find_target(SIGHT_RANGE)
	var enemy_close := _target != null and me.distance_to(_target.global_position) < 9.0
	if player.combat.weapon == CombatComponent.FISTS and not enemy_close:
		var loot := GameManager.find_nearest_pickup(me, LOOT_SEARCH_RANGE, &"weapon")
		if loot:
			_set_goal(loot.global_position)
			_goal_is_weapon = true
			return

	if _target:
		_set_goal(_target.global_position)
		if _rng.randf() < 0.15:
			_strafe_sign *= -1.0
		return

	if not _has_goal or me.distance_to(_goal) < 3.0:
		_set_goal(GameManager.random_point_in_zone(_rng))


func _steer(delta: float) -> void:
	if not _has_goal:
		move_direction = Vector3.ZERO
		return
	var me := player.global_position
	if _target and not _goal_is_weapon:
		_goal = _target.global_position
	var to_goal := _goal - me
	to_goal.y = 0.0
	var distance := to_goal.length()
	var desired := to_goal / maxf(distance, 0.001)

	var move := Vector3.ZERO
	var weapon := player.combat.weapon
	if _target and not _goal_is_weapon:
		if weapon.kind == WeaponData.Kind.RANGED:
			if distance > RANGED_PREFERRED_DISTANCE + 3.0:
				move = desired
			elif distance < RANGED_PREFERRED_DISTANCE - 5.0:
				move = -desired
			else:
				move = desired.cross(Vector3.UP) * _strafe_sign
		elif distance > weapon.reach * 0.75:
			move = desired
		else:
			move = desired.cross(Vector3.UP) * _strafe_sign * 0.3
	elif distance > 1.0:
		move = desired

	if _goal_is_weapon and distance < 1.8:
		wants_interact = true

	# Destrabarse: si quiere moverse y no avanza, salta y rodea el obstáculo.
	var now := CombatComponent.now()
	if now < _detour_until:
		move = _detour_direction
	elif move != Vector3.ZERO and Vector2(player.velocity.x, player.velocity.z).length() < 0.8:
		_stuck_time += delta
		if _stuck_time > 0.6:
			_stuck_time = 0.0
			wants_jump = true
			_detour_direction = move.rotated(Vector3.UP, 1.3 * (1.0 if _rng.randf() < 0.5 else -1.0))
			_detour_until = now + 0.9
	else:
		_stuck_time = 0.0

	if _rng.randf() < 0.003:
		wants_jump = true
	move_direction = move


func _fight() -> void:
	if _target == null or not is_instance_valid(_target) or not _target.health.is_alive():
		return
	var weapon := player.combat.weapon
	var origin := player.get_chest_position()
	var aim_point := _target.get_chest_position()
	var distance := player.global_position.distance_to(_target.global_position)

	if weapon.kind == WeaponData.Kind.RANGED:
		var flight_time := distance / weapon.projectile.speed
		aim_point += _target.get_estimated_velocity() * flight_time * skill
		aim_point.y += 0.5 * weapon.projectile.gravity * flight_time * flight_time
	var error := (1.0 - skill) * 0.09 * distance
	aim_point += Vector3(_rng.randf_range(-error, error), _rng.randf_range(-error, error) * 0.5, _rng.randf_range(-error, error))
	aim_direction = (aim_point - origin).normalized()

	var reach := 28.0 if weapon.kind == WeaponData.Kind.RANGED else weapon.reach + 0.5
	if distance <= reach:
		if weapon.kind == WeaponData.Kind.MELEE and _rng.randf() < 0.1 * skill:
			wants_heavy_attack = true
		else:
			wants_attack = true

	var ability := player.character.ability
	if ability and CombatComponent.now() >= player.combat.local_ability_ready_at and _rng.randf() < 0.05 + skill * 0.1:
		match ability.bot_hint:
			AbilityData.BotHint.CLOSE_RANGE:
				wants_ability = distance <= ability.bot_range
			AbilityData.BotHint.MID_RANGE:
				wants_ability = distance > 3.0 and distance <= ability.bot_range
			AbilityData.BotHint.DEFENSIVE:
				wants_ability = player.health.get_ratio() < 0.55 and distance < 12.0
			AbilityData.BotHint.MOBILITY:
				wants_ability = distance > 7.0 and distance <= ability.bot_range


## El enemigo más conveniente: cerca, visible y con poca vida.
func _find_target(max_distance: float) -> Player:
	var best: Player = null
	var best_score := INF
	var me := player.global_position
	for other in GameManager.get_alive_players():
		if other == player:
			continue
		var distance := me.distance_to(other.global_position)
		if distance > max_distance:
			continue
		var score := distance + other.health.get_ratio() * 8.0
		if not CombatSystem.has_line_of_sight(player.get_world_3d(), player.get_chest_position(), other.get_chest_position()):
			score += 15.0
		if other == _target:
			score -= 5.0  # No cambiar de objetivo a cada rato.
		if score < best_score:
			best_score = score
			best = other
	return best


func _set_goal(position: Vector3) -> void:
	_goal = position
	_has_goal = true
