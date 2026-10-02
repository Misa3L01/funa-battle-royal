class_name Pickup
extends Node3D
## Objeto en el piso. Las armas se agarran con E; los consumibles se agarran
## solos al pasar por encima. Lo crea el servidor con el MultiplayerSpawner.

const AUTO_PICKUP_RANGE := 1.4
## Altura desde la que caen los objetos de la Lluvia de Empanadas.
const DROP_HEIGHT := 25.0

var kind: StringName
var item_id: StringName
var ammo := -1
## Evita que dos personajes agarren el mismo objeto en el mismo frame.
var taken := false

var _visual: Node3D
var _time := 0.0
var _drop_offset := 0.0


func setup(data: Dictionary) -> void:
	name = data["name"]
	kind = data["kind"]
	item_id = data["id"]
	ammo = data["ammo"]
	position = data["position"]
	_drop_offset = DROP_HEIGHT if data["drop"] else 0.0


func _ready() -> void:
	add_to_group(&"pickups")
	_time = randf() * TAU
	var label := Label3D.new()
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 30
	label.outline_size = 10
	label.position.y = 1.35
	label.visibility_range_end = 30.0
	if kind == &"weapon":
		var weapon := DataLibrary.weapon(item_id)
		_visual = WeaponVisuals.build(weapon.visual)
		_visual.rotation.x = -PI * 0.25
		label.text = weapon.display_name
		label.modulate = weapon.get_rarity_color()
		_add_ring(weapon.get_rarity_color())
	else:
		var consumable := DataLibrary.consumable(item_id)
		_visual = WeaponVisuals.build_consumable(consumable.visual)
		label.text = consumable.display_name
		label.modulate = consumable.color
		_add_ring(consumable.color)
	var holder := Node3D.new()
	holder.name = "Holder"
	holder.add_child(_visual)
	add_child(holder)
	add_child(label)


func _process(delta: float) -> void:
	_time += delta
	_drop_offset = move_toward(_drop_offset, 0.0, 22.0 * delta)
	var holder := get_node("Holder") as Node3D
	holder.position.y = 0.7 + sin(_time * 2.0) * 0.12 + _drop_offset
	holder.rotation.y += delta * 1.5


func _physics_process(_delta: float) -> void:
	if kind != &"consumable" or taken or _drop_offset > 0.5 or not multiplayer.is_server():
		return
	for player in GameManager.get_alive_players():
		if player.global_position.distance_to(global_position) <= AUTO_PICKUP_RANGE:
			taken = true
			GameManager.consume(player, DataLibrary.consumable(item_id))
			queue_free()
			return


func get_display_name() -> String:
	if kind == &"weapon":
		return DataLibrary.weapon(item_id).display_name
	return DataLibrary.consumable(item_id).display_name


func _add_ring(color: Color) -> void:
	var ring := MeshInstance3D.new()
	var mesh := TorusMesh.new()
	mesh.inner_radius = 0.55
	mesh.outer_radius = 0.65
	ring.mesh = mesh
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	ring.material_override = material
	ring.position.y = 0.08
	add_child(ring)
