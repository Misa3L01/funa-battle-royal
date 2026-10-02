class_name DiseaseEvent
extends GlobalEvent
## Enfermedad (COVID): aplica un efecto de estado (daño por tiempo y lentitud)
## solo a los personajes de riesgo. Si no hay nadie de riesgo, no ocurre.

@export var target_tag: StringName = CharacterTags.GRUPO_DE_RIESGO
## Probabilidad por partida si hay al menos un personaje con la tag.
@export_range(0.0, 1.0) var probability: float = 0.4
@export var status: StatusEffect


func get_match_probability(players: Array[Player]) -> float:
	return probability if count_with_tag(players, target_tag) > 0 else 0.0


func execute(players: Array[Player], _rng: RandomNumberGenerator) -> String:
	var infected := filter_by_tag(players, target_tag)
	if infected.is_empty():
		return "Por suerte no quedaba nadie de riesgo."
	for player in infected:
		player.status.apply(status)
	return "Contagiados: %s (¡busquen una vacuna!)" % join_names(infected)
