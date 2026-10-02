class_name HumanController
extends PlayerController
## Controles del jugador local: teclado + mouse o mando.
## Cámara en tercera persona sobre el hombro; se apunta al centro de la pantalla.

const MOUSE_SENSITIVITY := 0.003
const STICK_SENSITIVITY := 2.8
const MIN_PITCH_DEGREES := -65.0
const MAX_PITCH_DEGREES := 25.0
const AIM_DISTANCE := 150.0

var _shake := 0.0


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	Fx.camera_shake_requested.connect(_on_camera_shake_requested)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED
		return
	var click := event as InputEventMouseButton
	if click and click.pressed and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		return
	if click and click.pressed and not player.health.is_alive():
		player.spectate_next()
		return
	var motion := event as InputEventMouseMotion
	if motion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_rotate_camera(motion.relative * MOUSE_SENSITIVITY)


func _process(delta: float) -> void:
	var stick := Vector2(Input.get_joy_axis(0, JOY_AXIS_RIGHT_X), Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y))
	if stick.length() > 0.2:
		_rotate_camera(stick * STICK_SENSITIVITY * delta)
	if player.camera:
		_shake = move_toward(_shake, 0.0, delta * 2.5)
		player.camera.v_offset = randf_range(-1.0, 1.0) * _shake * 0.3
		player.camera.rotation.z = randf_range(-1.0, 1.0) * _shake * 0.04


func update(_delta: float) -> void:
	var captured := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	move_direction = Basis(Vector3.UP, player.camera_pivot.rotation.y) * Vector3(input.x, 0.0, input.y)
	aim_direction = _compute_aim()
	wants_jump = Input.is_action_just_pressed("jump")
	wants_attack = captured and Input.is_action_pressed("attack")
	wants_heavy_attack = captured and Input.is_action_just_pressed("heavy_attack")
	wants_ability = Input.is_action_just_pressed("ability")
	wants_interact = Input.is_action_just_pressed("interact")


func _rotate_camera(amount: Vector2) -> void:
	if player.camera_pivot == null:
		return
	player.camera_pivot.rotate_y(-amount.x)
	player.spring_arm.rotation.x = clampf(player.spring_arm.rotation.x - amount.y,
		deg_to_rad(MIN_PITCH_DEGREES), deg_to_rad(MAX_PITCH_DEGREES))


## Apunta a lo que haya en el centro de la pantalla.
func _compute_aim() -> Vector3:
	var camera := player.camera
	var forward := -camera.global_basis.z
	var from := camera.global_position
	var query := PhysicsRayQueryParameters3D.create(from, from + forward * AIM_DISTANCE, Layers.WORLD | Layers.PLAYERS)
	query.exclude = [player.get_rid()]
	var hit := player.get_world_3d().direct_space_state.intersect_ray(query)
	var target: Vector3 = hit.position if not hit.is_empty() else from + forward * AIM_DISTANCE
	var direction := (target - player.get_chest_position()).normalized()
	# Si lo apuntado queda detrás del personaje (algo muy cerca de la cámara), usar la mirada.
	return direction if direction.dot(forward) > 0.2 else forward


func _on_camera_shake_requested(strength: float, origin: Vector3) -> void:
	# Cuanto más fuerte, desde más lejos se siente (una bomba nuclear se siente en toda la isla).
	var distance := origin.distance_to(player.global_position)
	_shake = maxf(_shake, strength * clampf(1.0 - distance / (40.0 * strength), 0.0, 1.0))
