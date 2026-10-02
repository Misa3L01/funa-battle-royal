class_name CombatSystem
## Reglas de daño. Solo corre en el servidor.
##
## Daño final = base
##   × daño del atacante (buffs como Complejo de Altura)
##   × rivalidad si los dos están cerca (La Grieta ×1.25, Bromance ×0.75...)
##   × daño recibido del objetivo (Huelga de Hambre ×0.2, Siesta ×0.5...)
## Invulnerable → 0. "Inmune a distancia" + proyectil → 0.

## Radio aproximado del cuerpo de un personaje, para alcances y áreas.
const TARGET_RADIUS := 0.45


static func deal_damage(attacker: Player, target: Player, base_damage: float, cause: StringName,
		is_ranged := false, knockback := Vector3.ZERO, hit_status: StatusEffect = null) -> float:
	if target == null or not target.health.is_alive():
		return 0.0
	if target.status.has_flag(StatusEffect.Flag.INVULNERABLE) \
			or (is_ranged and target.status.has_flag(StatusEffect.Flag.IMMUNE_RANGED)):
		Fx.broadcast(&"block", target.get_chest_position())
		return 0.0

	var attacker_id := 0
	var amount := base_damage
	if attacker:
		attacker_id = attacker.peer_id
		amount *= attacker.status.get_damage_dealt_multiplier()
		amount *= GameManager.get_rivalry_multiplier(attacker, target)
	amount *= target.status.get_damage_taken_multiplier()

	if amount > 0.0:
		target.health.apply_damage(amount, cause, attacker_id)
		Fx.broadcast(&"hit", target.get_chest_position(), amount)
	if knockback != Vector3.ZERO and target.health.is_alive():
		target.combat.push(knockback)
	if hit_status:
		target.status.apply(hit_status, attacker_id)
	return amount


static func players_in_radius(center: Vector3, radius: float, exclude: Player = null) -> Array[Player]:
	var result: Array[Player] = []
	for player in GameManager.get_alive_players():
		if player != exclude and player.global_position.distance_to(center) <= radius + TARGET_RADIUS:
			result.append(player)
	return result


## Explosión con daño y empuje que bajan con la distancia (hasta 40% en el borde).
static func explode(attacker: Player, center: Vector3, radius: float, damage: float, knockback: float,
		cause: StringName, status: StatusEffect = null, hurts_attacker := false) -> void:
	for target in players_in_radius(center, radius):
		if target == attacker and not hurts_attacker:
			continue
		var offset := target.global_position - center
		var falloff := 1.0 - clampf(offset.length() / (radius + TARGET_RADIUS), 0.0, 1.0) * 0.6
		offset.y = 0.0
		var away := offset.normalized() if offset.length() > 0.1 else Vector3.FORWARD
		var push := (away + Vector3.UP * 0.7).normalized() * knockback * falloff
		deal_damage(attacker, target, damage * falloff, cause, false, push, status)
	Fx.broadcast(&"explosion", center, radius)


static func has_line_of_sight(world: World3D, from: Vector3, to: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(from, to, Layers.WORLD)
	return world.direct_space_state.intersect_ray(query).is_empty()
