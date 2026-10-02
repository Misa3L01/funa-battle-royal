@abstract
class_name GlobalEvent
extends Resource
## Evento global aleatorio (Ataque Nuclear, COVID, muerte por edad...).
##
## Cada evento es un .tres con sus números, así se ajustan desde el inspector
## sin tocar código. Para crear un evento nuevo: heredar de esta clase,
## implementar get_match_probability() y execute(), crear su .tres y sumarlo
## a GameManager.event_pool.
##
## Estos métodos solo los llama el GameManager, y solo en el servidor.

## Identificador interno (logs, RPCs y efectos visuales en los clientes).
@export var id: StringName
## Nombre para la UI y el registro de bajas ("murió por el Ataque Nuclear").
@export var display_name: String

@export_group("Cuándo ocurre")
## Segundos desde el inicio de la partida. El momento exacto se sortea en este rango.
@export var earliest_time: float = 45.0
@export var latest_time: float = 180.0

@export_group("Textos")
## Segundos entre el aviso y el efecto (0 = sin aviso). Da tiempo a reaccionar.
@export var warning_time: float = 5.0
@export_multiline var warning_text: String = ""
## Texto que se muestra cuando el evento ocurre.
@export_multiline var announcement: String = ""


## Probabilidad (0 a 1) de que el evento ocurra en esta partida, según quién juega.
@abstract func get_match_probability(players: Array[Player]) -> float


## Aplica el efecto sobre los jugadores vivos. Devuelve un detalle opcional
## para sumar al anuncio (por ejemplo, a quién afectó).
@abstract func execute(players: Array[Player], rng: RandomNumberGenerator) -> String


## Si devuelve false en el momento de ocurrir, el evento se cancela sin
## anunciarse (por ejemplo, ya no queda nadie a quien afectar).
func can_execute(_players: Array[Player]) -> bool:
	return true


static func count_with_tag(players: Array[Player], tag: StringName) -> int:
	var count := 0
	for player in players:
		if player.has_tag(tag):
			count += 1
	return count


static func filter_by_tag(players: Array[Player], tag: StringName) -> Array[Player]:
	var result: Array[Player] = []
	for player in players:
		if player.has_tag(tag):
			result.append(player)
	return result


static func join_names(players: Array[Player]) -> String:
	var names := PackedStringArray()
	for player in players:
		names.append(player.get_display_name())
	return ", ".join(names)
