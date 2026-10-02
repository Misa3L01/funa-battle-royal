class_name StatusComponent
extends Node
## Efectos de estado activos de un personaje.
##
## El servidor los aplica, los vence y hace el daño/curación por tiempo. Los
## clientes reciben la lista para la UI y las animaciones, y para que el dueño
## respete aturdimientos y lentitud al moverse. Autoridad de red: servidor.

signal changed

## Cada cuánto se aplica el daño y la curación por tiempo.
const TICK_SECONDS := 0.5

var _active: Dictionary[StringName, ActiveEffect] = {}
var _tick_accumulator := 0.0

@onready var _health: HealthComponent = get_parent().get_node("Health")


class ActiveEffect:
	var effect: StatusEffect
	var remaining: float
	var source_id: int

	func _init(p_effect: StatusEffect, p_remaining: float, p_source_id: int) -> void:
		effect = p_effect
		remaining = p_remaining
		source_id = p_source_id


func _ready() -> void:
	_health.died.connect(func(_cause: StringName, _killer: int) -> void: clear_all())


func _physics_process(delta: float) -> void:
	if _active.is_empty():
		return
	# Todos los peers descuentan el tiempo (para la UI); solo el servidor vence y aplica.
	for active: ActiveEffect in _active.values():
		active.remaining -= delta
	if not multiplayer.is_server():
		return

	_tick_accumulator += delta
	if _tick_accumulator >= TICK_SECONDS:
		_apply_ticks(_tick_accumulator)
		_tick_accumulator = 0.0

	var expired: Array[StringName] = []
	for effect_id: StringName in _active:
		if _active[effect_id].remaining <= 0.0:
			expired.append(effect_id)
	if not expired.is_empty():
		for effect_id in expired:
			_active.erase(effect_id)
		_broadcast()


## Aplica un efecto (o lo renueva si ya lo tenía). Solo en el servidor.
## [param duration]: -1 usa la duración del efecto.
func apply(effect: StatusEffect, source_id: int = 0, duration: float = -1.0) -> void:
	if effect == null or not multiplayer.is_server() or not _health.is_alive():
		return
	var seconds := effect.duration if duration < 0.0 else duration
	var existing: ActiveEffect = _active.get(effect.id)
	if existing:
		existing.source_id = source_id
		# Solo se avisa si se alarga bastante: renovar cada medio segundo no ensucia la red.
		if seconds > existing.remaining + 0.5:
			existing.remaining = seconds
			_broadcast()
		else:
			existing.remaining = maxf(existing.remaining, seconds)
		return
	_active[effect.id] = ActiveEffect.new(effect, seconds, source_id)
	_broadcast()


func remove(effect_id: StringName) -> void:
	if multiplayer.is_server() and _active.erase(effect_id):
		_broadcast()


## Saca todos los efectos negativos (vacuna, habilidades de limpieza).
func cure_negative() -> void:
	if not multiplayer.is_server():
		return
	var removed := false
	for effect_id: StringName in _active.keys():
		if _active[effect_id].effect.is_negative():
			_active.erase(effect_id)
			removed = true
	if removed:
		_broadcast()


func clear_all() -> void:
	if multiplayer.is_server() and not _active.is_empty():
		_active.clear()
		_broadcast()


func has_flag(flag_mask: int) -> bool:
	for active: ActiveEffect in _active.values():
		if active.effect.has_flag(flag_mask):
			return true
	return false


func has_effect(effect_id: StringName) -> bool:
	return _active.has(effect_id)


func get_move_speed_multiplier() -> float:
	var result := 1.0
	for active: ActiveEffect in _active.values():
		result *= active.effect.move_speed_multiplier
	return result


func get_damage_dealt_multiplier() -> float:
	var result := 1.0
	for active: ActiveEffect in _active.values():
		result *= active.effect.damage_dealt_multiplier
	return result


func get_damage_taken_multiplier() -> float:
	var result := 1.0
	for active: ActiveEffect in _active.values():
		result *= active.effect.damage_taken_multiplier
	return result


func get_active_effects() -> Array[ActiveEffect]:
	var result: Array[ActiveEffect] = []
	result.assign(_active.values())
	return result


func _apply_ticks(elapsed: float) -> void:
	var damage := 0.0
	var heal := 0.0
	var cause := &""
	var source_id := 0
	for active: ActiveEffect in _active.values():
		if active.effect.damage_per_second > 0.0:
			damage += active.effect.damage_per_second * elapsed
			cause = active.effect.id
			source_id = active.source_id
		heal += active.effect.heal_per_second * elapsed
	if damage > 0.0 and not has_flag(StatusEffect.Flag.INVULNERABLE):
		_health.apply_damage(damage * get_damage_taken_multiplier(), cause, source_id)
	if heal > 0.0:
		_health.heal(heal)


func _broadcast() -> void:
	var ids: Array[StringName] = []
	var remaining := PackedFloat32Array()
	for active: ActiveEffect in _active.values():
		ids.append(active.effect.id)
		remaining.append(active.remaining)
	_sync.rpc(ids, remaining)
	changed.emit()


@rpc("authority", "call_remote", "reliable")
func _sync(ids: Array, remaining: PackedFloat32Array) -> void:
	_active.clear()
	for i in ids.size():
		var effect := DataLibrary.status(StringName(ids[i]))
		if effect:
			_active[effect.id] = ActiveEffect.new(effect, remaining[i], 0)
	changed.emit()
