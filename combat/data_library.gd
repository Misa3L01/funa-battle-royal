class_name DataLibrary
## Busca recursos de datos por id (efectos, armas, skins, consumibles).
##
## Por la red solo viajan ids; cada peer resuelve el recurso acá. Para sumar
## un arma o un efecto alcanza con crear su .tres en la carpeta que corresponde.

const STATUS_DIR := "res://combat/statuses/"
const WEAPON_DIR := "res://weapons/data/"
const SKIN_DIR := "res://weapons/skins/"
const CONSUMABLE_DIR := "res://weapons/consumables/"

static var _cache: Dictionary = {}


static func status(id: StringName) -> StatusEffect:
	return _lookup(STATUS_DIR, id) as StatusEffect


static func weapon(id: StringName) -> WeaponData:
	return _lookup(WEAPON_DIR, id) as WeaponData


static func skin(id: StringName) -> WeaponSkin:
	return _lookup(SKIN_DIR, id) as WeaponSkin


static func consumable(id: StringName) -> ConsumableData:
	return _lookup(CONSUMABLE_DIR, id) as ConsumableData


## Como los getters de arriba, pero sin avisar si no existe.
static func find(dir: String, id: StringName) -> Resource:
	return _load_dir(dir).get(id)


## Todos los recursos de una carpeta, ordenados por nombre de archivo.
static func all_in(dir: String) -> Array:
	return _load_dir(dir).values()


static func _lookup(dir: String, id: StringName) -> Resource:
	var entries := _load_dir(dir)
	if not entries.has(id):
		push_warning("DataLibrary: no existe '%s' en %s" % [id, dir])
		return null
	return entries[id]


static func _load_dir(dir: String) -> Dictionary:
	if _cache.has(dir):
		return _cache[dir]
	var entries := {}
	for file in ResourceLoader.list_directory(dir):
		if file.ends_with(".tres") or file.ends_with(".res"):
			var resource := load(dir + file)
			if resource and "id" in resource:
				entries[resource.id] = resource
	_cache[dir] = entries
	return entries
