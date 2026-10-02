class_name PlayerStateMachine
extends Node
## Máquina de estados del personaje: decide qué animación toca y cuánto se
## puede mover.
##
## Prioridad: Muerto > Aturdido > acción en curso (ataques, especial) > movimiento.
## Corre en todos los peers: en el dueño limita el movimiento; en todos elige
## la animación.

signal state_changed(previous: State, current: State)

enum State { IDLE, RUN, AIR, LIGHT_ATTACK, HEAVY_ATTACK, SPECIAL, STUNNED, DEAD }

const RUN_THRESHOLD := 0.6
## Cuánto se puede mover mientras ataca: pegar compromete.
const ACTION_MOVE_MULTIPLIERS := {
	State.LIGHT_ATTACK: 0.55,
	State.HEAVY_ATTACK: 0.3,
	State.SPECIAL: 0.7,
}

var state: State = State.IDLE

var _action_state: State = State.IDLE
var _action_until := 0.0


## Arranca un estado de acción (ataque o especial) que dura unos segundos.
func start_action(action_state: State, duration: float) -> void:
	_action_state = action_state
	_action_until = CombatComponent.now() + duration


func update(on_floor: bool, horizontal_speed: float, is_stunned: bool, is_dead: bool) -> void:
	var next := _resolve(on_floor, horizontal_speed, is_stunned, is_dead)
	if next != state:
		var previous := state
		state = next
		state_changed.emit(previous, next)


func get_move_multiplier() -> float:
	return ACTION_MOVE_MULTIPLIERS.get(state, 1.0)


func is_in_action() -> bool:
	return state in [State.LIGHT_ATTACK, State.HEAVY_ATTACK, State.SPECIAL]


func _resolve(on_floor: bool, horizontal_speed: float, is_stunned: bool, is_dead: bool) -> State:
	if is_dead:
		return State.DEAD
	if is_stunned:
		return State.STUNNED
	if CombatComponent.now() < _action_until:
		return _action_state
	if not on_floor:
		return State.AIR
	return State.RUN if horizontal_speed > RUN_THRESHOLD else State.IDLE
