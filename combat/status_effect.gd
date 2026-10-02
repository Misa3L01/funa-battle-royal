class_name StatusEffect
extends Resource
## Efecto de estado con duración (buff o debuff): mareo, veneno, COVID...
##
## Cada efecto es un .tres en res://combat/statuses/. Por la red viaja solo su
## id y cada peer lo busca en DataLibrary.

## Banderas de comportamiento. Se combinan (por ejemplo, aturdido + invulnerable).
enum Flag {
	STUNNED = 1,        ## No puede moverse, atacar ni usar la habilidad.
	SILENCED = 2,       ## No puede usar la habilidad.
	DISARMED = 4,       ## No puede atacar.
	INVULNERABLE = 8,   ## No recibe daño.
	REFLECT = 16,       ## Devuelve los proyectiles al que los tiró.
	IMMUNE_RANGED = 32, ## Los proyectiles no le hacen daño.
	DIZZY = 64,         ## Pantalla mareada y peor puntería.
	ROOTED = 128,       ## No puede moverse, pero sí atacar.
}

## Banderas que vuelven negativo a un efecto (las cura la vacuna).
const NEGATIVE_FLAGS := Flag.STUNNED | Flag.SILENCED | Flag.DISARMED | Flag.DIZZY | Flag.ROOTED

@export var id: StringName
@export var display_name: String
@export var color: Color = Color.WHITE
@export var duration: float = 3.0
@export_flags("Aturdido", "Silenciado", "Desarmado", "Invulnerable", "Refleja", "Inmune a distancia", "Mareado", "Inmóvil")
var flags: int = 0

@export_group("Modificadores")
@export var damage_per_second: float = 0.0
@export var heal_per_second: float = 0.0
@export var move_speed_multiplier: float = 1.0
@export var damage_dealt_multiplier: float = 1.0
@export var damage_taken_multiplier: float = 1.0


func has_flag(flag: int) -> bool:
	return (flags & flag) != 0


func is_negative() -> bool:
	return damage_per_second > 0.0 or move_speed_multiplier < 1.0 \
		or damage_dealt_multiplier < 1.0 or damage_taken_multiplier > 1.0 \
		or (flags & NEGATIVE_FLAGS) != 0
