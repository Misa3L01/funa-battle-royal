class_name IslandGenerator
extends Node3D
## Isla generada por código a partir de una semilla fija.
##
## Todos los peers la generan igual (terreno, colisión, agua, vegetación y
## lugares), así que no hace falta mandarla por la red. Para otra isla alcanza
## con cambiar map_seed (los lugares mantienen su posición).

const SIZE := 200            ## Metros por lado del terreno (celdas de 1 m).
const HALF := 100
const ISLAND_RADIUS := 88.0
const SEA_FLOOR := -7.0
const WATER_SIZE := 900.0
const MOUNTAIN_CENTER := Vector2(50.0, -40.0)
const WATER_SHADER := preload("res://map/water.gdshader")

const SAND := Color(0.93, 0.84, 0.6)
const WET_SAND := Color(0.72, 0.66, 0.48)
const GRASS := Color(0.36, 0.62, 0.27)
const DARK_GRASS := Color(0.25, 0.48, 0.2)
const ROCK := Color(0.52, 0.5, 0.47)
const STONE := Color(0.72, 0.7, 0.66)
const PINK := Color(0.96, 0.62, 0.72)
const WHITE := Color(0.95, 0.94, 0.9)
const BRICK := Color(0.68, 0.2, 0.17)
const CONCRETE := Color(0.55, 0.56, 0.52)
const METAL := Color(0.6, 0.62, 0.66)

@export var map_seed: int = 20260924

var heights := PackedFloat32Array()
var spawn_points: Array[Vector3] = []
var loot_points: Array[Vector3] = []
var wander_points: Array[Vector3] = []
var bunkers: Array[Node3D] = []

var _rng := RandomNumberGenerator.new()
var _materials: Dictionary = {}
var _pois: Array[Dictionary] = []
var _nature_body: StaticBody3D


func generate() -> void:
	_rng.seed = map_seed
	_pois = [
		{"id": &"plaza", "name": "PLAZA DEL MATE GIGANTE", "center": Vector2(0, 0), "radius": 16.0},
		{"id": &"casa_rosadita", "name": "CASA ROSADITA", "center": Vector2(-40, 18), "radius": 13.0},
		{"id": &"kremlincito", "name": "KREMLINCITO", "center": Vector2(40, 30), "radius": 14.0},
		{"id": &"space_equis", "name": "SPACE EQUIS", "center": Vector2(-22, -48), "radius": 11.0},
		{"id": &"muro", "name": "EL MURO (NADIE LO PAGÓ)", "center": Vector2(10, 55), "radius": 16.0},
		{"id": &"bunker", "name": "BÚNKER ANTINUCLEAR", "center": Vector2(28, -10), "radius": 7.0},
		{"id": &"bunker", "name": "BÚNKER ANTINUCLEAR", "center": Vector2(-55, -16), "radius": 7.0},
		{"id": &"bunker", "name": "BÚNKER ANTINUCLEAR", "center": Vector2(-12, 36), "radius": 7.0},
	]
	_build_heights()
	_build_terrain()
	_build_water()
	_nature_body = StaticBody3D.new()
	_nature_body.name = "Nature"
	_nature_body.collision_layer = Layers.WORLD
	_nature_body.collision_mask = 0
	add_child(_nature_body)
	_build_pois()
	_scatter_nature()
	_compute_points()


func height_at(x: float, z: float) -> float:
	var fx := x + HALF
	var fz := z + HALF
	if fx < 0.0 or fz < 0.0 or fx >= SIZE or fz >= SIZE:
		return SEA_FLOOR
	var i := int(fx)
	var j := int(fz)
	var tx := fx - i
	var tz := fz - j
	var width := SIZE + 1
	var top := lerpf(heights[j * width + i], heights[j * width + i + 1], tx)
	var bottom := lerpf(heights[(j + 1) * width + i], heights[(j + 1) * width + i + 1], tx)
	return lerpf(top, bottom, tz)


func is_in_bunker(point: Vector3) -> bool:
	for bunker in bunkers:
		var local := bunker.global_transform.affine_inverse() * point
		if absf(local.x) < 3.5 and absf(local.z) < 3.5 and local.y > -1.0 and local.y < 3.0:
			return true
	return false


## Punto de tierra firme al azar (para loot, bots y la lluvia de empanadas).
func random_land_point(rng: RandomNumberGenerator, center := Vector3.ZERO, radius := ISLAND_RADIUS) -> Vector3:
	for attempt in 30:
		var angle := rng.randf() * TAU
		var distance := sqrt(rng.randf()) * radius
		var x := center.x + cos(angle) * distance
		var z := center.z + sin(angle) * distance
		var h := height_at(x, z)
		if h > 1.2:
			return Vector3(x, h, z)
	return Vector3(center.x, height_at(center.x, center.z), center.z)


# --- Terreno --------------------------------------------------------------------

func _build_heights() -> void:
	var hills := FastNoiseLite.new()
	hills.seed = map_seed
	hills.frequency = 0.018
	hills.fractal_octaves = 4
	var coast := FastNoiseLite.new()
	coast.seed = map_seed + 1
	coast.frequency = 0.035
	var width := SIZE + 1
	heights.resize(width * width)
	for j in width:
		for i in width:
			heights[j * width + i] = _raw_height(float(i - HALF), float(j - HALF), hills, coast)
	for poi in _pois:
		_flatten(poi)


func _raw_height(x: float, z: float, hills: FastNoiseLite, coast: FastNoiseLite) -> float:
	var distance := Vector2(x, z).length() / ISLAND_RADIUS + coast.get_noise_2d(x, z) * 0.16
	var land_mask := 1.0 - smoothstep(0.62, 0.98, distance)
	var inland := clampf(1.0 - distance, 0.0, 1.0)
	var hill_height := (hills.get_noise_2d(x, z) * 0.5 + 0.5) * 7.0 * smoothstep(0.05, 0.55, inland)
	var peak := maxf(0.0, 1.0 - Vector2(x, z).distance_to(MOUNTAIN_CENTER) / 26.0)
	var land := 1.4 + hill_height + peak * peak * 16.0
	return lerpf(SEA_FLOOR, land, land_mask)


## Aplana el terreno alrededor de un lugar para poder construir encima.
func _flatten(poi: Dictionary) -> void:
	var center: Vector2 = poi["center"]
	var radius: float = poi["radius"]
	var width := SIZE + 1
	var center_index := int(center.y + HALF) * width + int(center.x + HALF)
	var target := maxf(heights[center_index], 1.8)
	poi["height"] = target
	var reach := int(radius * 1.7)
	for j in range(int(center.y) - reach, int(center.y) + reach + 1):
		for i in range(int(center.x) - reach, int(center.x) + reach + 1):
			if i < -HALF or i > HALF or j < -HALF or j > HALF:
				continue
			var index := (j + HALF) * width + (i + HALF)
			var weight := 1.0 - smoothstep(radius * 0.85, radius * 1.6, Vector2(i, j).distance_to(center))
			heights[index] = lerpf(heights[index], target, weight)


func _build_terrain() -> void:
	var width := SIZE + 1
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	vertices.resize(width * width)
	normals.resize(width * width)
	colors.resize(width * width)
	var tint := FastNoiseLite.new()
	tint.seed = map_seed + 7
	tint.frequency = 0.08
	for j in width:
		for i in width:
			var index := j * width + i
			var h := heights[index]
			vertices[index] = Vector3(i - HALF, h, j - HALF)
			var normal := Vector3(_grid_height(i - 1, j) - _grid_height(i + 1, j), 2.0,
				_grid_height(i, j - 1) - _grid_height(i, j + 1)).normalized()
			normals[index] = normal
			colors[index] = _terrain_color(h, normal.y, tint.get_noise_2d(i, j))

	var indices := PackedInt32Array()
	indices.resize(SIZE * SIZE * 6)
	var k := 0
	for j in SIZE:
		for i in SIZE:
			var a := j * width + i
			var b := a + 1
			var c := a + width
			var d := c + 1
			indices[k] = a
			indices[k + 1] = b
			indices[k + 2] = c
			indices[k + 3] = b
			indices[k + 4] = d
			indices[k + 5] = c
			k += 6

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.95
	var terrain := MeshInstance3D.new()
	terrain.name = "Terrain"
	terrain.mesh = mesh
	terrain.material_override = material
	add_child(terrain)

	var body := StaticBody3D.new()
	body.name = "TerrainBody"
	body.collision_layer = Layers.WORLD
	body.collision_mask = 0
	var shape := HeightMapShape3D.new()
	shape.map_width = width
	shape.map_depth = width
	shape.map_data = heights
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)
	add_child(body)


func _grid_height(i: int, j: int) -> float:
	var width := SIZE + 1
	return heights[clampi(j, 0, SIZE) * width + clampi(i, 0, SIZE)]


func _terrain_color(h: float, normal_y: float, variation: float) -> Color:
	if h < -0.3:
		return WET_SAND.darkened(clampf(-h / 8.0, 0.0, 0.5))
	if h < 1.6:
		return SAND
	if normal_y < 0.78 or h > 14.0:
		return ROCK.lightened(variation * 0.1)
	var grass := GRASS.lerp(DARK_GRASS, variation * 0.5 + 0.5)
	return SAND.lerp(grass, smoothstep(1.6, 2.4, h))


func _build_water() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(WATER_SIZE, WATER_SIZE)
	var material := ShaderMaterial.new()
	material.shader = WATER_SHADER
	var water := MeshInstance3D.new()
	water.name = "Water"
	water.mesh = plane
	water.material_override = material
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(water)


# --- Lugares ------------------------------------------------------------------

func _build_pois() -> void:
	for poi in _pois:
		var center: Vector2 = poi["center"]
		var root := StaticBody3D.new()
		root.name = String(poi["id"]).capitalize().replace(" ", "")
		root.collision_layer = Layers.WORLD
		root.collision_mask = 0
		root.position = Vector3(center.x, poi["height"], center.y)
		# El frente de cada lugar (+Z local) mira al centro de la isla.
		if center.length() > 1.0:
			root.rotation.y = atan2(-center.x, -center.y)
		add_child(root)
		var local_loot: Array[Vector3] = []
		var sign_height := 8.0
		match poi["id"]:
			&"plaza":
				local_loot = _build_plaza(root)
				sign_height = 12.0
			&"casa_rosadita":
				local_loot = _build_casa_rosadita(root)
				sign_height = 9.0
			&"kremlincito":
				local_loot = _build_kremlincito(root)
				sign_height = 14.5
			&"space_equis":
				local_loot = _build_space_equis(root)
				sign_height = 20.0
			&"muro":
				local_loot = _build_muro(root)
				sign_height = 8.0
			&"bunker":
				local_loot = _build_bunker(root)
				bunkers.append(root)
				sign_height = 5.5
		_sign(root, poi["name"], Vector3(0, sign_height, 0))
		for point in local_loot:
			loot_points.append(root.transform * point)
		wander_points.append(root.position)


func _build_plaza(root: Node3D) -> Array[Vector3]:
	_cylinder(root, 15.0, 0.3, Vector3(0, 0.15, 0), STONE, true, -1.0, 40)
	_cylinder(root, 3.2, 1.2, Vector3(0, 0.9, 0), STONE.darkened(0.2))
	# El mate gigante.
	_sphere(root, 2.6, Vector3(0, 4.4, 0), Color(0.45, 0.28, 0.15), Vector3(1.0, 1.15, 1.0))
	_collision_cylinder(root, 2.6, 6.0, Vector3(0, 4.4, 0))
	_cylinder(root, 2.0, 0.5, Vector3(0, 7.3, 0), Color(0.55, 0.35, 0.2), false)
	_cylinder(root, 1.85, 0.15, Vector3(0, 7.55, 0), Color(0.35, 0.6, 0.2), false)
	var straw := _cylinder(root, 0.14, 4.5, Vector3(0.8, 9.0, 0), METAL, false)
	straw.rotation.z = -0.3
	for i in 6:
		var angle := TAU * i / 6.0
		_box(root, Vector3(2.4, 0.5, 0.7), Vector3(cos(angle) * 10.0, 0.55, sin(angle) * 10.0), Color(0.55, 0.35, 0.2), true, -angle + PI * 0.5)
	return [Vector3(6, 0.3, 0), Vector3(-6, 0.3, 0), Vector3(0, 0.3, 6), Vector3(0, 0.3, -6)]


func _build_casa_rosadita(root: Node3D) -> Array[Vector3]:
	_box(root, Vector3(16, 0.4, 11), Vector3(0, 0.2, 0), WHITE)
	_box(root, Vector3(16, 5, 0.5), Vector3(0, 2.9, -5.25), PINK)
	_box(root, Vector3(0.5, 5, 11), Vector3(-7.75, 2.9, 0), PINK)
	_box(root, Vector3(0.5, 5, 11), Vector3(7.75, 2.9, 0), PINK)
	_box(root, Vector3(6.25, 5, 0.5), Vector3(-4.875, 2.9, 5.25), PINK)
	_box(root, Vector3(6.25, 5, 0.5), Vector3(4.875, 2.9, 5.25), PINK)
	_box(root, Vector3(3.5, 1.2, 0.5), Vector3(0, 4.8, 5.25), PINK)
	_box(root, Vector3(16.6, 0.5, 11.6), Vector3(0, 5.65, 0), WHITE)
	for x in [-6.0, -3.5, 3.5, 6.0]:
		_cylinder(root, 0.35, 5.0, Vector3(x, 2.9, 6.8), WHITE)
	_box(root, Vector3(16, 0.4, 2.4), Vector3(0, 5.4, 6.6), WHITE)
	_cylinder(root, 0.08, 3.0, Vector3(0, 7.4, 0), METAL, false)
	var stripes := [Color(0.45, 0.72, 0.95), WHITE, Color(0.45, 0.72, 0.95)]
	for i in 3:
		_box(root, Vector3(1.8, 0.35, 0.05), Vector3(1.0, 8.6 - i * 0.35, 0), stripes[i], false)
	return [Vector3(-4, 0.4, -2), Vector3(4, 0.4, -2), Vector3(0, 0.4, 1)]


func _build_kremlincito(root: Node3D) -> Array[Vector3]:
	_box(root, Vector3(18, 3.2, 0.8), Vector3(0, 1.6, -8.6), BRICK)
	_box(root, Vector3(0.8, 3.2, 18), Vector3(-8.6, 1.6, 0), BRICK)
	_box(root, Vector3(0.8, 3.2, 18), Vector3(8.6, 1.6, 0), BRICK)
	_box(root, Vector3(7, 3.2, 0.8), Vector3(-5.5, 1.6, 8.6), BRICK)
	_box(root, Vector3(7, 3.2, 0.8), Vector3(5.5, 1.6, 8.6), BRICK)
	for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		var x: float = corner.x * 8.6
		var z: float = corner.y * 8.6
		_box(root, Vector3(1.8, 5, 1.8), Vector3(x, 2.5, z), BRICK)
		_cylinder(root, 1.3, 2.2, Vector3(x, 6.1, z), Color(0.2, 0.55, 0.3), false, 0.0)
	_box(root, Vector3(4, 8, 4), Vector3(0, 4, -3), BRICK)
	_sphere(root, 2.4, Vector3(0, 9.6, -3), Color(0.95, 0.75, 0.2), Vector3(1.0, 1.25, 1.0))
	_cylinder(root, 0.5, 2.0, Vector3(0, 12.4, -3), Color(0.95, 0.75, 0.2), false, 0.0)
	var dome_colors := [Color(0.15, 0.45, 0.9), Color(0.2, 0.7, 0.3)]
	for i in 2:
		var x := -4.5 if i == 0 else 4.5
		_box(root, Vector3(2, 5, 2), Vector3(x, 2.5, -4), Color(0.85, 0.3, 0.25))
		_sphere(root, 1.4, Vector3(x, 5.9, -4), dome_colors[i], Vector3(1.0, 1.35, 1.0))
	return [Vector3(-4, 0, 3), Vector3(4, 0, 3), Vector3(0, 0, 1.5)]


func _build_space_equis(root: Node3D) -> Array[Vector3]:
	_cylinder(root, 7.0, 0.6, Vector3(0, 0.3, 0), CONCRETE, true, -1.0, 28)
	_cylinder(root, 1.2, 14.0, Vector3(0, 7.6, -2), WHITE)
	_cylinder(root, 1.2, 3.0, Vector3(0, 16.1, -2), Color(0.15, 0.15, 0.18), false, 0.0)
	for i in 3:
		var angle := TAU * i / 3.0
		_box(root, Vector3(0.25, 3.0, 2.2), Vector3(sin(angle) * 1.6, 2.1, -2 + cos(angle) * 1.6), Color(0.15, 0.15, 0.18), false, angle)
	_box(root, Vector3(2, 16, 2), Vector3(4.2, 8.6, -2), METAL)
	_box(root, Vector3(3.0, 0.4, 0.6), Vector3(2.6, 13.0, -2), METAL, false)
	return [Vector3(-3, 0.6, 3), Vector3(3, 0.6, 3), Vector3(0, 0.6, 4.5)]


func _build_muro(root: Node3D) -> Array[Vector3]:
	var wall_color := Color(0.78, 0.72, 0.6)
	_box(root, Vector3(20, 5, 1.2), Vector3(-12, 2.5, 0), wall_color)
	_box(root, Vector3(20, 5, 1.2), Vector3(12, 2.5, 0), wall_color)
	_box(root, Vector3(20, 0.3, 1.5), Vector3(-12, 5.15, 0), wall_color.darkened(0.3), false)
	_box(root, Vector3(20, 0.3, 1.5), Vector3(12, 5.15, 0), wall_color.darkened(0.3), false)
	return [Vector3(-8, 0, 3), Vector3(8, 0, -3), Vector3(0, 0, 4)]


func _build_bunker(root: Node3D) -> Array[Vector3]:
	_box(root, Vector3(7.4, 0.2, 7.4), Vector3(0, 0.1, 0), CONCRETE.darkened(0.25))
	_box(root, Vector3(8, 3, 0.6), Vector3(0, 1.5, -3.7), CONCRETE)
	_box(root, Vector3(0.6, 3, 8), Vector3(-3.7, 1.5, 0), CONCRETE)
	_box(root, Vector3(0.6, 3, 8), Vector3(3.7, 1.5, 0), CONCRETE)
	_box(root, Vector3(2.8, 3, 0.6), Vector3(-2.6, 1.5, 3.7), CONCRETE)
	_box(root, Vector3(2.8, 3, 0.6), Vector3(2.6, 1.5, 3.7), CONCRETE)
	_box(root, Vector3(8.6, 0.6, 8.6), Vector3(0, 3.3, 0), CONCRETE.darkened(0.2))
	for i in 5:
		var stripe_color := Color(0.95, 0.8, 0.1) if i % 2 == 0 else Color(0.1, 0.1, 0.1)
		_box(root, Vector3(0.5, 0.4, 0.1), Vector3(-1.0 + i * 0.5, 2.7, 4.05), stripe_color, false)
	return [Vector3(0, 0.2, -1.5)]


# --- Vegetación y rocas ------------------------------------------------------

func _scatter_nature() -> void:
	var palms: Array[Transform3D] = []
	var trees: Array[Transform3D] = []
	var bushes: Array[Transform3D] = []
	var rocks: Array[Transform3D] = []
	for attempt in 2600:
		var x := _rng.randf_range(-HALF + 4, HALF - 4)
		var z := _rng.randf_range(-HALF + 4, HALF - 4)
		var h := height_at(x, z)
		if h < 0.5 or _near_poi(Vector2(x, z), 4.0) or _slope_at(x, z) < 0.8:
			continue
		var base := Vector3(x, h - 0.1, z)
		var yaw := _rng.randf() * TAU
		if h < 2.3:
			if palms.size() < 55 and _rng.randf() < 0.35:
				palms.append(Transform3D(Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, _rng.randf_range(0.05, 0.25)), base))
		elif h < 13.0:
			var roll := _rng.randf()
			if roll < 0.18 and trees.size() < 80:
				trees.append(Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * _rng.randf_range(0.8, 1.3)), base))
			elif roll < 0.4 and bushes.size() < 110:
				bushes.append(Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * _rng.randf_range(0.6, 1.3)), base + Vector3.UP * 0.3))
		if _rng.randf() < 0.025 and rocks.size() < 45:
			var rock_scale := Vector3(_rng.randf_range(1.0, 2.4), _rng.randf_range(0.6, 1.4), _rng.randf_range(1.0, 2.2))
			rocks.append(Transform3D(Basis(Vector3.UP, yaw).scaled(rock_scale), base))

	_build_palms(palms)
	_build_trees(trees)
	_multimesh(_sphere_mesh(0.8, 7, 4), bushes, DARK_GRASS, 0.15)
	_multimesh(_sphere_mesh(1.0, 6, 4), rocks, ROCK, 0.12)
	for rock in rocks:
		var rock_size := rock.basis.get_scale()
		_collision_sphere(minf(rock_size.x, rock_size.z) * 0.85, rock.origin)


func _build_palms(palms: Array[Transform3D]) -> void:
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.18
	trunk.bottom_radius = 0.3
	trunk.height = 5.0
	trunk.radial_segments = 8
	var trunks: Array[Transform3D] = []
	var crowns: Array[Transform3D] = []
	for palm in palms:
		trunks.append(palm.translated_local(Vector3(0, 2.5, 0)))
		crowns.append(palm.translated_local(Vector3(0, 5.0, 0)))
		_collision_cylinder(_nature_body, 0.3, 5.0, palm.origin + Vector3.UP * 2.5)
	_multimesh(trunk, trunks, Color(0.6, 0.45, 0.3), 0.05)
	_multimesh(_palm_crown_mesh(), crowns, Color(0.3, 0.65, 0.25), 0.15)


func _build_trees(trees: Array[Transform3D]) -> void:
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.22
	trunk.bottom_radius = 0.32
	trunk.height = 3.0
	trunk.radial_segments = 7
	var trunks: Array[Transform3D] = []
	var crowns: Array[Transform3D] = []
	for tree in trees:
		trunks.append(tree.translated_local(Vector3(0, 1.5, 0)))
		crowns.append(tree.translated_local(Vector3(0, 4.0, 0)))
		_collision_cylinder(_nature_body, 0.35, 3.0, tree.origin + Vector3.UP * 1.5)
	_multimesh(trunk, trunks, Color(0.45, 0.32, 0.2), 0.05)
	_multimesh(_sphere_mesh(1.9, 8, 5), crowns, GRASS.darkened(0.1), 0.2)


func _palm_crown_mesh() -> Mesh:
	var leaf := BoxMesh.new()
	leaf.size = Vector3(0.55, 0.06, 2.6)
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 7:
		var leaf_basis := Basis(Vector3.UP, TAU * i / 7.0) * Basis(Vector3.RIGHT, 0.35)
		tool.append_from(leaf, 0, Transform3D(leaf_basis, Vector3.ZERO).translated_local(Vector3(0, 0, -1.2)))
	return tool.commit()


func _sphere_mesh(radius: float, segments: int, rings: int) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = segments
	mesh.rings = rings
	return mesh


## Muchas copias de un mesh en un solo draw call, con variación de color.
func _multimesh(mesh: Mesh, transforms: Array[Transform3D], color: Color, color_variation: float) -> void:
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = mesh
	multimesh.instance_count = transforms.size()
	for i in transforms.size():
		multimesh.set_instance_transform(i, transforms[i])
		var shade := _rng.randf_range(-color_variation, color_variation)
		multimesh.set_instance_color(i, color.lightened(shade) if shade > 0.0 else color.darkened(-shade))
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = multimesh
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.9
	instance.material_override = material
	add_child(instance)


func _near_poi(point: Vector2, margin: float) -> bool:
	for poi in _pois:
		if point.distance_to(poi["center"]) < float(poi["radius"]) + margin:
			return true
	return false


func _slope_at(x: float, z: float) -> float:
	return Vector3(height_at(x - 1, z) - height_at(x + 1, z), 2.0, height_at(x, z - 1) - height_at(x, z + 1)).normalized().y


# --- Puntos de aparición, loot y paseo ----------------------------------------

func _compute_points() -> void:
	for i in 12:
		var angle := TAU * i / 12.0 + 0.2
		for radius in range(62, 20, -3):
			var x := cos(angle) * radius
			var z := sin(angle) * radius
			var h := height_at(x, z)
			if h > 1.5 and not _near_poi(Vector2(x, z), 3.0) and _slope_at(x, z) > 0.85:
				spawn_points.append(Vector3(x, h + 1.0, z))
				break
	for i in 24:
		var point := random_land_point(_rng, Vector3.ZERO, 70.0)
		if not _near_poi(Vector2(point.x, point.z), 2.0):
			loot_points.append(point + Vector3.UP * 0.1)
	for i in 30:
		wander_points.append(random_land_point(_rng, Vector3.ZERO, 70.0))


# --- Primitivas ------------------------------------------------------------------

func _material(color: Color) -> StandardMaterial3D:
	var key := color.to_html()
	if not _materials.has(key):
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		material.roughness = 0.85
		_materials[key] = material
	return _materials[key]


func _box(root: Node3D, size: Vector3, local_position: Vector3, color: Color, collide := true, yaw := 0.0) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = _material(color)
	instance.position = local_position
	instance.rotation.y = yaw
	root.add_child(instance)
	if collide:
		var shape := BoxShape3D.new()
		shape.size = size
		var collision := CollisionShape3D.new()
		collision.shape = shape
		collision.position = local_position
		collision.rotation.y = yaw
		root.add_child(collision)
	return instance


func _cylinder(root: Node3D, radius: float, height: float, local_position: Vector3, color: Color, collide := true,
		top_radius := -1.0, segments := 16) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = radius
	mesh.top_radius = radius if top_radius < 0.0 else top_radius
	mesh.height = height
	mesh.radial_segments = segments
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = _material(color)
	instance.position = local_position
	root.add_child(instance)
	if collide:
		_collision_cylinder(root, radius, height, local_position)
	return instance


func _sphere(root: Node3D, radius: float, local_position: Vector3, color: Color, stretch := Vector3.ONE) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = _sphere_mesh(radius, 16, 8)
	instance.material_override = _material(color)
	instance.position = local_position
	instance.scale = stretch
	root.add_child(instance)
	return instance


func _collision_cylinder(body: Node3D, radius: float, height: float, local_position: Vector3) -> void:
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = height
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position = local_position
	body.add_child(collision)


func _collision_sphere(radius: float, local_position: Vector3) -> void:
	var shape := SphereShape3D.new()
	shape.radius = radius
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position = local_position
	_nature_body.add_child(collision)


func _sign(root: Node3D, text: String, local_position: Vector3) -> void:
	var label := Label3D.new()
	label.text = text
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 96
	label.outline_size = 20
	label.pixel_size = 0.014
	label.modulate = Color(1.0, 0.95, 0.75)
	label.position = local_position
	# Se ve de lejos para orientarse, pero se oculta de cerca para no tapar la pelea.
	label.visibility_range_begin = 22.0
	label.visibility_range_end = 170.0
	root.add_child(label)
