class_name CharacterRoster
extends Resource
## Lista de todos los personajes jugables, en el orden en que aparecen en la
## selección. Se edita desde el inspector: res://characters/roster.tres

const MAIN_PATH := "res://characters/roster.tres"

@export var characters: Array[CharacterData] = []

static var _main: CharacterRoster


## El roster del juego. Se carga en tiempo de ejecución (no con preload) para
## no crear dependencias circulares entre scripts al compilar.
static func main() -> CharacterRoster:
	if _main == null:
		_main = load(MAIN_PATH)
	return _main


func get_character(character_id: StringName) -> CharacterData:
	for character in characters:
		if character.id == character_id:
			return character
	return null


func has_character(character_id: StringName) -> bool:
	return get_character(character_id) != null
