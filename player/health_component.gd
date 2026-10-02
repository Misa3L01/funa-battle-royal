class_name HealthComponent
extends Node
## Vida de un personaje.
##
## Solo el servidor puede modificarla; los clientes reciben el valor por RPC.
## Por eso su autoridad de red es siempre el servidor (peer 1), aunque el
## Player que la contiene pertenezca a otro peer.

signal health_changed(current: float, maximum: float)
## Se emite en todos los peers. amount > 0 es daño; < 0 es curación.
signal health_delta(amount: float, attacker_id: int)
## Se emite en todos los peers cuando la vida llega a 0.
signal died(cause: StringName, killer_id: int)

@export var max_health: float = 100.0

var current_health: float = 100.0
## id del atacante -> momento del último golpe (ms). Solo en el servidor.
var recent_attackers: Dictionary[int, int] = {}


## Inicializa la vida localmente. Todos los peers la llaman con los mismos
## datos al crear el personaje, así que no hace falta sincronizarla.
func setup(new_max_health: float) -> void:
	max_health = new_max_health
	current_health = new_max_health
	health_changed.emit(current_health, max_health)


func is_alive() -> bool:
	return current_health > 0.0


func get_ratio() -> float:
	return current_health / max_health


## Resta vida. Solo tiene efecto en el servidor.
func apply_damage(amount: float, cause: StringName, attacker_id: int = 0) -> void:
	if not _can_modify() or amount <= 0.0 or not is_alive():
		return
	if attacker_id != 0:
		recent_attackers[attacker_id] = Time.get_ticks_msec()
	_sync_health.rpc(maxf(current_health - amount, 0.0), cause, attacker_id)


## Suma vida sin pasar del máximo. Solo en el servidor.
func heal(amount: float) -> void:
	if not _can_modify() or amount <= 0.0 or not is_alive() or current_health >= max_health:
		return
	_sync_health.rpc(minf(current_health + amount, max_health), &"heal", 0)


## Mata al instante (caídas, tiburones, muerte por edad). Solo en el servidor.
func kill(cause: StringName, attacker_id: int = 0) -> void:
	if not _can_modify() or not is_alive():
		return
	_sync_health.rpc(0.0, cause, attacker_id)


func attacked_recently(attacker_id: int, seconds: float) -> bool:
	return recent_attackers.has(attacker_id) \
		and Time.get_ticks_msec() - recent_attackers[attacker_id] <= seconds * 1000.0


func _can_modify() -> bool:
	if multiplayer.is_server():
		return true
	push_warning("HealthComponent: solo el servidor puede modificar la vida.")
	return false


@rpc("authority", "call_local", "reliable")
func _sync_health(new_health: float, cause: StringName, attacker_id: int) -> void:
	var was_alive := is_alive()
	var delta := current_health - new_health
	current_health = new_health
	health_changed.emit(current_health, max_health)
	if not is_zero_approx(delta):
		health_delta.emit(delta, attacker_id)
	if was_alive and not is_alive():
		died.emit(cause, attacker_id)
