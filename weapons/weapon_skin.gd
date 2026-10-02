class_name WeaponSkin
extends Resource
## Skin cosmética de armas (estilo Call of Duty). Cambia solo el material de
## las partes principales del arma; la lógica no se entera.

@export var id: StringName
@export var display_name: String
@export var rarity: WeaponData.Rarity = WeaponData.Rarity.COMUN
## Funas con un arma necesarias para desbloquearla (maestría). Por ahora todas
## están disponibles; cuando haya base de datos se valida contra esto.
@export var required_kills: int = 0
## La clásica deja los colores originales de cada arma.
@export var is_default := false
@export var albedo: Color = Color.WHITE
@export var metallic: float = 0.0
@export var roughness: float = 0.6
@export var emission: Color = Color.BLACK
@export var emission_energy: float = 0.0
## Shader animado opcional (reemplaza al material estándar).
@export var shader: Shader

var _material: Material


func get_material() -> Material:
	if _material:
		return _material
	if shader:
		var shader_material := ShaderMaterial.new()
		shader_material.shader = shader
		_material = shader_material
	else:
		var standard := StandardMaterial3D.new()
		standard.albedo_color = albedo
		standard.metallic = metallic
		standard.roughness = roughness
		if emission_energy > 0.0:
			standard.emission_enabled = true
			standard.emission = emission
			standard.emission_energy_multiplier = emission_energy
		_material = standard
	return _material
