@echo off
:: Abre dos ventanas del juego en esta PC: una crea la partida (host) y la
:: otra se une sola. Se suman 6 bots y la partida arranca sola.
:: Si mueves Godot de lugar, actualiza la ruta de abajo.

set GODOT=R:\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64.exe
set PROYECTO=%~dp0.

start "Host" "%GODOT%" --path "%PROYECTO%" --resolution 960x540 --position 0,80 -- --host --character=pilei --bots=6 --autostart=2
ping -n 3 127.0.0.1 >nul
start "Cliente" "%GODOT%" --path "%PROYECTO%" --resolution 960x540 --position 960,80 -- --join=127.0.0.1 --character=birchner --skin=oro
