# Funa Battle Royal

Arena brawler 3D online de humor absurdo (Godot 4.6, GDScript, hasta 10 jugadores humanos + bots).

## Entrada
- Escena principal: `arena/arena.tscn` (script `arena/arena.gd`). El lobby y el HUD viven dentro de ella.
- Autoloads (en orden): `Fx` (sonidos/efectos), `NetworkManager` (ENet, lobby, bots), `GameManager` (reglas, eventos, zona, bajas).

## Módulos clave
- `player/`: `player.gd` (movimiento, cámara), `bot_controller.gd` (IA), `human_controller.gd`, `character_model.gd` (cuerpo + cara billboard).
- `combat/`: `combat_component.gd` (ataques, combos, armas, habilidad), `combat_system.gd` (fórmula de daño), `status_component.gd`, `rivalries.tres`.
- `weapons/`: armas, skins y consumibles como `.tres` (`data/`, `skins/`, `consumables/`); proyectiles y pickups.
- `abilities/`: 7 tipos de habilidad; cada personaje usa un `.tres` en `abilities/data/`.
- `characters/`: `roster.tres` + `roster/*.tres` + caras SVG.
- `events/`: eventos globales (nuclear, COVID, apagón...); se registran en `GameManager.event_pool`.
- `map/`: `island_generator.gd` (isla por semilla fija) e `inflation_zone.gd` (zona que se achica).
- `DISENO.md`: tablas de balance y cómo agregar contenido (usar grep para leer solo la sección necesaria).

## Probar
Godot (consola): `R:\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64_console.exe`
- Verificar que todo carga (un solo "test"): `<godot> --headless --path . res://tests/check_all.tscn`
- Partida sin ventana contra bots (modo simulado): `<godot> --headless --path . --time-scale 4 -- --host --character=pessi --bots=9 --autostart=1`. Filtrar la salida con grep por `Ganó`, `[Baja]` o `ERROR`.
- Modo demo con ventana: `jugar_solo_con_bots.bat` (9 bots) o `probar_2_jugadores.bat` (host + cliente).
- Capturas: `res://tests/screenshots.tscn -- --out=CARPETA`.

## Contratos que no se rompen
- Solo el servidor (peer 1) decide vida, daño, efectos, armas, eventos, zona y bots; los clientes reciben por RPC.
- Cada jugador mueve su personaje; vida, efectos y combate tienen autoridad 1.
- Por la red viajan ids (`StringName`), nunca recursos: resolver con `DataLibrary`. No renombrar ids ya publicados.
- La isla se genera idéntica en todos los peers con `map_seed`; no mandarla por red.
- Personajes con nombres en clave (parodia) y caras garabato: nunca nombres ni fotos reales.
- La lógica usa tags (`CharacterTags`), no ids de personajes.
- No usar `preload` del roster: usar `CharacterRoster.main()` (evita dependencias circulares).

## No leer
`.godot/`, `assets/`, `*.import`, `*.uid`, `builds/`.
