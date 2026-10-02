@abstract
class_name AbilityData
extends Resource
## Habilidad especial de un personaje (tecla Q).
##
## Hay pocos tipos genéricos (dash, área, buff propio, proyectil, súper salto,
## muro, piscinazo) y cada personaje configura el suyo en un .tres. activate()
## corre solo en el servidor.

## Pista para la IA de los bots sobre cuándo usarla.
enum BotHint {
	CLOSE_RANGE, ## Con un enemigo cerca (dentro de bot_range).
	MID_RANGE,   ## Con un enemigo a media distancia.
	DEFENSIVE,   ## Con poca vida y enemigos cerca.
	MOBILITY,    ## Para acercarse a un enemigo lejano.
}

@export var id: StringName
@export var display_name: String
@export_multiline var description: String
@export var cooldown: float = 10.0
## Animación del modelo al usarla.
@export var animation: StringName = &"interact-right"
@export var action_duration: float = 0.5
## Lo que grita el personaje (globo de texto). Vacío = nada.
@export var shout: String = ""
@export var bot_hint: BotHint = BotHint.CLOSE_RANGE
@export var bot_range: float = 6.0


## Aplica la habilidad. Solo corre en el servidor. aim es la dirección a la que apunta.
@abstract func activate(user: Player, aim: Vector3) -> void


static func flat_direction(aim: Vector3, user: Player) -> Vector3:
	var flat := Vector3(aim.x, 0.0, aim.z)
	if flat.length() < 0.1:
		return -user.global_basis.z
	return flat.normalized()
