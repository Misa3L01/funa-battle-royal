class_name HyperinflationEvent
extends GlobalEvent
## Hiperinflación: La Inflación (la zona) se achica ya y al doble de
## velocidad. Más probable cuantos más argentinos haya en la partida.

@export var trigger_tag: StringName = CharacterTags.ARGENTINO
## Probabilidad que aporta cada personaje con la tag.
@export_range(0.0, 1.0) var probability_per_character: float = 0.2


func get_match_probability(players: Array[Player]) -> float:
	return 1.0 - pow(1.0 - probability_per_character, count_with_tag(players, trigger_tag))


func can_execute(_players: Array[Player]) -> bool:
	return GameManager.zone != null and GameManager.zone.is_active()


func execute(_players: Array[Player], _rng: RandomNumberGenerator) -> String:
	GameManager.zone.hyperinflate()
	return ""
