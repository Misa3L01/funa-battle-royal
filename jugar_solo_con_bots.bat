@echo off
:: Abre el juego contra 9 bots. La partida arranca sola a los 3 segundos.
:: Si mueves Godot de lugar, actualiza la ruta de abajo.

set GODOT=R:\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64.exe
set PROYECTO=%~dp0.

start "Funa Battle Royal" "%GODOT%" --path "%PROYECTO%" -- --host --character=pessi --bots=9 --autostart=1
