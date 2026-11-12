@echo off
rem Builds ReimaginedUI.u for every base (GMDX AE and the original), logs to build_all.log.
cd /d "%~dp0"
echo Building for GMDX AE...
call "%~dp0Build_ReimaginedUI.cmd" AE < nul > "%~dp0build_ri.log" 2>&1
findstr /c:"OK: Mods" "%~dp0build_ri.log" >nul && (echo   AE OK) || (echo   AE FAILED, see build_ri.log)
echo Building for vanilla Deus Ex...
call "%~dp0Build_ReimaginedUI.cmd" Vanilla < nul > "%~dp0build_ri_vanilla.log" 2>&1
findstr /c:"OK: Mods" "%~dp0build_ri_vanilla.log" >nul && (echo   Vanilla OK) || (echo   Vanilla FAILED, see build_ri_vanilla.log)
pause
