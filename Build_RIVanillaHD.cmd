@echo off
rem Builds the Vanilla+ HD texture package (Real-ESRGAN 4x remasters of the original UI art)
rem into Mods\ReimaginedUI\System\RIVanillaHD.u. Only needed when the textures change;
rem ReimaginedUI.u loads them by name at run time, so the two build independently.
setlocal
cd /d "%~dp0..\..\System" 2>nul
if not exist "UCC.exe" cd /d "C:\Program Files (x86)\Steam\steamapps\common\Deus Ex\System" 2>nul
if not exist "UCC.exe" (
    echo Run this from Mods\ReimaginedUI inside the Deus Ex folder.
    pause
    exit /b 1
)

echo [1/3] Staging textures...
if exist "..\RIVanillaHD" rmdir /s /q "..\RIVanillaHD"
xcopy /e /i /q "..\Mods\ReimaginedUI\Source\RIVanillaHD" "..\RIVanillaHD" >nul
if exist "RIVanillaHD.u" del "RIVanillaHD.u"
if exist "..\Mods\ReimaginedUI\System\RIVanillaHD.u" del "..\Mods\ReimaginedUI\System\RIVanillaHD.u"
if exist "..\Mods\ReimaginedUI\System\RIVanillaHD.u" goto locked

rem Compile with the add-on's build ini, but with RIVanillaHD as the only new package
powershell -NoProfile -Command "(Get-Content '..\Mods\ReimaginedUI\System\RIBuild.ini') | Where-Object { $_ -notmatch '^EditPackages=(RINative|ReimaginedUI)$' } | ForEach-Object { $_; if ($_ -eq 'EditPackages=DeusEx') { 'EditPackages=RIVanillaHD' } } | Set-Content '..\Mods\ReimaginedUI\System\RIHDBuild.ini'"

echo [2/3] Importing textures (this takes a few minutes)...
UCC.exe make INI="..\Mods\ReimaginedUI\System\RIHDBuild.ini"

if not exist "RIVanillaHD.u" goto failed
move /y "RIVanillaHD.u" "..\Mods\ReimaginedUI\System\RIVanillaHD.u" >nul
rmdir /s /q "..\RIVanillaHD"
del "..\Mods\ReimaginedUI\System\RIHDBuild.ini"
echo [3/3] OK: Mods\ReimaginedUI\System\RIVanillaHD.u
pause
exit /b 0

:locked
echo RIVanillaHD.u is in use. Close the game and run this again.
pause
exit /b 1

:failed
echo Build FAILED. See the UCC output above.
if exist "..\RIVanillaHD" rmdir /s /q "..\RIVanillaHD"
pause
exit /b 1
