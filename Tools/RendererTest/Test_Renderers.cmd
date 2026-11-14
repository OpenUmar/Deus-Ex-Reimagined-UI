@echo off
rem Reimagined UI renderer test: starts the game once per renderer, windowed,
rem straight into Liberty Island (01_NYC_UNATCOIsland), each with its own log.
rem Quit each run from the pause menu (Esc > Quit) to move on to the next.
setlocal
cd /d "%~dp0..\..\..\..\System"
set T=%~dp0
for %%R in (D3D D3D9 D3D10 OpenGL Software SecondRevision) do (
    echo Testing %%R ...
    if exist "%T%%%R.log" del "%T%%%R.log"
    start "" /wait DeusEx.exe INI="%T%DeusEx_%%R.ini" -log ABSLOG="%T%%%R.log" 01_NYC_UNATCOIsland
)
echo Done. Logs are in %T%
pause
