class_name Projectile
extends Node3D
## Proyectil en red.
##
## Todos los peers lo mueven igual a partir de los mismos datos de spawn (sin
## sincronizar cada frame). Solo el servidor detecta impactos, aplica el daño y
## lo destruye; el MultiplayerSpawner lo borra en los clientes. Si rebota o lo
## refleja el Ping Pong, el servidor manda la nueva trayectoria.

var data: Dictionary
var owner_id: int

var _velocity: Vector3
var _age := 0.0
var _bounces_left := 0
var _spin := 0.0
var _visual: Node3D
var _finished := false


func setup(spawn_data: Dictionary) -> void:
	data = spawn_data
	name = spawn_data["name"]
	owner_id = spawn_data["owner"]
	position = spawn_data["origin"]
	_velocity = spawn_data["velocity"]
	_bounces_left = spawn_data["bounces"]
	_spin = spawn_data["spin"]


func _ready() -> void:
	_visual = WeaponVisuals.build_projectile(data["visual"], data["radius"], DataLibrary.skin(data["skin"]))
	add_child(_visual)
	_orient()


func _physics_process(delta: float) -> void:
	_age += delta
	var from := global_position
	_velocity.y -= float(data["gravity"]) * delta
	global_position = from + _velocity * delta
	_orient()
	if _spin != 0.0:
		_visual.rotate_object_local(Vector3.RIGHT, TAU * _spin * delta)
	if not multiplayer.is_server() or _finished:
		return

	if _age >= float(data["lifetime"]):
		_impact(global_position, null)
		return
	var query := PhysicsRayQueryParameters3D.create(from, global_position, Layers.WORLD)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		if _bounces_left > 0:
			_bounces_left -= 1
			_velocity = _velocity.bounce(hit.normal) * 0.7
			global_position = hit.position + hit.normal * 0.05
			_redirect.rpc(global_position, _velocity, owner_id)
		else:
			_impact(hit.position, null)
		return
	for target in GameManager.get_alive_players():
		if target.peer_id == owner_id or not _touches(from, global_position, target):
			continue
		if target.status.has_flag(StatusEffect.Flag.REFLECT):
			_reflect(target)
		else:
			_impact(global_position, target)
		return


func _touches(from: Vector3, to: Vector3, target: Player) -> bool:
	var bottom := target.global_position + Vector3.UP * 0.35
	var top := target.global_position + Vector3.UP * 1.6
	var closest := Geometry3D.get_closest_points_between_segments(from, to, bottom, top)
	return closest[0].distance_to(closest[1]) <= float(data["radius"]) + CombatSystem.TARGET_RADIUS


func _reflect(target: Player) -> void:
	var original := GameManager.get_player(owner_id)
	var speed := _velocity.length()
	var direction := -_velocity.normalized()
	if original and original.health.is_alive():
		direction = (original.get_chest_position() - global_position).normalized()
	owner_id = target.peer_id
	_velocity = direction * speed * 1.2
	_age = 0.0
	_redirect.rpc(global_position, _velocity, owner_id)
	Fx.broadcast(&"reflect", global_position, 0.0, Color(1, 0.3, 0.3))


func _impact(at: Vector3, target: Player) -> void:
	_finished = true
	var attacker := GameManager.get_player(owner_id)
	var status_id: StringName = data["status"]
	var status := DataLibrary.status(status_id) if status_id != &"" else null
	var damage: float = data["damage"]
	var knockback: float = data["knockback"]
	var explosion: float = data["explosion"]
	if explosion > 0.0:
		CombatSystem.explode(attacker, at, explosion, damage, knockback, data["cause"], status)
	elif target:
		var push := Vector3(_velocity.x, 0.0, _velocity.z).normalized()
		push = (push + Vector3.UP * 0.3).normalized() * knockback
		CombatSystem.deal_damage(attacker, target, damage, data["cause"], true, push, status)
	else:
		Fx.broadcast(&"puff", at)
	queue_free()


func _orient() -> void:
	if _velocity.length() > 0.1 and _visual:
		var up := Vector3.UP if absf(_velocity.normalized().y) < 0.99 else Vector3.RIGHT
		look_at(global_position + _velocity, up)


@rpc("authority", "call_remote", "reliable")
func _redirect(new_position: Vector3, new_velocity: Vector3, new_owner: int) -> void:
	global_position = new_position
	_velocity = new_velocity
	owner_id = new_owner
