@echo off
rem Launches the original Deus Ex with the Reimagined UI add-on.
rem Uses its own ini (Mods\ReimaginedUI\System\Vanilla\DeusEx.ini) and the
rem original's saves (..\Save); GMDX AE's setup is left alone.
cd /d "%~dp0"

rem Steam's own DeusEx.exe (64,000 bytes) relaunches itself through Steam and
rem drops the INI= setting below, so the game would start without the mod.
rem A DRM-free exe is needed: Kentie's DeusExe (via Vortex) or GOG's.
for %%A in (DeusEx.exe) do if %%~zA==64000 (
    echo DeusEx.exe is Steam's copy, which ignores this launcher's settings.
    echo Put Kentie's DeusExe back: in Vortex, Deus Ex ^> Deploy Mods.
    pause
    exit /b 1
)

rem Play_ReimaginedUI.cmd (GMDX AE) swaps AE's DeusEx.int in while it runs and
rem puts DeusEx.int_vanilla back afterwards. If AE's is still here (a crash
rem skips that), put the other one back first.
fc /b DeusEx.int "..\Mods\GMDX_AE\System\DeusEx.int" >nul 2>&1
if not errorlevel 1 if exist DeusEx.int_vanilla copy /y DeusEx.int_vanilla DeusEx.int >nul

rem Windows display scaling (125%/150% on laptops) makes Windows lie to the
rem old exe about the screen size, so borderless fullscreen opens at e.g.
rem 1280x720 and gets stretched. Mark DeusEx.exe as DPI-aware once, per user.
set "RI_LAYERS=HKCU\Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers"
reg query "%RI_LAYERS%" /v "%~dp0DeusEx.exe" 2>nul | find /i "HIGHDPIAWARE" >nul
if errorlevel 1 reg add "%RI_LAYERS%" /v "%~dp0DeusEx.exe" /t REG_SZ /d "~ HIGHDPIAWARE" /f >nul

DeusEx.exe INI="..\Mods\ReimaginedUI\System\Vanilla\DeusEx.ini" -log ABSLOG="%~dp0..\Mods\ReimaginedUI\System\Vanilla\ReimaginedUI.log" %*
