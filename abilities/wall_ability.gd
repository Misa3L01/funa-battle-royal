class_name WallAbility
extends AbilityData
## Levanta un muro delante del personaje (El Muro de Tromp). Frena
## personajes y proyectiles hasta que se cae solo.

@export var width: float = 6.0
@export var height: float = 3.2
@export var distance: float = 3.0
@export var lifetime: float = 8.0


func activate(user: Player, aim: Vector3) -> void:
	var direction := flat_direction(aim, user)
	var position := user.global_position + direction * distance
	position.y = GameManager.ground_height(position)
	GameManager.spawn_wall(position, atan2(direction.x, direction.z), width, height, lifetime)
