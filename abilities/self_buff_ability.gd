class_name SelfBuffAbility
extends AbilityData
## Efecto sobre uno mismo (Complejo de Altura, Huelga de Hambre, Siesta,
## Abrazos no balazos, Ping Pong, Almuerzo con Mirta).

@export var statuses: Array[StatusEffect] = []
@export var heal: float = 0.0
@export var cures_negative := false
@export var fx_color: Color = Color(1, 1, 1, 0.6)


func activate(user: Player, _aim: Vector3) -> void:
	if cures_negative:
		user.status.cure_negative()
	for effect in statuses:
		user.status.apply(effect, user.peer_id)
	if heal > 0.0:
		user.health.heal(heal)
	Fx.broadcast(&"buff", user.global_position + Vector3.UP * 0.2, 1.8, fx_color)
