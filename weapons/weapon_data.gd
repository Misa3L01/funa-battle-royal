class_name WeaponData
extends Resource
## Arma. Cada una es un .tres en res://weapons/data/.
##
## "Arma firma": si la agarra el personaje de signature_character, se aplican
## los multiplicadores de firma (Pilei con la motosierra, Smoke Dogg con el
## puro...). Si la agarra otro, se aplica lo de "non_signature" (daño menor o un
## efecto molesto mientras la tenga, como el mareo del puro).

enum Kind {
	MELEE,  ## Golpe en arco delante del personaje.
	RANGED, ## Dispara proyectiles.
	CONE,   ## Cono continuo a corta distancia (lanzallamas, vuvuzela).
}
enum Rarity { COMUN, RARA, EPICA, LEGENDARIA }

const RARITY_NAMES: Array[String] = ["Común", "Rara", "Épica", "Legendaria"]
const RARITY_COLORS: Array[Color] = [
	Color(0.85, 0.85, 0.85), Color(0.35, 0.65, 1.0), Color(0.75, 0.4, 1.0), Color(1.0, 0.7, 0.15),
]

@export var id: StringName
@export var display_name: String
@export_multiline var description: String
@export var kind: Kind = Kind.MELEE
@export var rarity: Rarity = Rarity.COMUN
## Modelo procedural (ver WeaponVisuals.build).
@export var visual: StringName = &"fists"
@export var two_handed := false

@export_group("Daño")
## Daño por golpe (cuerpo a cuerpo y cono). Las de distancia usan el del proyectil.
@export var damage: float = 8.0
@export var cooldown: float = 0.5
## Demora entre el inicio del golpe y el impacto (cuerpo a cuerpo).
@export var windup: float = 0.12
## Alcance en metros (cuerpo a cuerpo y cono).
@export var reach: float = 1.6
@export var arc_degrees: float = 100.0
@export var knockback: float = 3.0
@export var heavy_damage_multiplier: float = 2.2
@export var heavy_cooldown_multiplier: float = 2.4
@export var heavy_knockback_multiplier: float = 2.5
@export var hit_status: StatusEffect
## Usos antes de romperse (-1 = infinito).
@export var ammo: int = -1

@export_group("Distancia")
@export var projectile: ProjectileSpec
@export var projectile_count: int = 1
@export var spread_degrees: float = 4.0

@export_group("Arma firma")
@export var signature_character: StringName
@export var signature_damage_multiplier: float = 1.0
@export var signature_cooldown_multiplier: float = 1.0
@export var signature_range_multiplier: float = 1.0
## 0 = puntería perfecta.
@export var signature_spread_multiplier: float = 1.0
## Reemplaza a hit_status cuando la usa su dueño.
@export var signature_hit_status: StatusEffect
@export var non_signature_damage_multiplier: float = 1.0
## Efecto que sufre cualquier otro mientras la tenga en la mano.
@export var non_signature_held_status: StatusEffect
## Texto corto para la UI: qué cambia con el dueño y con los demás.
@export_multiline var signature_text: String

@export_group("Loot")
## Peso relativo al sortear el loot (0 = no aparece en el piso).
@export var spawn_weight: float = 10.0


func is_signature_for(character: CharacterData) -> bool:
	return signature_character != &"" and character != null and character.id == signature_character


func uses_ammo() -> bool:
	return ammo > 0


func get_rarity_color() -> Color:
	return RARITY_COLORS[rarity]
