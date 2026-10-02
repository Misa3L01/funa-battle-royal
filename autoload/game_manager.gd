extends Node
## GameManager (Autoload): reglas de la partida.
##
## - Eventos globales aleatorios: al empezar, el servidor calcula la
##   probabilidad de cada evento según los personajes presentes y tira los
##   dados UNA vez; si sale, lo agenda para un segundo al azar. Un solo Timer
##   recorre la agenda: primero avisa y, pasados warning_time segundos, aplica.
## - Registro de jugadores, bajas, ganador y vuelta al lobby.
## - Rivalidades y sinergias: frases al cruzarse y multiplicador de daño.
## - Loot inicial y utilidades para crear objetos en red (proyectiles, pickups, muros).
##
## Solo el servidor decide; los clientes reciben todo por RPC y lo exponen como
## señales para la UI.

signal event_warning(event_id: StringName, text: String, seconds: float)
signal event_triggered(event_id: StringName, text: String)
## Mensaje genérico para el HUD (rivalidades, tarjetas amarillas...).
signal announcement(text: String, seconds: float, color: Color)
signal kill_feed(text: String)
signal alive_count_changed(alive: int, total: int)
## standings: Array de {"name", "kills", "alive"} ordenado del primero al último.
signal match_over(winner_name: String, standings: Array)

const RETURN_TO_LOBBY_SECONDS := 10.0
const RIVALRY_CHECK_SECONDS := 0.5
const LOOT_FILL_CHANCE := 0.85
const WEAPON_LOOT_CHANCE := 0.7
const RIVALRIES: RivalryTable = preload("res://combat/rivalries.tres")

## Eventos posibles. Para agregar uno: crear su .tres y sumarlo acá.
var event_pool: Array[GlobalEvent] = [
	preload("res://events/nuclear_strike.tres"),
	preload("res://events/covid.tres"),
	preload("res://events/natural_death.tres"),
	preload("res://events/apagon.tres"),
	preload("res://events/hiperinflacion.tres"),
	preload("res://events/lluvia_empanadas.tres"),
]

## Referencias a la arena actual (las pone Arena en todos los peers).
var island: IslandGenerator
var zone: InflationZone
var world_spawner: MultiplayerSpawner

var _players_by_id: Dictionary[int, Player] = {}
var _rng := RandomNumberGenerator.new()
var _schedule: Array[ScheduledEvent] = []
var _match_time := 0.0
var _is_running := false
var _match_over := false
var _started_with := 0
var _kills: Dictionary[int, int] = {}
var _triggered_rivalries: Dictionary[String, bool] = {}
var _rivalry_timer := 0.0
var _spawn_counter := 0
var _timer: Timer


## Un momento de la agenda: avisar o ejecutar un evento.
class ScheduledEvent:
	var event: GlobalEvent
	## Segundos desde el inicio de la partida.
	var time: float
	## true = toca mostrar el aviso; false = toca aplicar el efecto.
	var is_warning: bool

	func _init(p_event: GlobalEvent, p_time: float, p_is_warning: bool) -> void:
		event = p_event
		time = p_time
		is_warning = p_is_warning


func _ready() -> void:
	_timer = Timer.new()
	_timer.one_shot = true
	_timer.timeout.connect(_on_timer_timeout)
	add_child(_timer)


func _process(delta: float) -> void:
	if not _is_running:
		return
	_match_time += delta
	_rivalry_timer -= delta
	if _rivalry_timer <= 0.0 and multiplayer.is_server():
		_rivalry_timer = RIVALRY_CHECK_SECONDS
		_check_rivalries()


# --- Arena y jugadores (todos los peers) -------------------------------------------

func bind_arena(arena_island: IslandGenerator, arena_zone: InflationZone, spawner: MultiplayerSpawner) -> void:
	island = arena_island
	zone = arena_zone
	world_spawner = spawner


func unbind_arena() -> void:
	end_match()
	island = null
	zone = null
	world_spawner = null
	_players_by_id.clear()


func register_player(player: Player) -> void:
	_players_by_id[player.peer_id] = player
	player.tree_exiting.connect(_on_player_removed.bind(player))
	if multiplayer.is_server():
		player.health.died.connect(_on_player_died.bind(player))


func get_player(peer_id: int) -> Player:
	var player: Player = _players_by_id.get(peer_id)
	return player if is_instance_valid(player) else null


func get_players() -> Array[Player]:
	var result: Array[Player] = []
	result.assign(_players_by_id.values())
	return result


func get_alive_players() -> Array[Player]:
	var alive: Array[Player] = []
	for player: Player in _players_by_id.values():
		if player.health.is_alive():
			alive.append(player)
	return alive


## El siguiente vivo después de current (para mirar la partida después de morir).
func get_next_alive_player(current: Player) -> Player:
	var alive := get_alive_players()
	if alive.is_empty():
		return null
	var index := alive.find(current)
	return alive[(index + 1) % alive.size()]


func get_event(event_id: StringName) -> GlobalEvent:
	for event in event_pool:
		if event.id == event_id:
			return event
	return null


func ground_height(point: Vector3) -> float:
	return island.height_at(point.x, point.z) if island else point.y


func random_point_in_zone(rng: RandomNumberGenerator) -> Vector3:
	if island == null:
		return Vector3.ZERO
	if zone and zone.is_active():
		return island.random_land_point(rng, zone.center, maxf(zone.radius * 0.8, 3.0))
	return island.random_land_point(rng, Vector3.ZERO, 70.0)


# --- Partida (servidor) ------------------------------------------------------------

## Arranca la partida con los personajes ya creados. Solo en el servidor.
## [param match_seed]: semilla fija para repetir una partida al depurar (-1 = aleatoria).
func start_match(players: Array[Player], match_seed: int = -1) -> void:
	if not multiplayer.is_server():
		push_error("GameManager.start_match() solo se llama en el servidor.")
		return
	end_match()
	if match_seed >= 0:
		_rng.seed = match_seed
	else:
		_rng.randomize()
	_is_running = true
	_started_with = players.size()
	_roll_events()
	_arm_timer()
	if island:
		_spawn_initial_loot()
	if zone:
		zone.start(Vector3.ZERO, 95.0)
	_sync_alive.rpc(players.size(), players.size())


## Termina la partida y cancela los eventos pendientes.
func end_match() -> void:
	_is_running = false
	_match_over = false
	_match_time = 0.0
	_timer.stop()
	_schedule.clear()
	_kills.clear()
	_triggered_rivalries.clear()
	if zone:
		zone.stop()


func get_match_time() -> float:
	return _match_time


## Dispara un evento ya mismo (con su aviso), sin tirar dados. Solo para pruebas.
func debug_trigger(event_id: StringName) -> void:
	if not multiplayer.is_server() or not _is_running:
		return
	var event := get_event(event_id)
	if event == null:
		push_warning("GameManager: no existe el evento '%s'." % event_id)
		return
	_schedule_event(event, _match_time)
	_arm_timer()


func announce(text: String, seconds: float = 3.0, color: Color = Color.WHITE) -> void:
	if multiplayer.is_server():
		_announce.rpc(text, seconds, color)


# --- Objetos en red (servidor) ---------------------------------------------------------

func spawn_projectile(spec: ProjectileSpec, owner: Player, origin: Vector3, direction: Vector3,
		damage_multiplier: float = 1.0, cause: StringName = &"", status_override: StatusEffect = null,
		skin_id: StringName = &"clasica") -> void:
	var status := status_override if status_override else spec.hit_status
	_spawn_world({
		"type": &"projectile",
		"owner": owner.peer_id,
		"origin": origin,
		"velocity": direction.normalized() * spec.speed,
		"gravity": spec.gravity,
		"radius": spec.radius,
		"lifetime": spec.lifetime,
		"visual": spec.visual,
		"damage": spec.damage * damage_multiplier,
		"knockback": spec.knockback,
		"explosion": spec.explosion_radius,
		"bounces": spec.bounces,
		"status": status.id if status else &"",
		"cause": cause,
		"spin": spec.spin,
		"skin": skin_id,
	})


func spawn_pickup(kind: StringName, item_id: StringName, point: Vector3, ammo: int = -1, drop := false) -> void:
	_spawn_world({"type": &"pickup", "kind": kind, "id": item_id, "position": point, "ammo": ammo, "drop": drop})


func spawn_wall(point: Vector3, yaw: float, width: float, height: float, lifetime: float) -> void:
	_spawn_world({"type": &"wall", "position": point, "yaw": yaw, "width": width, "height": height, "lifetime": lifetime})


func find_nearest_pickup(point: Vector3, max_distance: float, kind: StringName) -> Pickup:
	var best: Pickup = null
	var best_distance := max_distance
	for node in get_tree().get_nodes_in_group(&"pickups"):
		var pickup := node as Pickup
		if pickup.taken or pickup.kind != kind:
			continue
		var distance := pickup.global_position.distance_to(point)
		if distance <= best_distance:
			best_distance = distance
			best = pickup
	return best


func consume(player: Player, consumable: ConsumableData) -> void:
	if consumable.cures_negative:
		player.status.cure_negative()
	if consumable.status:
		player.status.apply(consumable.status, player.peer_id)
	if consumable.heal > 0.0:
		player.health.heal(consumable.heal)
		Fx.broadcast(&"heal", player.get_chest_position(), consumable.heal)
	Fx.broadcast(&"pickup", player.get_chest_position(), 0.0, consumable.color)


func _spawn_world(data: Dictionary) -> void:
	if not multiplayer.is_server() or world_spawner == null:
		return
	_spawn_counter += 1
	data["name"] = "%s_%d" % [data["type"], _spawn_counter]
	world_spawner.spawn(data)


func _spawn_initial_loot() -> void:
	var weapons: Array = DataLibrary.all_in(DataLibrary.WEAPON_DIR).filter(
		func(weapon: WeaponData) -> bool: return weapon.spawn_weight > 0.0)
	var consumables: Array = DataLibrary.all_in(DataLibrary.CONSUMABLE_DIR)
	for point in island.loot_points:
		if _rng.randf() > LOOT_FILL_CHANCE:
			continue
		if _rng.randf() < WEAPON_LOOT_CHANCE:
			var weapon: WeaponData = _weighted_pick(weapons)
			spawn_pickup(&"weapon", weapon.id, point, weapon.ammo)
		else:
			var consumable: ConsumableData = _weighted_pick(consumables)
			spawn_pickup(&"consumable", consumable.id, point)


func _weighted_pick(items: Array) -> Resource:
	var total := 0.0
	for item in items:
		total += item.spawn_weight
	var roll := _rng.randf() * total
	for item in items:
		roll -= item.spawn_weight
		if roll <= 0.0:
			return item
	return items.back()


# --- Bajas y final (servidor) ---------------------------------------------------------

func _on_player_died(cause: StringName, killer_id: int, victim: Player) -> void:
	var killer := get_player(killer_id)
	if killer and killer != victim:
		_kills[killer_id] = _kills.get(killer_id, 0) + 1
		if not killer.character.taunts.is_empty() and _rng.randf() < 0.6:
			killer.combat.say(killer.character.taunts[_rng.randi() % killer.character.taunts.size()], 2.5)
	_announce_kill.rpc(_describe_death(victim, cause, killer))
	Fx.broadcast(&"death", victim.get_chest_position())

	var alive := get_alive_players()
	_sync_alive.rpc(alive.size(), _started_with)
	if _match_over:
		return
	if (_started_with >= 2 and alive.size() <= 1) or alive.is_empty():
		_finish(alive[0] if alive.size() == 1 else null)


func _describe_death(victim: Player, cause: StringName, killer: Player) -> String:
	var victim_name := victim.get_display_name()
	if killer and killer != victim:
		return "%s funó a %s (%s)" % [killer.get_display_name(), victim_name, describe_cause(cause)]
	match cause:
		&"inflacion":
			return "%s no pudo pagar la inflación" % victim_name
		&"tiburon":
			return "A %s se lo comió un tiburón" % victim_name
		&"caida":
			return "%s descubrió la gravedad" % victim_name
		&"natural_death":
			return "%s se fue de viejo. Descanse en paz." % victim_name
	return "%s murió por %s" % [victim_name, describe_cause(cause)]


## Nombre legible de lo que causó un daño (arma, habilidad, efecto o evento).
func describe_cause(cause: StringName) -> String:
	var weapon := DataLibrary.find(DataLibrary.WEAPON_DIR, cause) as WeaponData
	if weapon:
		return weapon.display_name
	var status := DataLibrary.find(DataLibrary.STATUS_DIR, cause) as StatusEffect
	if status:
		return status.display_name
	var event := get_event(cause)
	if event:
		return event.display_name
	for character in CharacterRoster.main().characters:
		if character.ability and character.ability.id == cause:
			return character.ability.display_name
	return String(cause)


func _finish(winner: Player) -> void:
	_match_over = true
	_timer.stop()
	if zone:
		zone.stop()
	var standings: Array = []
	for player: Player in _players_by_id.values():
		standings.append({
			"name": player.get_display_name(),
			"kills": _kills.get(player.peer_id, 0),
			"alive": player.health.is_alive(),
		})
	standings.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a["alive"] != b["alive"]:
			return a["alive"]
		return a["kills"] > b["kills"])
	var winner_name := winner.get_display_name() if winner else "Nadie. Empate técnico."
	if winner and not winner.character.taunts.is_empty():
		winner.combat.say(winner.character.taunts[0], 4.0)
	print("[GameManager] Ganó: %s" % winner_name)
	_announce_winner.rpc(winner_name, standings)
	get_tree().create_timer(RETURN_TO_LOBBY_SECONDS).timeout.connect(NetworkManager.return_to_lobby)


# --- Rivalidades (servidor) -------------------------------------------------------------

## Multiplicador de daño entre dos personajes según su relación y distancia.
func get_rivalry_multiplier(attacker: Player, target: Player) -> float:
	var relation := RIVALRIES.find(attacker.character.id, target.character.id)
	if relation and attacker.global_position.distance_to(target.global_position) <= relation.activation_range:
		return relation.damage_multiplier
	return 1.0


func _check_rivalries() -> void:
	var alive := get_alive_players()
	for i in alive.size():
		for j in range(i + 1, alive.size()):
			var a := alive[i]
			var b := alive[j]
			var relation := RIVALRIES.find(a.character.id, b.character.id)
			if relation == null or a.global_position.distance_to(b.global_position) > relation.activation_range:
				continue
			var key := "%d|%d" % [mini(a.peer_id, b.peer_id), maxi(a.peer_id, b.peer_id)]
			if _triggered_rivalries.has(key):
				continue
			_triggered_rivalries[key] = true
			var first := a if a.character.id == relation.character_a else b
			var second := b if first == a else a
			first.combat.say(relation.line_a, 3.5)
			get_tree().create_timer(1.8).timeout.connect(func() -> void:
				if is_instance_valid(second) and second.health.is_alive():
					second.combat.say(relation.line_b, 3.5))
			var is_rival := relation.kind == RivalryData.Kind.RIVAL
			var percent := roundi(absf(relation.damage_multiplier - 1.0) * 100.0)
			announce("%s: %s vs %s (%s%d%% de daño entre ellos)" % [
				relation.display_name.to_upper(), first.get_display_name(), second.get_display_name(),
				"+" if is_rival else "-", percent,
			], 4.0, Color(1.0, 0.4, 0.3) if is_rival else Color(0.4, 0.9, 1.0))


# --- Eventos (servidor) ------------------------------------------------------------------

func _roll_events() -> void:
	var players := get_alive_players()
	for event in event_pool:
		var probability := clampf(event.get_match_probability(players), 0.0, 1.0)
		var roll := _rng.randf()
		var happens := roll < probability
		print("[GameManager] %s: probabilidad %d%%, tirada %.2f -> %s" % [
			event.id, roundi(probability * 100.0), roll, "OCURRE" if happens else "no ocurre"
		])
		if happens:
			_schedule_event(event, _rng.randf_range(event.earliest_time, event.latest_time))


## Agenda un evento: primero su aviso (si tiene) y después el efecto.
func _schedule_event(event: GlobalEvent, time: float) -> void:
	_insert(ScheduledEvent.new(event, time, event.warning_time > 0.0))


func _insert(entry: ScheduledEvent) -> void:
	_schedule.append(entry)
	_schedule.sort_custom(func(a: ScheduledEvent, b: ScheduledEvent) -> bool: return a.time < b.time)


func _arm_timer() -> void:
	_timer.stop()
	if _schedule.is_empty():
		return
	# Timer.start() necesita un tiempo positivo, aunque el evento ya esté atrasado.
	_timer.start(maxf(_schedule[0].time - _match_time, 0.05))


func _on_timer_timeout() -> void:
	if _schedule.is_empty() or _match_over:
		return
	var entry: ScheduledEvent = _schedule.pop_front()
	var event := entry.event
	var alive := get_alive_players()
	if not event.can_execute(alive):
		print("[GameManager] %s cancelado: ya no tiene a quién afectar." % event.id)
	elif entry.is_warning:
		_announce_warning.rpc(event.id, event.warning_text, event.warning_time)
		_insert(ScheduledEvent.new(event, entry.time + event.warning_time, false))
	else:
		print("[GameManager] Evento: %s (segundo %.1f)" % [event.id, _match_time])
		var detail := event.execute(alive, _rng)
		var text := event.announcement if detail.is_empty() else "%s\n%s" % [event.announcement, detail]
		_announce_event.rpc(event.id, text)
	_arm_timer()


func _on_player_removed(player: Player) -> void:
	if _players_by_id.get(player.peer_id) == player:
		_players_by_id.erase(player.peer_id)


# --- RPC servidor → todos -------------------------------------------------------------------

@rpc("authority", "call_local", "reliable")
func _announce_warning(event_id: StringName, text: String, seconds: float) -> void:
	event_warning.emit(event_id, text, seconds)


@rpc("authority", "call_local", "reliable")
func _announce_event(event_id: StringName, text: String) -> void:
	event_triggered.emit(event_id, text)


@rpc("authority", "call_local", "reliable")
func _announce(text: String, seconds: float, color: Color) -> void:
	announcement.emit(text, seconds, color)


@rpc("authority", "call_local", "reliable")
func _announce_kill(text: String) -> void:
	print("[Baja] %s" % text)
	kill_feed.emit(text)


@rpc("authority", "call_local", "reliable")
func _sync_alive(alive: int, total: int) -> void:
	alive_count_changed.emit(alive, total)


@rpc("authority", "call_local", "reliable")
func _announce_winner(winner_name: String, standings: Array) -> void:
	match_over.emit(winner_name, standings)
