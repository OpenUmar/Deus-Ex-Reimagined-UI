@echo off
rem Rebuilds ReimaginedUI.u for the original Deus Ex, logs to build_ri_vanilla.log, then launches it.
cd /d "%~dp0"
echo Building ReimaginedUI.u (vanilla)...
call "%~dp0Build_ReimaginedUI.cmd" Vanilla < nul > "%~dp0build_ri_vanilla.log" 2>&1
findstr /c:"OK: Mods" "%~dp0build_ri_vanilla.log" >nul || (echo ReimaginedUI vanilla build FAILED, see build_ri_vanilla.log & timeout /t 8 >nul & exit /b 1)
echo Launching...
start "" /d "%~dp0..\..\System" "%~dp0..\..\System\Play_ReimaginedUI_Vanilla.cmd"
exit /b 0
