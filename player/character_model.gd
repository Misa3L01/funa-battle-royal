class_name CharacterModel
extends Node3D
## Parte visual del personaje: cuerpo Kenney Mini Characters (CC0) con la
## cabeza oculta, cara garabato en billboard encima, arma en la mano derecha y
## animaciones según la máquina de estados. Al morir se suelta como un cuerpo
## físico que sale volando ("ragdoll" de un solo cuerpo).

const MODEL_SCALE := 2.6
const BLEND_SECONDS := 0.12
## Tamaño y altura de la cara, en unidades del modelo (antes de MODEL_SCALE).
const FACE_SIZE := 0.46
const FACE_OFFSET_Y := 0.17
const FACE_SHADER := preload("res://player/face_billboard.gdshader")
const LOOPING_ANIMATIONS: Array[StringName] = [&"idle", &"walk", &"sprint"]

var _animation_player: AnimationPlayer
var _skeleton: Skeleton3D
var _face_material: ShaderMaterial
var _flash_material: StandardMaterial3D
var _weapon_mount: Node3D
var _weapon_visual: Node3D
var _arm_pose: ArmPoseModifier
var _stars: Node3D
var _current_animation := &""
var _action_until := 0.0
var _flash_tween: Tween
var _is_ragdoll := false


func build(character: CharacterData) -> void:
	var model := character.body_model.instantiate() as Node3D
	var scale_factor := MODEL_SCALE * character.body_scale
	model.scale = Vector3.ONE * scale_factor
	model.rotation.y = PI  # Los modelos Kenney miran a +Z; el juego usa -Z como adelante.
	add_child(model)
	_skeleton = model.find_child("Skeleton3D", true, false) as Skeleton3D
	_animation_player = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	for animation_name in LOOPING_ANIMATIONS:
		if _animation_player.has_animation(animation_name):
			_animation_player.get_animation(animation_name).loop_mode = Animation.LOOP_LINEAR

	var head_mesh := _skeleton.get_node_or_null("head-mesh") as MeshInstance3D
	if head_mesh:
		head_mesh.visible = false
	_flash_material = StandardMaterial3D.new()
	_flash_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_flash_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_flash_material.albedo_color = Color(1, 1, 1, 0)
	var body_mesh := _skeleton.get_node_or_null("body-mesh") as MeshInstance3D
	if body_mesh:
		body_mesh.material_overlay = _flash_material

	_build_face(character.face_texture)
	_build_weapon_mount(scale_factor)
	_build_stars()
	_arm_pose = ArmPoseModifier.new()
	_skeleton.add_child(_arm_pose)
	_arm_pose.setup(_skeleton)
	_arm_pose.active = false
	_play(&"idle", 1.0)


func set_weapon(weapon: WeaponData, skin: WeaponSkin) -> void:
	if _weapon_visual:
		_weapon_visual.queue_free()
	_weapon_visual = WeaponVisuals.build(weapon.visual, skin)
	_weapon_mount.add_child(_weapon_visual)
	_arm_pose.active = weapon.kind != WeaponData.Kind.MELEE
	_arm_pose.both_arms = weapon.two_handed


func update_locomotion(state: PlayerStateMachine.State, horizontal_speed: float) -> void:
	if _is_ragdoll:
		return
	_stars.visible = state == PlayerStateMachine.State.STUNNED
	if _stars.visible:
		_stars.rotate_y(0.15)
	if CombatComponent.now() < _action_until:
		return
	match state:
		PlayerStateMachine.State.IDLE:
			_play(&"idle", 1.0)
		PlayerStateMachine.State.RUN:
			if horizontal_speed > 5.0:
				_play(&"sprint", clampf(horizontal_speed / 7.0, 0.7, 1.5))
			else:
				_play(&"walk", clampf(horizontal_speed / 3.0, 0.6, 1.7))
		PlayerStateMachine.State.AIR:
			_play(&"jump", 1.0)
		PlayerStateMachine.State.STUNNED:
			_play(&"idle", 0.3)


## Reproduce una animación de acción (golpe, disparo, habilidad) que dure como mucho duration.
func play_action(animation: StringName, duration: float) -> void:
	if _is_ragdoll or not _animation_player.has_animation(animation):
		return
	var length := _animation_player.get_animation(animation).length
	var speed := maxf(1.0, length / maxf(duration, 0.05))
	_animation_player.play(animation, 0.05)
	_animation_player.seek(0.0, true)
	_animation_player.speed_scale = speed
	_current_animation = animation
	_action_until = CombatComponent.now() + length / speed


func flash() -> void:
	if _flash_tween:
		_flash_tween.kill()
	_flash_material.albedo_color.a = 0.75
	_face_material.set_shader_parameter("flash", 0.8)
	_flash_tween = create_tween().set_parallel()
	_flash_tween.tween_property(_flash_material, "albedo_color:a", 0.0, 0.18)
	_flash_tween.tween_method(func(value: float) -> void: _face_material.set_shader_parameter("flash", value), 0.8, 0.0, 0.18)


## Suelta el modelo como un cuerpo físico que sale despedido. Solo visual (cada
## peer simula el suyo). Devuelve el cuerpo para que la cámara pueda seguirlo.
func detach_as_ragdoll(impulse: Vector3) -> RigidBody3D:
	_is_ragdoll = true
	_stars.visible = false
	_arm_pose.active = false
	var body := RigidBody3D.new()
	body.collision_layer = Layers.DEBRIS
	body.collision_mask = Layers.WORLD
	body.mass = 3.0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.9, 1.3, 0.7)
	shape.shape = box
	shape.position.y = 0.65
	body.add_child(shape)
	get_tree().current_scene.add_child(body)
	body.global_transform = global_transform
	reparent(body)
	body.apply_central_impulse(impulse * body.mass)
	body.apply_torque_impulse(Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * 6.0)
	if _animation_player.has_animation(&"die"):
		_animation_player.speed_scale = 1.0
		_animation_player.play(&"die", 0.05)
	return body


func _play(animation: StringName, speed: float) -> void:
	_animation_player.speed_scale = speed
	if _current_animation != animation:
		_current_animation = animation
		_animation_player.play(animation, BLEND_SECONDS)


func _build_face(texture: Texture2D) -> void:
	var head_attachment := BoneAttachment3D.new()
	head_attachment.bone_name = "head"
	_skeleton.add_child(head_attachment)
	var quad := QuadMesh.new()
	quad.size = Vector2(FACE_SIZE, FACE_SIZE)
	_face_material = ShaderMaterial.new()
	_face_material.shader = FACE_SHADER
	_face_material.set_shader_parameter("face_texture", texture)
	var face := MeshInstance3D.new()
	face.name = "Face"
	face.mesh = quad
	face.material_override = _face_material
	face.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	face.position = Vector3(0.0, FACE_OFFSET_Y, 0.0)
	head_attachment.add_child(face)


func _build_weapon_mount(scale_factor: float) -> void:
	var hand := BoneAttachment3D.new()
	hand.bone_name = "arm-right"
	_skeleton.add_child(hand)
	# El arma se construye en metros y apuntando a -Z; acá se alinea con el
	# brazo (-Y del hueso) y se deshace la escala del modelo.
	_weapon_mount = Node3D.new()
	_weapon_mount.position = Vector3(0.0, -0.12, 0.0)
	_weapon_mount.rotation.x = -PI * 0.5
	_weapon_mount.scale = Vector3.ONE / scale_factor
	hand.add_child(_weapon_mount)


func _build_stars() -> void:
	_stars = Node3D.new()
	_stars.position.y = 2.1
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(1.0, 0.9, 0.2)
	var mesh := SphereMesh.new()
	mesh.radius = 0.08
	mesh.height = 0.16
	for i in 3:
		var star := MeshInstance3D.new()
		star.mesh = mesh
		star.material_override = material
		var angle := TAU * i / 3.0
		star.position = Vector3(cos(angle) * 0.45, 0.0, sin(angle) * 0.45)
		_stars.add_child(star)
	_stars.visible = false
	add_child(_stars)
