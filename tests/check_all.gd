extends Node
## Prueba: carga todos los scripts, recursos y escenas del proyecto para detectar errores.

var _count := 0


func _ready() -> void:
	_walk("res://")
	print("Cargados: %d archivos" % _count)
	var roster := CharacterRoster.main()
	print("Roster: %d personajes" % roster.characters.size())
	for character in roster.characters:
		var problems := PackedStringArray()
		if character.ability == null:
			problems.append("sin habilidad")
		if character.face_texture == null:
			problems.append("sin cara")
		if character.body_model == null:
			problems.append("sin cuerpo")
		print("  %-18s %-16s hab=%-20s %s" % [character.display_name, character.country,
			character.ability.display_name if character.ability else "-", " ".join(problems)])
	print("Armas: ", DataLibrary.all_in(DataLibrary.WEAPON_DIR).map(func(w): return w.id))
	print("Efectos: ", DataLibrary.all_in(DataLibrary.STATUS_DIR).size())
	print("Skins: ", DataLibrary.all_in(DataLibrary.SKIN_DIR).map(func(s): return s.id))
	print("Rivalidades: ", GameManager.RIVALRIES.entries.size())
	for event in GameManager.event_pool:
		print("  evento %s (%s)" % [event.id, event.get_script().get_global_name()])
	get_tree().quit()


func _walk(path: String) -> void:
	for dir in DirAccess.get_directories_at(path):
		if dir.begins_with(".") or dir == "addons":
			continue
		_walk(path.path_join(dir))
	for file in DirAccess.get_files_at(path):
		if file.get_extension() in ["gd", "tres", "tscn", "gdshader"]:
			var resource := load(path.path_join(file))
			_count += 1
			if resource == null:
				print("NO CARGA: ", path.path_join(file))
