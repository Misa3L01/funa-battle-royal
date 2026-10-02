class_name CharacterData
extends Resource
## Datos de un personaje jugable. Cada personaje es un .tres en
## res://characters/roster/ y se registra en res://characters/roster.tres.
##
## La lógica del juego nunca pregunta "¿es Tromp?": pregunta por tags
## (ver CharacterTags). Así, agregar personajes no obliga a tocar código.

## Identificador interno. Es lo que viaja por la red: no cambiarlo una vez publicado.
@export var id: StringName
## Nombre que ve el jugador (nombre en clave, nunca el real).
@export var display_name: String
@export var country: String
@export_multiline var bio: String
## Garabato de la cara, que va en lugar de la cabeza del modelo.
@export var face_texture: Texture2D
## Tags que usan los eventos, sinergias y rivalidades. Ver CharacterTags.
@export var tags: Array[StringName] = []
@export var ability: AbilityData
## Frases al funar a alguien (se elige una al azar).
@export var taunts: PackedStringArray = []

@export_group("Stats")
@export var max_health: float = 100.0
@export var move_speed: float = 6.0

@export_group("Modelo")
## Cuerpo (pack Kenney Mini Characters, CC0). La cabeza se reemplaza por la cara.
@export var body_model: PackedScene
## Escala del cuerpo (Napoleón es chiquito).
@export var body_scale: float = 1.0


func has_tag(tag: StringName) -> bool:
	return tag in tags
