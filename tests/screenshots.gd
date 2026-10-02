extends Node
## Prueba visual: abre la arena, arma una partida con bots y guarda capturas en
## la carpeta indicada con --out=CARPETA (por defecto user://capturas).
## Uso: Godot --path . res://tests/screenshots.tscn -- --out=C:/capturas

var _out_dir := "user://capturas/"


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out_dir = arg.trim_prefix("--out=").trim_suffix("/") + "/"
	DirAccess.make_dir_recursive_absolute(_out_dir)
	_run.call_deferred()


func _run() -> void:
	# La arena pasa a ser la escena actual; este nodo queda al lado, sacando fotos.
	var arena: Node = load("res://arena/arena.tscn").instantiate()
	get_tree().root.add_child(arena)
	get_tree().current_scene = arena
	await _wait(2.0)
	await _shot("01_lobby")

	NetworkManager.local_character = &"pessi"
	NetworkManager.local_skin = &"oro"
	NetworkManager.host_game()
	NetworkManager.set_bot_count(9)
	NetworkManager.start_match()
	await _wait(1.0)

	var sky_camera := _camera(Vector3(-60, 95, 120), Vector3(0, 0, 5))
	await _wait(0.5)
	await _shot("02_isla")

	# Primer plano: varios personajes quietos frente a la cámara, con armas distintas.
	var host := GameManager.get_player(1)
	var weapons := [&"motosierra", &"puro", &"chancla", &"no_es_un_lanzallamas", &"bate", &"pelota"]
	var base := host.global_position + Vector3(0, 0, -7)
	base.y = GameManager.ground_height(base)
	var lineup: Array = GameManager.get_players().filter(func(p: Player) -> bool: return p.is_bot).slice(0, 6)
	for i in lineup.size():
		var bot: Player = lineup[i]
		bot.set_physics_process(false)
		bot.global_position = base + Vector3(-5.0 + i * 2.0, 0.05, (i % 2) * 1.2)
		bot.rotation.y = PI
		bot.combat.server_equip(DataLibrary.weapon(weapons[i]))
	_camera(base + Vector3(0, 2.0, 6.0), base + Vector3(0, 1.1, 0))
	await _wait(0.8)
	await _shot("03_personajes")
	_camera(base + Vector3(-3.0, 1.6, 2.6), base + Vector3(-3.0, 1.1, 0))
	await _wait(0.3)
	await _shot("04_armas_de_cerca")
	for bot: Player in lineup:
		bot.combat.request_attack(false, Vector3(0, 0, 1))
	await _wait(0.12)
	await _shot("05_ataques")
	for bot: Player in lineup:
		bot.set_physics_process(true)

	host.camera.current = true
	await _wait(6.0)
	await _shot("06_jugador")

	GameManager.debug_trigger(&"nuclear_strike")
	await _wait(3.0)
	await _shot("07_alerta_nuclear")
	sky_camera.current = true
	await _wait(8.6)
	await _shot("08_bomba")
	GameManager.debug_trigger(&"apagon")
	await _wait(6.5)
	_camera(Vector3(-20, 30, 40), Vector3(0, 0, 0))
	await _shot("09_apagon")
	get_tree().quit()


func _camera(from: Vector3, target: Vector3) -> Camera3D:
	var camera := Camera3D.new()
	camera.far = 1000.0
	get_tree().current_scene.add_child(camera)
	camera.global_position = from
	camera.look_at(target)
	camera.current = true
	return camera


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _shot(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_out_dir + file_name + ".png")
	print("Captura: ", file_name)
