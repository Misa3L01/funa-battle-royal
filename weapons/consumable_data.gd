class_name ConsumableData
extends Resource
## Objeto que se consume al pasar por encima (mate, empanada, vacuna).

@export var id: StringName
@export var display_name: String
@export_multiline var description: String
@export var heal: float = 0.0
## Saca los efectos negativos (veneno, COVID, mareo...).
@export var cures_negative := false
@export var status: StatusEffect
@export var color: Color = Color.WHITE
## Modelo (ver WeaponVisuals.build_consumable).
@export var visual: StringName = &"empanada"
@export var spawn_weight: float = 10.0
