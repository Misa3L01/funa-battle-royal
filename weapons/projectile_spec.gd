class_name ProjectileSpec
extends Resource
## Cómo es un proyectil. Lo usan las armas a distancia y algunas habilidades.

## Modelo (ver WeaponVisuals.build_projectile).
@export var visual: StringName = &"ball"
@export var speed: float = 25.0
## Gravedad propia: 0 va recto; ~14 es la parábola de algo tirado a mano.
@export var gravity: float = 0.0
@export var radius: float = 0.25
@export var lifetime: float = 2.0
@export var damage: float = 10.0
@export var knockback: float = 4.0
## Mayor a 0: explota y daña en área (el daño baja con la distancia).
@export var explosion_radius: float = 0.0
## Rebotes contra el piso o paredes antes de desaparecer.
@export var bounces: int = 0
@export var hit_status: StatusEffect
## Vueltas por segundo del modelo (la chancla girando, etc.).
@export var spin: float = 0.0
