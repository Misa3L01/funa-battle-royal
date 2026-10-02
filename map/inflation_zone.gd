class_name InflationZone
extends Node3D
## "La Inflación": la zona de battle royale que se achica por fases. Afuera
## todo aumenta (el daño por segundo sube en cada fase).
##
## El servidor decide cada fase (centro y radio nuevos) y la manda a todos;
## cada peer anima el círculo localmente. El daño lo aplica solo el servidor.

## Se emite en todos los peers al empezar una fase.
signal phase_started(index: int, wait: float, shrink: float)

const WALL_HEIGHT := 80.0
const DAMAGE_TICK := 1.0
const ZONE_SHADER := preload("res://map/zone.gdshader")
## wait: segundos quieta; shrink: segundos achicándose; radius: fracción del radio inicial.
const PHASES: Array[Dictionary] = [
	{"wait": 45.0, "shrink": 35.0, "radius": 0.62, "dps": 2.0},
	{"wait": 30.0, "shrink": 30.0, "radius": 0.38, "dps": 4.0},
	{"wait": 25.0, "shrink": 25.0, "radius": 0.18, "dps": 7.0},
	{"wait": 20.0, "shrink": 25.0, "radius": 0.0, "dps": 12.0},
]

var center := Vector3.ZERO
var radius := 100.0
var damage_per_second := 0.0
var phase_index := -1

var _active := false
var _elapsed := 0.0
var _wait := 0.0
var _shrink := 0.0
var _from_center := Vector3.ZERO
var _to_center := Vector3.ZERO
var _from_radius := 100.0
var _to_radius := 100.0
var _initial_radius := 100.0
var _damage_timer := 0.0
var _rng := RandomNumberGenerator.new()
var _wall: MeshInstance3D


func _ready() -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 1.0
	mesh.bottom_radius = 1.0
	mesh.height = WALL_HEIGHT
	mesh.radial_segments = 96
	mesh.cap_top = false
	mesh.cap_bottom = false
	var material := ShaderMaterial.new()
	material.shader = ZONE_SHADER
	_wall = MeshInstance3D.new()
	_wall.mesh = mesh
	_wall.material_override = material
	_wall.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_wall.visible = false
	add_child(_wall)


## Arranca la zona. Solo en el servidor.
func start(initial_center: Vector3, initial_radius: float) -> void:
	if not multiplayer.is_server():
		return
	_rng.randomize()
	_initial_radius = initial_radius
	_begin_phase(0, initial_center, initial_radius)


func stop() -> void:
	_active = false
	_wall.visible = false


func is_active() -> bool:
	return _active


## Metros fuera de la zona (negativo = adentro, a esa distancia del borde).
func distance_outside(point: Vector3) -> float:
	return Vector2(point.x - center.x, point.z - center.z).length() - radius


func is_shrinking() -> bool:
	return _active and _elapsed >= _wait


## Segundos hasta el próximo cambio (empieza a achicarse o termina de hacerlo).
func seconds_to_next_change() -> float:
	if _elapsed < _wait:
		return _wait - _elapsed
	return maxf(_wait + _shrink - _elapsed, 0.0)


func has_remaining_phases() -> bool:
	return _active and phase_index < PHASES.size() - 1


## Hiperinflación: la fase actual se achica ya y al doble de velocidad. Solo en el servidor.
func hyperinflate() -> void:
	if not multiplayer.is_server() or not _active:
		return
	var remaining_shrink := _wait + _shrink - _elapsed if _elapsed >= _wait else _shrink
	_sync_phase.rpc(phase_index, center, radius, _to_center, _to_radius, 0.0, maxf(remaining_shrink * 0.5, 5.0), damage_per_second * 1.5)


func _process(delta: float) -> void:
	if not _active:
		return
	_elapsed += delta
	var t := clampf((_elapsed - _wait) / maxf(_shrink, 0.001), 0.0, 1.0)
	center = _from_center.lerp(_to_center, t)
	radius = lerpf(_from_radius, _to_radius, t)
	_wall.position = Vector3(center.x, WALL_HEIGHT * 0.5 - 10.0, center.z)
	_wall.scale = Vector3(maxf(radius, 0.1), 1.0, maxf(radius, 0.1))

	if not multiplayer.is_server():
		return
	_damage_timer -= delta
	if _damage_timer <= 0.0:
		_damage_timer = DAMAGE_TICK
		for player in GameManager.get_alive_players():
			if distance_outside(player.global_position) > 0.0:
				player.health.apply_damage(damage_per_second * DAMAGE_TICK, &"inflacion")
	if _elapsed >= _wait + _shrink and phase_index < PHASES.size() - 1:
		_begin_phase(phase_index + 1, _to_center, _to_radius)


func _begin_phase(index: int, from_center: Vector3, from_radius: float) -> void:
	var phase: Dictionary = PHASES[index]
	var to_radius: float = _initial_radius * phase["radius"]
	# El centro nuevo cae dentro del círculo actual, para que siempre se pueda llegar.
	var max_offset := maxf(from_radius - to_radius, 0.0) * 0.6
	var angle := _rng.randf() * TAU
	var offset := Vector3(cos(angle), 0.0, sin(angle)) * _rng.randf() * max_offset
	var to_center := from_center + offset
	if GameManager.island:
		to_center.y = GameManager.island.height_at(to_center.x, to_center.z)
	_sync_phase.rpc(index, from_center, from_radius, to_center, to_radius, phase["wait"], phase["shrink"], phase["dps"])


@rpc("authority", "call_local", "reliable")
func _sync_phase(index: int, from_center: Vector3, from_radius: float, to_center: Vector3, to_radius: float,
		wait: float, shrink: float, dps: float) -> void:
	phase_index = index
	_from_center = from_center
	_from_radius = from_radius
	_to_center = to_center
	_to_radius = to_radius
	_wait = wait
	_shrink = shrink
	damage_per_second = dps
	_elapsed = 0.0
	_active = true
	_wall.visible = true
	center = from_center
	radius = from_radius
	phase_started.emit(index, wait, shrink)
