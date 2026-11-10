@echo off
rem Builds RIVanillaHD.u and ReimaginedUI.u without pauses, logs to Mods\ReimaginedUI\*.log, then launches the game.
cd /d "%~dp0"
echo Building RIVanillaHD.u (textures, takes a few minutes)...
call "%~dp0Build_RIVanillaHD.cmd" < nul > "%~dp0build_hd.log" 2>&1
if not exist "%~dp0System\RIVanillaHD.u" (echo RIVanillaHD build FAILED, see build_hd.log & echo FAILED>>"%~dp0build_hd.log" & timeout /t 8 >nul & exit /b 1)
echo Building ReimaginedUI.u...
call "%~dp0Build_ReimaginedUI.cmd" < nul > "%~dp0build_ri.log" 2>&1
findstr /c:"OK: Mods" "%~dp0build_ri.log" >nul || (echo ReimaginedUI build FAILED, see build_ri.log & timeout /t 8 >nul & exit /b 1)
echo Launching...
start "" /d "%~dp0..\..\System" "%~dp0..\..\System\Play_ReimaginedUI.cmd"
exit /b 0
