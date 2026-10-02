class_name NuclearStrikeEvent
extends GlobalEvent
## Ataque Nuclear: daño a todos, más probable cuantas más potencias nucleares
## haya en la arena. Los que estén dentro de un búnker reciben mucho menos.

## Tag que cuenta para la probabilidad.
@export var trigger_tag: StringName = CharacterTags.POTENCIA_NUCLEAR
## Probabilidad por partida según cuántos personajes con la tag hay.
## Índice 0 = ninguno, 1 = uno, etc. Si hay más que entradas, se usa la última.
@export var probability_by_count: Array[float] = [0.0, 0.25, 0.5, 0.8, 0.9]
## Daño a todos los jugadores vivos.
@export var damage: float = 60.0
## Multiplicador del daño para los que estén en un búnker.
@export var bunker_multiplier: float = 0.1


func get_match_probability(players: Array[Player]) -> float:
	if probability_by_count.is_empty():
		return 0.0
	var count := count_with_tag(players, trigger_tag)
	return probability_by_count[mini(count, probability_by_count.size() - 1)]


func execute(players: Array[Player], _rng: RandomNumberGenerator) -> String:
	var sheltered := PackedStringArray()
	for player in players:
		var in_bunker := GameManager.island != null and GameManager.island.is_in_bunker(player.global_position)
		if in_bunker:
			sheltered.append(player.get_display_name())
		player.health.apply_damage(damage * (bunker_multiplier if in_bunker else 1.0), id)
	Fx.broadcast(&"nuke", Vector3(0, 0, 0))
	if sheltered.is_empty():
		return "Nadie estaba en un búnker."
	return "Se salvaron en el búnker: %s" % ", ".join(sheltered)
