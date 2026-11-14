@echo off
rem Test_One.cmd <Renderer>   e.g. Test_One.cmd OpenGL
cd /d "%~dp0..\..\..\..\System"
set T=%~dp0
if exist "%T%%1.log" del "%T%%1.log"
start "" DeusEx.exe INI="%T%DeusEx_%1.ini" -log ABSLOG="%T%%1.log" 01_NYC_UNATCOIsland
