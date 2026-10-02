class_name PlayerController
extends Node
## Intención del personaje en este frame. La llena un humano (HumanController)
## o un bot (BotController); Player la convierte en movimiento y acciones.

## Dirección de movimiento en el mundo (largo 0 a 1).
var move_direction := Vector3.ZERO
## Hacia dónde apunta (normalizado).
var aim_direction := Vector3.FORWARD
var wants_jump := false
## Se mantiene apretado (las armas rápidas disparan mientras esté en true).
var wants_attack := false
var wants_heavy_attack := false
var wants_ability := false
var wants_interact := false

@onready var player: Player = get_parent()


func update(_delta: float) -> void:
	pass
