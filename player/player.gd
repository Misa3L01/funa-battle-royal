class_name Player
extends CharacterBody3D
## Personaje en red (humano o bot).
##
## Autoridad: el dueño mueve su personaje (el humano en su PC, o el servidor
## si es bot) y replica posición, giro y velocidad con el MultiplayerSynchronizer.
## Vida, efectos, armas y golpes los decide el servidor: los componentes
## Health, Status y Combat siempre tienen autoridad 1.
##
## Es "movimiento con autoridad del cliente": responde al instante y es simple,
## pero permite trampas de velocidad. Si el ranking llega a dar premios,
## conviene pasar la autoridad del movimiento al servidor.

const JUMP_VELOCITY := 6.5
const TURN_SPEED := 14.0
const CAMERA_HEIGHT := 1.9
const WATER_LEVEL := 0.0
## Profundidad a la que empieza a flotar (nadar).
const SWIM_DEPTH := 1.1
const WATER_SPEED_MULTIPLIER := 0.55
## Más allá de este radio desde el centro de la isla hay tiburones.
const SHARK_RADIUS := 118.0
const FALL_LIMIT_Y := -30.0
## Qué tan rápido los personajes remotos alcanzan su posición replicada.
const REMOTE_SMOOTHING := 15.0
const KNOCKBACK_DECAY := 5.0
## Tras atacar, el personaje mira hacia donde apunta durante este tiempo.
const AIM_FACE_SECONDS := 0.6

var peer_id: int = 1
var is_bot := false
var character: CharacterData
var skin_id: StringName = &"clasica"
var controller: PlayerController
var in_water := false

## Estado replicado: lo escribe el dueño y lo leen los demás peers.
var sync_position: Vector3
var sync_yaw: float
var sync_speed: float
var sync_on_floor := true

var _knockback := Vector3.ZERO
var _dash_velocity := Vector3.ZERO
var _dash_until := 0.0
var _is_launched := false
var _left_ground_after_launch := false
var _face_aim_until := 0.0
var _ragdoll: RigidBody3D
var _camera_target: Node3D
var _bubble_tween: Tween

@onready var health: HealthComponent = $Health
@onready var status: StatusComponent = $Status
@onready var combat: CombatComponent = $Combat
@onready var state_machine: PlayerStateMachine = $StateMachine
@onready var model: CharacterModel = $Visuals/Model
@onready var name_label: Label3D = $NameLabel
@onready var status_label: Label3D = $StatusLabel
@onready var bubble: Label3D = $Bubble
@onready var lamp: OmniLight3D = $Lamp
@onready var camera_pivot: Node3D = $CameraPivot
@onready var spring_arm: SpringArm3D = $CameraPivot/SpringArm3D
@onready var camera: Camera3D = $CameraPivot/SpringArm3D/Camera3D


## Se llama en todos los peers antes de agregar el nodo al árbol.
func setup(p_peer_id: int, data: CharacterData, spawn_position: Vector3, p_is_bot := false, p_skin_id := &"clasica") -> void:
	peer_id = p_peer_id
	is_bot = p_is_bot
	character = data
	skin_id = p_skin_id
	name = ("bot_%d" % peer_id) if is_bot else str(peer_id)
	position = spawn_position
	sync_position = spawn_position


func get_authority_id() -> int:
	return 1 if is_bot else peer_id


func _enter_tree() -> void:
	set_multiplayer_authority(get_authority_id())
	# Vida, efectos y combate los decide siempre el servidor.
	for component in [$Health, $Status, $Combat]:
		component.set_multiplayer_authority(1)


func _ready() -> void:
	collision_layer = Layers.PLAYERS
	collision_mask = Layers.WORLD | Layers.PLAYERS
	health.setup(character.max_health)
	health.died.connect(_on_died)
	health.health_delta.connect(_on_health_delta)
	status.changed.connect(_refresh_status_label)
	combat.weapon_changed.connect(_on_weapon_changed)
	combat.action_played.connect(_on_action_played)
	model.build(character)
	model.set_weapon(combat.weapon, DataLibrary.skin(skin_id))
	name_label.text = get_display_name()
	status_label.text = ""
	bubble.hide()
	lamp.hide()

	if is_multiplayer_authority():
		controller = BotController.new() if is_bot else HumanController.new()
		controller.name = "Controller"
		add_child(controller)
	if is_local_human():
		camera.current = true
		spring_arm.add_excluded_object(get_rid())
		spring_arm.collision_mask = Layers.WORLD
		spring_arm.rotation.x = deg_to_rad(-18.0)
		camera_pivot.rotation.y = rotation.y
		camera_pivot.global_position = global_position + Vector3.UP * CAMERA_HEIGHT
		name_label.hide()
	else:
		camera_pivot.queue_free()
		camera_pivot = null
		spring_arm = null
		camera = null


func is_local_human() -> bool:
	return is_multiplayer_authority() and not is_bot


func _physics_process(delta: float) -> void:
	var alive := health.is_alive()
	if is_multiplayer_authority():
		if alive:
			controller.update(delta)
			_handle_actions()
			_move(delta)
	elif alive:
		_follow_replicated_state(delta)

	var horizontal_speed := Vector2(velocity.x, velocity.z).length() if is_multiplayer_authority() else sync_speed
	var on_floor := is_on_floor() if is_multiplayer_authority() else sync_on_floor
	state_machine.update(on_floor, horizontal_speed, status.has_flag(StatusEffect.Flag.STUNNED), not alive)
	model.update_locomotion(state_machine.state, horizontal_speed)

	if multiplayer.is_server() and alive:
		_check_hazards()
	if camera_pivot:
		_update_camera(delta)


# --- Acciones y movimiento (dueño) --------------------------------------------

func _handle_actions() -> void:
	var aim := controller.aim_direction
	if controller.wants_attack:
		combat.request_attack(false, aim)
	if controller.wants_heavy_attack:
		combat.request_attack(true, aim)
	if controller.wants_ability:
		combat.request_ability(aim)
	if controller.wants_interact:
		combat.request_interact()
	if controller.wants_attack or controller.wants_heavy_attack or controller.wants_ability:
		_face_aim_until = CombatComponent.now() + AIM_FACE_SECONDS


func _move(delta: float) -> void:
	var now := CombatComponent.now()
	in_water = global_position.y < WATER_LEVEL - 0.3
	var swimming := global_position.y < WATER_LEVEL - SWIM_DEPTH
	if swimming:
		# Flotar: empujar hacia la superficie en vez de hundirse.
		velocity.y = lerpf(velocity.y, (WATER_LEVEL - SWIM_DEPTH - global_position.y) * 3.0, 0.2)
	elif not is_on_floor():
		velocity += get_gravity() * delta

	if _is_launched:
		velocity.x = _dash_velocity.x
		velocity.z = _dash_velocity.z
	elif now < _dash_until:
		velocity.x = _dash_velocity.x
		velocity.z = _dash_velocity.z
	else:
		var direction := controller.move_direction if can_move() else Vector3.ZERO
		if direction.length() > 1.0:
			direction = direction.normalized()
		var speed := character.move_speed * status.get_move_speed_multiplier() * state_machine.get_move_multiplier()
		if in_water:
			speed *= WATER_SPEED_MULTIPLIER
		velocity.x = direction.x * speed + _knockback.x
		velocity.z = direction.z * speed + _knockback.z
		if controller.wants_jump and can_move() and (is_on_floor() or swimming):
			velocity.y = JUMP_VELOCITY

	_knockback = _knockback.lerp(Vector3.ZERO, clampf(KNOCKBACK_DECAY * delta, 0.0, 1.0))
	move_and_slide()

	if _is_launched:
		if not is_on_floor():
			_left_ground_after_launch = true
		elif _left_ground_after_launch:
			_is_launched = false
			combat.notify_landed()

	_update_facing(delta)
	sync_position = global_position
	sync_yaw = rotation.y
	sync_speed = Vector2(velocity.x, velocity.z).length()
	sync_on_floor = is_on_floor()


func _update_facing(delta: float) -> void:
	var target_yaw := rotation.y
	var aim := controller.aim_direction
	if CombatComponent.now() < _face_aim_until and Vector2(aim.x, aim.z).length() > 0.1:
		target_yaw = atan2(-aim.x, -aim.z)
	elif Vector2(velocity.x, velocity.z).length() > 0.5:
		target_yaw = atan2(-velocity.x, -velocity.z)
	rotation.y = lerp_angle(rotation.y, target_yaw, clampf(TURN_SPEED * delta, 0.0, 1.0))


func _follow_replicated_state(delta: float) -> void:
	# Suavizado exponencial: evita que los demás se vean a los saltos.
	var weight := 1.0 - exp(-REMOTE_SMOOTHING * delta)
	global_position = global_position.lerp(sync_position, weight)
	rotation.y = lerp_angle(rotation.y, sync_yaw, weight)


## Empujón recibido (golpes, explosiones). Lo aplica el dueño.
func apply_knockback(impulse: Vector3) -> void:
	_knockback += Vector3(impulse.x, 0.0, impulse.z)
	velocity.y = maxf(velocity.y, impulse.y)


func start_dash(dash_velocity: Vector3, duration: float) -> void:
	_dash_velocity = dash_velocity
	_dash_until = CombatComponent.now() + duration


func start_launch(launch_velocity: Vector3) -> void:
	_is_launched = true
	_left_ground_after_launch = false
	_dash_velocity = launch_velocity
	velocity = launch_velocity


func _check_hazards() -> void:
	if global_position.y < FALL_LIMIT_Y:
		health.kill(&"caida")
	elif Vector2(global_position.x, global_position.z).length() > SHARK_RADIUS:
		health.kill(&"tiburon")


# --- Consultas ----------------------------------------------------------------

func can_attack() -> bool:
	return health.is_alive() and not status.has_flag(StatusEffect.Flag.STUNNED | StatusEffect.Flag.DISARMED)


func can_use_ability() -> bool:
	return health.is_alive() and not status.has_flag(StatusEffect.Flag.STUNNED | StatusEffect.Flag.SILENCED)


func can_move() -> bool:
	return health.is_alive() and not status.has_flag(StatusEffect.Flag.STUNNED | StatusEffect.Flag.ROOTED)


func has_tag(tag: StringName) -> bool:
	return character.has_tag(tag)


func get_display_name() -> String:
	return character.display_name + (" [BOT]" if is_bot else "")


func get_chest_position() -> Vector3:
	return global_position + Vector3.UP * 1.1


func get_muzzle_position(aim: Vector3) -> Vector3:
	var flat := Vector3(aim.x, 0.0, aim.z).normalized()
	return global_position + Vector3.UP * 1.25 + flat * 0.6


## Velocidad aproximada, también para personajes remotos (para que los bots anticipen).
func get_estimated_velocity() -> Vector3:
	if is_multiplayer_authority():
		return velocity
	return Vector3(-sin(sync_yaw), 0.0, -cos(sync_yaw)) * sync_speed


# --- Visual -------------------------------------------------------------------

func show_bubble(text: String, seconds: float) -> void:
	if not health.is_alive():
		return
	bubble.text = "«%s»" % text
	bubble.modulate.a = 1.0
	bubble.show()
	if _bubble_tween:
		_bubble_tween.kill()
	_bubble_tween = create_tween()
	_bubble_tween.tween_interval(seconds)
	_bubble_tween.tween_property(bubble, "modulate:a", 0.0, 0.4)
	_bubble_tween.tween_callback(bubble.hide)


func spectate_next() -> void:
	_camera_target = GameManager.get_next_alive_player(_camera_target as Player)


func _update_camera(delta: float) -> void:
	var focus := global_position
	if not health.is_alive():
		if _camera_target == null or not is_instance_valid(_camera_target) \
				or (_camera_target is Player and not (_camera_target as Player).health.is_alive()):
			_camera_target = GameManager.get_next_alive_player(null)
			if _camera_target == null:
				_camera_target = _ragdoll
		if _camera_target:
			focus = _camera_target.global_position
		camera_pivot.global_position = camera_pivot.global_position.lerp(focus + Vector3.UP * CAMERA_HEIGHT, 1.0 - exp(-6.0 * delta))
	else:
		camera_pivot.global_position = focus + Vector3.UP * CAMERA_HEIGHT


func _refresh_status_label() -> void:
	var names := PackedStringArray()
	var color := Color.WHITE
	for active in status.get_active_effects():
		if active.effect.display_name != "":
			if names.is_empty():
				color = active.effect.color
			names.append(active.effect.display_name.to_upper())
	status_label.text = " · ".join(names)
	status_label.modulate = color


func _on_health_delta(amount: float, _attacker_id: int) -> void:
	if amount > 0.0:
		model.flash()


func _on_weapon_changed(new_weapon: WeaponData) -> void:
	model.set_weapon(new_weapon, DataLibrary.skin(skin_id))


func _on_action_played(animation: StringName, kind: PlayerStateMachine.State, duration: float) -> void:
	state_machine.start_action(kind, duration)
	model.play_action(animation, duration)


func _on_died(cause: StringName, killer_id: int) -> void:
	name_label.hide()
	status_label.hide()
	bubble.hide()
	lamp.hide()
	collision_layer = 0
	velocity = Vector3.ZERO
	# Sale volando lejos de quien lo mató (y bien alto si fue la bomba).
	var impulse := Vector3.UP * 5.0
	var killer := GameManager.get_player(killer_id)
	if killer and killer != self:
		var away := global_position - killer.global_position
		away.y = 0.0
		impulse += away.normalized() * 7.0
		_camera_target = killer
	if cause == &"nuclear_strike":
		impulse = Vector3(randf_range(-4, 4), 16.0, randf_range(-4, 4))
	_ragdoll = model.detach_as_ragdoll(impulse)
	if _camera_target == null:
		_camera_target = _ragdoll
