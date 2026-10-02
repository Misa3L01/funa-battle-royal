class_name DiveAbility
extends AbilityData
## El Piscinazo de Neymal: se tira al piso, queda invulnerable un momento y
## le sacan tarjeta amarilla (aturdimiento) a todos los que le pegaron hace poco.

@export var self_status: StatusEffect
@export var punish_status: StatusEffect
@export var memory_seconds: float = 3.0
@export var victim_line: String = "¡¿Qué hice?! ¡Ni lo toqué!"


func activate(user: Player, _aim: Vector3) -> void:
	user.status.apply(self_status, user.peer_id)
	var punished := PackedStringArray()
	for attacker_id: int in user.health.recent_attackers:
		if not user.health.attacked_recently(attacker_id, memory_seconds):
			continue
		var attacker := GameManager.get_player(attacker_id)
		if attacker and attacker.health.is_alive() and attacker != user:
			attacker.status.apply(punish_status, user.peer_id)
			attacker.combat.say(victim_line, 2.5)
			punished.append(attacker.get_display_name())
	if not punished.is_empty():
		GameManager.announce("TARJETA AMARILLA para %s" % ", ".join(punished), 3.0, Color(1, 0.9, 0.2))
