class_name ProjectileAbility
extends AbilityData
## Tira un proyectil especial (Té de Polonio, Misil de Prueba).

@export var projectile: ProjectileSpec


func activate(user: Player, aim: Vector3) -> void:
	var direction := aim.normalized() if aim.length() > 0.1 else flat_direction(aim, user)
	# Los proyectiles con gravedad salen un poco hacia arriba, como tirados a mano.
	if projectile.gravity > 0.0:
		direction = (direction + Vector3.UP * 0.25).normalized()
	GameManager.spawn_projectile(projectile, user, user.get_muzzle_position(direction), direction, 1.0, id)
