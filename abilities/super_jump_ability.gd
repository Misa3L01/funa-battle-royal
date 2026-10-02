class_name SuperJumpAbility
extends AbilityData
## Súper salto con golpe al caer (Cohete a Marte de Elon Musgo).

@export var jump_velocity: float = 13.0
@export var forward_speed: float = 8.0
@export var slam_radius: float = 4.5
@export var slam_damage: float = 25.0
@export var slam_knockback: float = 12.0
@export var slam_status: StatusEffect


func activate(user: Player, aim: Vector3) -> void:
	var direction := flat_direction(aim, user)
	user.combat.launch(direction * forward_speed + Vector3.UP * jump_velocity)
	user.combat.await_landing(_slam.bind(user))
	Fx.broadcast(&"launch", user.global_position, 0.0, Color(1.0, 0.6, 0.2))


func _slam(user: Player) -> void:
	if not is_instance_valid(user) or not user.health.is_alive():
		return
	CombatSystem.explode(user, user.global_position, slam_radius, slam_damage, slam_knockback, id, slam_status, false)
