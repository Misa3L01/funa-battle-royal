class_name AreaEffectAbility
extends AbilityData
## Onda alrededor del personaje: aplica efectos a los enemigos en el radio
## (Cadena Nacional, Relatividad, Nube Verde).

@export var radius: float = 7.0
@export var damage: float = 0.0
@export var knockback: float = 0.0
@export var enemy_statuses: Array[StatusEffect] = []
@export var self_statuses: Array[StatusEffect] = []
@export var self_heal: float = 0.0
@export var fx_color: Color = Color(1, 1, 1, 0.6)


func activate(user: Player, _aim: Vector3) -> void:
	for target in CombatSystem.players_in_radius(user.global_position, radius, user):
		var push := Vector3.ZERO
		if knockback > 0.0:
			var away := target.global_position - user.global_position
			away.y = 0.0
			push = (away.normalized() + Vector3.UP * 0.4).normalized() * knockback
		CombatSystem.deal_damage(user, target, damage, id, false, push)
		for effect in enemy_statuses:
			target.status.apply(effect, user.peer_id)
	for effect in self_statuses:
		user.status.apply(effect, user.peer_id)
	if self_heal > 0.0:
		user.health.heal(self_heal)
	Fx.broadcast(&"area", user.global_position + Vector3.UP * 0.3, radius, fx_color)
