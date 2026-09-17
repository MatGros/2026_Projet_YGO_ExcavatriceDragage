Ils ne prennent pas le bon device parce que j'ai plusieurs joysticks. Ils prennent le V Joy, c'est un joystick virtuel, donc ça ne sert à rien.@echo off
setlocal
cd /d "%~dp0"
python server.py
if errorlevel 1 pause
