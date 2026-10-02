class_name WeaponVisuals
## Modelos de armas, proyectiles y consumibles hechos con primitivas de Godot.
##
## Convención: el arma se arma en metros, con la empuñadura en el origen y
## apuntando hacia -Z. Las partes "principales" (skinnable) toman el material
## de la skin elegida; los detalles (hoja, llama, etc.) conservan su color.

static var _materials: Dictionary = {}


static func build(visual: StringName, skin: WeaponSkin = null) -> Node3D:
	var root := Node3D.new()
	root.name = "Weapon"
	match visual:
		&"chainsaw":
			_part(root, _box(0.22, 0.28, 0.5), Vector3(0, 0.02, -0.15), _mat(Color(1.0, 0.45, 0.1)), skin)
			_part(root, _box(0.05, 0.13, 0.8), Vector3(0, -0.02, -0.75), _mat(Color(0.75, 0.75, 0.8), 0.8, 0.3))
			_part(root, _box(0.07, 0.07, 0.25), Vector3(0, 0.2, 0.05), _mat(Color(0.1, 0.1, 0.1)))
		&"cigar":
			_part(root, _cylinder(0.035, 0.035, 0.32), Vector3(0, 0, -0.16), _mat(Color(0.45, 0.28, 0.12)), skin, Vector3(PI * 0.5, 0, 0))
			_part(root, _cylinder(0.037, 0.037, 0.05), Vector3(0, 0, -0.34), _mat(Color(1.0, 0.4, 0.05), 0.0, 0.5, 3.0), null, Vector3(PI * 0.5, 0, 0))
		&"slipper":
			_part(root, _box(0.16, 0.04, 0.42), Vector3(0, 0, -0.21), _mat(Color(0.2, 0.55, 1.0)), skin)
			_part(root, _box(0.17, 0.08, 0.04), Vector3(0, 0.05, -0.12), _mat(Color(1.0, 1.0, 1.0)))
		&"flamethrower":
			_part(root, _cylinder(0.06, 0.06, 0.7), Vector3(0, 0, -0.45), _mat(Color(0.25, 0.25, 0.28), 0.7, 0.4), skin, Vector3(PI * 0.5, 0, 0))
			_part(root, _cylinder(0.14, 0.14, 0.4), Vector3(0, -0.12, 0.05), _mat(Color(0.8, 0.1, 0.1)), skin)
			_part(root, _sphere(0.05), Vector3(0, 0, -0.82), _mat(Color(1.0, 0.5, 0.1), 0.0, 0.5, 2.5))
		&"bat":
			_part(root, _cylinder(0.065, 0.03, 0.95), Vector3(0, 0, -0.42), _mat(Color(0.72, 0.52, 0.3)), skin, Vector3(-PI * 0.5, 0, 0))
		&"ball":
			_part(root, _sphere(0.2), Vector3(0, 0, -0.18), _mat(Color(0.95, 0.95, 0.95)), skin)
			_part(root, _cylinder(0.205, 0.205, 0.06), Vector3(0, 0, -0.18), _mat(Color(0.1, 0.1, 0.1)))
		&"vuvuzela":
			_part(root, _cylinder(0.16, 0.025, 0.85), Vector3(0, 0, -0.42), _mat(Color(1.0, 0.85, 0.1)), skin, Vector3(-PI * 0.5, 0, 0))
		&"selfie_stick":
			_part(root, _cylinder(0.02, 0.02, 1.5), Vector3(0, 0, -0.75), _mat(Color(0.15, 0.15, 0.15)), skin, Vector3(PI * 0.5, 0, 0))
			_part(root, _box(0.2, 0.36, 0.03), Vector3(0, 0.12, -1.5), _mat(Color(0.2, 0.6, 1.0), 0.3, 0.2, 0.6))
		&"teacup":
			_part(root, _cylinder(0.12, 0.09, 0.14), Vector3.ZERO, _mat(Color(1, 1, 1)))
			_part(root, _cylinder(0.105, 0.105, 0.02), Vector3(0, 0.06, 0), _mat(Color(0.3, 1.0, 0.3), 0.0, 0.5, 2.0))
		&"missile":
			_part(root, _cylinder(0.16, 0.16, 1.0), Vector3(0, 0, 0.1), _mat(Color(0.35, 0.4, 0.3)), skin, Vector3(PI * 0.5, 0, 0))
			_part(root, _cylinder(0.0, 0.16, 0.35), Vector3(0, 0, -0.57), _mat(Color(0.8, 0.1, 0.1)), null, Vector3(-PI * 0.5, 0, 0))
			_part(root, _box(0.5, 0.04, 0.2), Vector3(0, 0, 0.55), _mat(Color(0.8, 0.1, 0.1)))
			_part(root, _box(0.04, 0.5, 0.2), Vector3(0, 0, 0.55), _mat(Color(0.8, 0.1, 0.1)))
		&"smoke_ring":
			var torus := TorusMesh.new()
			torus.inner_radius = 0.18
			torus.outer_radius = 0.3
			_part(root, torus, Vector3.ZERO, _mat(Color(0.75, 0.9, 0.7, 0.75)), null, Vector3(PI * 0.5, 0, 0))
	return root


## Proyectil: mismo modelo que el arma cuando existe; si no, una esfera.
static func build_projectile(visual: StringName, radius: float, skin: WeaponSkin = null) -> Node3D:
	if visual in [&"slipper", &"ball", &"teacup", &"missile", &"smoke_ring"]:
		return build(visual, skin)
	var root := Node3D.new()
	_part(root, _sphere(radius), Vector3.ZERO, _mat(Color(1, 1, 1), 0.0, 0.5, 1.0))
	return root


static func build_consumable(visual: StringName) -> Node3D:
	var root := Node3D.new()
	match visual:
		&"mate":
			_part(root, _sphere(0.22), Vector3(0, 0.2, 0), _mat(Color(0.45, 0.28, 0.15)))
			_part(root, _cylinder(0.14, 0.14, 0.06), Vector3(0, 0.38, 0), _mat(Color(0.3, 0.55, 0.2)))
			_part(root, _cylinder(0.015, 0.015, 0.45), Vector3(0.05, 0.5, 0), _mat(Color(0.85, 0.85, 0.9), 0.9, 0.2), null, Vector3(0, 0, 0.3))
		&"empanada":
			var mesh := SphereMesh.new()
			mesh.radius = 0.25
			mesh.height = 0.25
			mesh.is_hemisphere = true
			var part := _part(root, mesh, Vector3(0, 0.05, 0), _mat(Color(0.95, 0.7, 0.3)))
			part.scale = Vector3(1.0, 0.8, 0.55)
		&"vaccine":
			_part(root, _cylinder(0.06, 0.06, 0.35), Vector3(0, 0.25, 0), _mat(Color(0.5, 0.8, 1.0, 0.6)), null, Vector3(0, 0, PI * 0.5))
			_part(root, _cylinder(0.008, 0.008, 0.2), Vector3(-0.27, 0.25, 0), _mat(Color(0.9, 0.9, 0.9), 1.0, 0.1), null, Vector3(0, 0, PI * 0.5))
			_part(root, _box(0.05, 0.12, 0.12), Vector3(0.2, 0.25, 0), _mat(Color(0.95, 0.95, 0.95)))
	return root


static func _part(root: Node3D, mesh: Mesh, position: Vector3, material: Material, skin: WeaponSkin = null, rotation := Vector3.ZERO) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = position
	instance.rotation = rotation
	instance.material_override = skin.get_material() if skin and not skin.is_default else material
	root.add_child(instance)
	return instance


static func _mat(color: Color, metallic := 0.0, roughness := 0.6, emission := 0.0) -> StandardMaterial3D:
	var key := "%s|%s|%s|%s" % [color.to_html(), metallic, roughness, emission]
	if _materials.has(key):
		return _materials[key]
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness
	if color.a < 1.0:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if emission > 0.0:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = emission
	_materials[key] = material
	return material


static func _box(x: float, y: float, z: float) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(x, y, z)
	return mesh


## Cilindro a lo largo de Y (rotarlo para ponerlo a lo largo de Z).
static func _cylinder(top_radius: float, bottom_radius: float, height: float) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top_radius
	mesh.bottom_radius = bottom_radius
	mesh.height = height
	mesh.radial_segments = 12
	mesh.rings = 1
	return mesh


static func _sphere(radius: float) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 12
	mesh.rings = 6
	return mesh
