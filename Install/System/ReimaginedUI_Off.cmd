@echo off
rem Turns Reimagined UI off again: the game starts untouched from Steam.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\Mods\ReimaginedUI\System\RISteam.ps1" Off
pause
