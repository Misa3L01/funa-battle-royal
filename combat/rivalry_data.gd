class_name RivalryData
extends Resource
## Relación entre dos personajes: rivales (se pegan más fuerte) o aliados
## (se pegan menos). Se activa cuando están cerca: dicen sus frases y, mientras
## estén en rango, el daño entre ellos se multiplica.

enum Kind { RIVAL, ALLY }

@export var display_name: String = "La Grieta"
@export var kind: Kind = Kind.RIVAL
@export var character_a: StringName
@export var character_b: StringName
## Multiplica el daño que se hacen entre ellos (1.25 = +25%).
@export var damage_multiplier: float = 1.25
@export var activation_range: float = 12.0
@export var line_a: String
@export var line_b: String


func involves(first: StringName, second: StringName) -> bool:
	return (first == character_a and second == character_b) or (first == character_b and second == character_a)
