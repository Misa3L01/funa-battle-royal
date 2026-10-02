extends Node
## Fx (Autoload): sonidos y efectos visuales, todos generados por código.
##
## Todo se reproduce localmente. El servidor usa broadcast() para que lo vean
## y escuchen todos los peers. Los sonidos se sintetizan al arrancar (sin
## archivos de audio); se pueden reemplazar por .ogg cuando existan.

signal camera_shake_requested(strength: float, origin: Vector3)

const SAMPLE_RATE := 22050
const SOUND_MAX_DISTANCE := 70.0

var _sounds: Dictionary[StringName, AudioStreamWAV] = {}
var _rng := RandomNumberGenerator.new()
var _unshaded_cache: Dictionary = {}


func _ready() -> void:
	_rng.randomize()
	_generate_sounds()


## Solo el servidor: reproduce el efecto en todos los peers.
func broadcast(kind: StringName, position: Vector3, value: float = 0.0, color: Color = Color.WHITE) -> void:
	if multiplayer.is_server():
		_play_everywhere.rpc(kind, position, value, color)


@rpc("authority", "call_local", "reliable")
func _play_everywhere(kind: StringName, position: Vector3, value: float, color: Color) -> void:
	play(kind, position, value, color)


func play(kind: StringName, position: Vector3, value: float = 0.0, color: Color = Color.WHITE) -> void:
	if get_tree().current_scene == null:
		return
	match kind:
		&"hit":
			_sound(&"hit", position)
			_number(position, "%d" % roundi(value), Color(1.0, 0.92, 0.5) if value < 20.0 else Color(1.0, 0.45, 0.2))
			_burst(position, Color(1.0, 0.85, 0.4), 8, 3.5)
		&"block":
			_sound(&"block", position)
			_number(position, "¡BLOQUEADO!", Color(0.5, 0.9, 1.0))
		&"swing":
			_sound(&"swing", position)
		&"shoot":
			_sound(&"shoot", position)
		&"explosion":
			_sound(&"explosion", position)
			_explosion(position, value)
			camera_shake_requested.emit(0.7, position)
		&"nuke":
			_sound(&"explosion", position, 0.45)
			_mushroom_cloud(position)
			camera_shake_requested.emit(2.5, position)
		&"pickup":
			_sound(&"pickup", position)
			_burst(position, color, 10, 2.5)
		&"heal":
			_sound(&"heal", position)
			_number(position, "+%d" % roundi(value), Color(0.4, 1.0, 0.4))
		&"area":
			_sound(&"area", position)
			_ring(position, value, color)
		&"buff":
			_sound(&"buff", position)
			_ring(position, value, color)
			_burst(position + Vector3.UP, color, 14, 2.0)
		&"dash", &"launch":
			_sound(&"whoosh", position)
			_burst(position, color, 12, 3.0)
		&"reflect":
			_sound(&"ping", position)
			_number(position, "¡PING!", color)
		&"cone":
			_sound(&"flame" if color.g < 0.6 else &"honk", position)
			_cone(position, value, color)
		&"death":
			_sound(&"death", position)
			_burst(position, Color(0.6, 0.6, 0.6), 18, 4.0)
		&"puff":
			_burst(position, Color(0.8, 0.8, 0.8), 6, 1.5)
		&"siren":
			_sound(&"siren", Vector3.INF)
		&"zone_tick":
			_sound(&"zone_tick", Vector3.INF)
		&"win":
			_sound(&"win", Vector3.INF)


# --- Sonido ---------------------------------------------------------------------

func _sound(sound_name: StringName, position: Vector3, pitch := 1.0) -> void:
	if not _sounds.has(sound_name):
		return
	# Vector3.INF = sonido de interfaz (sin posición en el mundo).
	if position == Vector3.INF:
		var flat := AudioStreamPlayer.new()
		flat.stream = _sounds[sound_name]
		flat.pitch_scale = pitch
		add_child(flat)
		flat.play()
		flat.finished.connect(flat.queue_free)
		return
	var spatial := AudioStreamPlayer3D.new()
	spatial.stream = _sounds[sound_name]
	spatial.pitch_scale = pitch * _rng.randf_range(0.9, 1.1)
	spatial.unit_size = 12.0
	spatial.max_distance = SOUND_MAX_DISTANCE
	get_tree().current_scene.add_child(spatial)
	spatial.global_position = position
	spatial.play()
	spatial.finished.connect(spatial.queue_free)


func _generate_sounds() -> void:
	_sounds[&"hit"] = _synth(0.14, func(t: float, _i: int) -> float:
		return (_noise() * 0.6 + sin(TAU * 110.0 * t) * 0.8) * exp(-t * 28.0))
	_sounds[&"block"] = _synth(0.12, func(t: float, _i: int) -> float:
		return sin(TAU * 1200.0 * t) * exp(-t * 30.0) * 0.6)
	_sounds[&"swing"] = _synth(0.18, func(t: float, _i: int) -> float:
		return _noise() * sin(PI * t / 0.18) * 0.35)
	_sounds[&"whoosh"] = _synth(0.35, func(t: float, _i: int) -> float:
		return _noise() * sin(PI * t / 0.35) * 0.45)
	_sounds[&"shoot"] = _synth(0.12, func(t: float, _i: int) -> float:
		return signf(sin(TAU * lerpf(700.0, 250.0, t / 0.12) * t)) * exp(-t * 25.0) * 0.35)
	var brown := [0.0]
	_sounds[&"explosion"] = _synth(1.2, func(t: float, _i: int) -> float:
		brown[0] = clampf(brown[0] + _noise() * 0.12, -1.0, 1.0)
		return brown[0] * exp(-t * 3.5) * 1.6)
	_sounds[&"pickup"] = _synth(0.18, func(t: float, _i: int) -> float:
		var frequency := 660.0 if t < 0.08 else 990.0
		return sin(TAU * frequency * t) * 0.45 * exp(-fmod(t, 0.08) * 10.0))
	_sounds[&"heal"] = _synth(0.3, func(t: float, _i: int) -> float:
		var notes := [523.25, 659.25, 783.99]
		return sin(TAU * notes[mini(int(t / 0.1), 2)] * t) * 0.35 * exp(-fmod(t, 0.1) * 8.0))
	_sounds[&"area"] = _synth(0.5, func(t: float, _i: int) -> float:
		return sin(TAU * lerpf(180.0, 60.0, t / 0.5) * t) * exp(-t * 5.0) * 0.8)
	_sounds[&"buff"] = _synth(0.4, func(t: float, _i: int) -> float:
		return sin(TAU * lerpf(300.0, 900.0, t / 0.4) * t) * exp(-t * 4.0) * 0.4)
	_sounds[&"ping"] = _synth(0.3, func(t: float, _i: int) -> float:
		return sin(TAU * 1500.0 * t) * exp(-t * 12.0) * 0.5)
	_sounds[&"flame"] = _synth(0.25, func(t: float, _i: int) -> float:
		return _noise() * 0.35 * (1.0 - t / 0.25))
	_sounds[&"honk"] = _synth(0.3, func(t: float, _i: int) -> float:
		return signf(sin(TAU * 233.0 * t)) * 0.25 * (1.0 - t / 0.3))
	_sounds[&"death"] = _synth(0.5, func(t: float, _i: int) -> float:
		return signf(sin(TAU * lerpf(400.0, 80.0, t / 0.5) * t)) * 0.3 * (1.0 - t / 0.5))
	_sounds[&"siren"] = _synth(2.4, func(t: float, _i: int) -> float:
		var frequency := 650.0 + 250.0 * sin(TAU * t / 1.2)
		return sin(TAU * frequency * t) * 0.35)
	_sounds[&"zone_tick"] = _synth(0.06, func(t: float, _i: int) -> float:
		return sin(TAU * 880.0 * t) * 0.25)
	_sounds[&"win"] = _synth(1.0, func(t: float, _i: int) -> float:
		var notes := [523.25, 659.25, 783.99, 1046.5]
		return sin(TAU * notes[mini(int(t / 0.2), 3)] * t) * 0.35 * exp(-fmod(t, 0.2) * 3.0))


## Genera un sonido mono de 16 bits a partir de una función f(t, índice) -> [-1, 1].
func _synth(seconds: float, generator: Callable) -> AudioStreamWAV:
	var count := int(seconds * SAMPLE_RATE)
	var data := PackedByteArray()
	data.resize(count * 2)
	for i in count:
		var value: float = generator.call(float(i) / SAMPLE_RATE, i)
		data.encode_s16(i * 2, int(clampf(value, -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = SAMPLE_RATE
	wav.stereo = false
	wav.data = data
	return wav


func _noise() -> float:
	return _rng.randf_range(-1.0, 1.0)


# --- Visual ---------------------------------------------------------------------

func _number(position: Vector3, text: String, color: Color) -> void:
	var label := Label3D.new()
	label.text = text
	label.modulate = color
	label.font_size = 56
	label.outline_size = 14
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.fixed_size = true
	label.pixel_size = 0.0012
	get_tree().current_scene.add_child(label)
	label.global_position = position + Vector3(_rng.randf_range(-0.4, 0.4), 0.4, _rng.randf_range(-0.4, 0.4))
	var tween := label.create_tween().set_parallel()
	tween.tween_property(label, "global_position:y", label.global_position.y + 1.2, 0.8)
	tween.tween_property(label, "modulate:a", 0.0, 0.8).set_delay(0.3)
	tween.chain().tween_callback(label.queue_free)


func _burst(position: Vector3, color: Color, amount: int, speed: float) -> void:
	var particles := CPUParticles3D.new()
	particles.one_shot = true
	particles.emitting = false
	particles.amount = amount
	particles.lifetime = 0.6
	particles.explosiveness = 1.0
	particles.direction = Vector3.UP
	particles.spread = 180.0
	particles.initial_velocity_min = speed * 0.5
	particles.initial_velocity_max = speed
	particles.gravity = Vector3(0, -9.0, 0)
	particles.scale_amount_min = 0.6
	particles.scale_amount_max = 1.2
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE * 0.12
	particles.mesh = mesh
	particles.material_override = _unshaded(color)
	get_tree().current_scene.add_child(particles)
	particles.global_position = position
	particles.emitting = true
	get_tree().create_timer(1.0).timeout.connect(particles.queue_free)


func _explosion(position: Vector3, radius: float) -> void:
	var sphere := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	sphere.mesh = mesh
	var material := _unshaded(Color(1.0, 0.55, 0.1, 0.9), true)
	sphere.material_override = material
	get_tree().current_scene.add_child(sphere)
	sphere.global_position = position
	sphere.scale = Vector3.ONE * 0.3
	var tween := sphere.create_tween().set_parallel()
	tween.tween_property(sphere, "scale", Vector3.ONE * maxf(radius, 1.0), 0.25).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tween.tween_property(sphere, "transparency", 1.0, 0.45)
	tween.chain().tween_callback(sphere.queue_free)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.6, 0.2)
	light.light_energy = 6.0
	light.omni_range = radius * 3.0
	get_tree().current_scene.add_child(light)
	light.global_position = position + Vector3.UP
	var light_tween := light.create_tween()
	light_tween.tween_property(light, "light_energy", 0.0, 0.5)
	light_tween.tween_callback(light.queue_free)
	_burst(position, Color(0.3, 0.3, 0.3), 20, radius * 2.0)


## Hongo nuclear gigante que se ve desde toda la isla.
func _mushroom_cloud(position: Vector3) -> void:
	var root := Node3D.new()
	get_tree().current_scene.add_child(root)
	root.global_position = position
	var fire := _unshaded(Color(1.0, 0.6, 0.2, 1.0), true)
	var stem := MeshInstance3D.new()
	var stem_mesh := CylinderMesh.new()
	stem_mesh.top_radius = 5.0
	stem_mesh.bottom_radius = 9.0
	stem_mesh.height = 40.0
	stem.mesh = stem_mesh
	stem.material_override = fire
	stem.position.y = 20.0
	root.add_child(stem)
	var cap := MeshInstance3D.new()
	var cap_mesh := SphereMesh.new()
	cap_mesh.radius = 20.0
	cap_mesh.height = 22.0
	cap.mesh = cap_mesh
	cap.material_override = fire
	cap.position.y = 42.0
	root.add_child(cap)
	root.scale = Vector3.ONE * 0.1
	var tween := root.create_tween()
	tween.tween_property(root, "scale", Vector3.ONE, 2.5).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(fire, "albedo_color", Color(0.45, 0.42, 0.4, 0.85), 4.0)
	tween.tween_property(fire, "albedo_color:a", 0.0, 3.0)
	tween.tween_callback(root.queue_free)


func _ring(position: Vector3, radius: float, color: Color) -> void:
	var ring := MeshInstance3D.new()
	var mesh := TorusMesh.new()
	mesh.inner_radius = 0.85
	mesh.outer_radius = 1.0
	mesh.rings = 32
	ring.mesh = mesh
	ring.material_override = _unshaded(color, true)
	get_tree().current_scene.add_child(ring)
	ring.global_position = position
	ring.scale = Vector3(0.2, 1.0, 0.2)
	var tween := ring.create_tween().set_parallel()
	tween.tween_property(ring, "scale", Vector3(radius, 1.0, radius), 0.35).set_ease(Tween.EASE_OUT)
	tween.tween_property(ring, "transparency", 1.0, 0.5)
	tween.chain().tween_callback(ring.queue_free)


## Cono de partículas (llamas del lanzallamas, ondas de la vuvuzela). yaw: hacia dónde apunta.
func _cone(position: Vector3, yaw: float, color: Color) -> void:
	var particles := CPUParticles3D.new()
	particles.one_shot = true
	particles.emitting = false
	particles.amount = 24
	particles.lifetime = 0.4
	particles.explosiveness = 0.6
	particles.direction = Vector3(sin(yaw), 0.05, cos(yaw))
	particles.spread = 18.0
	particles.initial_velocity_min = 9.0
	particles.initial_velocity_max = 14.0
	particles.gravity = Vector3(0, 2.0, 0)
	particles.scale_amount_min = 1.0
	particles.scale_amount_max = 2.5
	var mesh := SphereMesh.new()
	mesh.radius = 0.12
	mesh.height = 0.24
	particles.mesh = mesh
	particles.material_override = _unshaded(color, true)
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 1))
	fade.set_color(1, Color(1, 1, 1, 0))
	particles.color_ramp = fade
	get_tree().current_scene.add_child(particles)
	particles.global_position = position
	particles.emitting = true
	get_tree().create_timer(1.0).timeout.connect(particles.queue_free)


func _unshaded(color: Color, unique := false) -> StandardMaterial3D:
	var key := color.to_html()
	if not unique and _unshaded_cache.has(key):
		return _unshaded_cache[key]
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	material.vertex_color_use_as_albedo = true
	if color.a < 1.0 or unique:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if not unique:
		_unshaded_cache[key] = material
	return material
