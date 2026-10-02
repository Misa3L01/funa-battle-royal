class_name BlackoutEvent
extends GlobalEvent
## Apagón: se hace de noche un rato. Cada peer oscurece su escena y prende
## una linterna sobre cada personaje (ver Arena). No cambia reglas.

@export_range(0.0, 1.0) var probability: float = 0.3
@export var duration: float = 35.0


func get_match_probability(_players: Array[Player]) -> float:
	return probability


func execute(_players: Array[Player], _rng: RandomNumberGenerator) -> String:
	return ""
