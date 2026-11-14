@echo off
rem Turns Reimagined UI on for the normal launch (Steam Play, Kentie's launcher).
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\Mods\ReimaginedUI\System\RISteam.ps1" On
pause
