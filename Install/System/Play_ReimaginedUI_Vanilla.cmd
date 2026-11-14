@echo off
rem Launches the original Deus Ex with the Reimagined UI add-on.
rem Uses its own ini (Mods\ReimaginedUI\System\Vanilla\DeusEx.ini) and the
rem game's own saves (..\Save).
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

rem Windows display scaling (125%/150% on laptops) makes Windows lie to the
rem old exe about the screen size, so borderless fullscreen opens at e.g.
rem 1280x720 and gets stretched. Mark DeusEx.exe as DPI-aware once, per user.
set "RI_LAYERS=HKCU\Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers"
reg query "%RI_LAYERS%" /v "%~dp0DeusEx.exe" 2>nul | find /i "HIGHDPIAWARE" >nul
if errorlevel 1 reg add "%RI_LAYERS%" /v "%~dp0DeusEx.exe" /t REG_SZ /d "~ HIGHDPIAWARE" /f >nul

rem Started on its own, so this window closes as soon as the game is up
start "" "%~dp0DeusEx.exe" INI="..\Mods\ReimaginedUI\System\Vanilla\DeusEx.ini" -log ABSLOG="%~dp0..\Mods\ReimaginedUI\System\Vanilla\ReimaginedUI.log" %*
exit
