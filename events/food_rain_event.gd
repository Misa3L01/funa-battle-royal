class_name FoodRainEvent
extends GlobalEvent
## Lluvia de Empanadas: caen del cielo consumibles dentro de la zona.

@export_range(0.0, 1.0) var probability: float = 0.35
@export var consumable: ConsumableData
@export var count: int = 14


func get_match_probability(_players: Array[Player]) -> float:
	return probability


func execute(_players: Array[Player], rng: RandomNumberGenerator) -> String:
	for i in count:
		GameManager.spawn_pickup(&"consumable", consumable.id, GameManager.random_point_in_zone(rng), -1, true)
	return ""
