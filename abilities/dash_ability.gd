class_name DashAbility
extends AbilityData
## Embestida hacia adelante. Puede dañar y empujar a quien atraviesa
## (¡AFUERA! de Pilei) o solo esquivar (Gambeta de Pessi).

@export var speed: float = 14.0
@export var duration: float = 0.3
@export var damage: float = 0.0
@export var knockback: float = 0.0
@export var hit_radius: float = 1.7
@export var hit_status: StatusEffect
@export var self_status: StatusEffect


func activate(user: Player, aim: Vector3) -> void:
	var direction := flat_direction(aim, user)
	user.combat.dash(direction * speed, duration)
	if self_status:
		user.status.apply(self_status, user.peer_id)
	if damage > 0.0 or hit_status:
		user.combat.add_sweep(duration + 0.15, hit_radius, damage, knockback, hit_status, id)
	Fx.broadcast(&"dash", user.get_chest_position(), 0.0, Color(1, 1, 1, 0.8))
