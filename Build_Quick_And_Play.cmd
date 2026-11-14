@echo off
rem Rebuilds ReimaginedUI.u only (not the texture package), logs to build_ri.log, then launches the game.
cd /d "%~dp0"
echo Building ReimaginedUI.u...
call "%~dp0Build_ReimaginedUI.cmd" < nul > "%~dp0build_ri.log" 2>&1
findstr /c:"OK: Mods" "%~dp0build_ri.log" >nul || (echo ReimaginedUI build FAILED, see build_ri.log & timeout /t 8 >nul & exit /b 1)
echo Launching...
start "" /d "%~dp0..\..\System" "%~dp0..\..\System\Play_ReimaginedUI.cmd"
exit /b 0
