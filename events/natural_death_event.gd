class_name NaturalDeathEvent
extends GlobalEvent
## Muerte por edad: un personaje con la tag se muere de golpe, sin aviso.

@export var target_tag: StringName = CharacterTags.MUERTE_POR_EDAD
## Probabilidad por partida de cada personaje con la tag.
@export_range(0.0, 1.0) var probability_per_character: float = 0.15


func get_match_probability(players: Array[Player]) -> float:
	# Probabilidad de que se vaya al menos uno: 1 - (1 - p)^n
	var count := count_with_tag(players, target_tag)
	return 1.0 - pow(1.0 - probability_per_character, count)


func can_execute(players: Array[Player]) -> bool:
	return count_with_tag(players, target_tag) > 0


func execute(players: Array[Player], rng: RandomNumberGenerator) -> String:
	var candidates := filter_by_tag(players, target_tag)
	var victim := candidates[rng.randi_range(0, candidates.size() - 1)]
	victim.health.kill(id)
	return "Se nos fue %s." % victim.get_display_name()
