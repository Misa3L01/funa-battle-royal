class_name WallProp
extends StaticBody3D
## Muro temporal de "El Muro" de Tromp. Frena personajes y proyectiles.
## Lo crea el servidor; al vencer lo borra y el spawner lo saca de los clientes.

var _size := Vector3(6.0, 3.2, 0.7)
var _lifetime := 8.0


func setup(data: Dictionary) -> void:
	name = data["name"]
	position = data["position"]
	rotation.y = data["yaw"]
	_size = Vector3(data["width"], data["height"], 0.7)
	_lifetime = data["lifetime"]


func _ready() -> void:
	collision_layer = Layers.WORLD
	collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = _size
	shape.shape = box
	shape.position.y = _size.y * 0.5
	add_child(shape)

	var visual := Node3D.new()
	var mesh := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = _size
	mesh.mesh = box_mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.7, 0.35, 0.25)
	material.roughness = 0.9
	mesh.material_override = material
	mesh.position.y = _size.y * 0.5
	visual.add_child(mesh)
	var label := Label3D.new()
	label.text = "EL MURO"
	label.font_size = 90
	label.outline_size = 16
	label.position = Vector3(0, _size.y * 0.6, 0.4)
	visual.add_child(label)
	var back_label := label.duplicate() as Label3D
	back_label.position.z = -0.4
	back_label.rotation.y = PI
	visual.add_child(back_label)
	add_child(visual)
	# Sube desde el piso.
	visual.position.y = -_size.y
	create_tween().tween_property(visual, "position:y", 0.0, 0.25).set_trans(Tween.TRANS_BACK)

	if multiplayer.is_server():
		get_tree().create_timer(_lifetime, false).timeout.connect(queue_free)
