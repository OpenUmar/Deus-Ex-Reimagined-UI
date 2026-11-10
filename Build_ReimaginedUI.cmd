@echo off
rem Compiles the Reimagined UI add-on into Mods\ReimaginedUI\System\ReimaginedUI.u
rem Source lives in Mods\ReimaginedUI\Source. GMDX AE's files are never modified.
setlocal
cd /d "%~dp0..\..\System"

echo [1/3] Staging source...
rem A newer native plugin may be waiting (written while the game had the old one open)
if exist "RINative.dll.new" (
    move /y "RINative.dll.new" "RINative.dll" >nul
    if exist "RINative.dll.new" goto locked
    echo       Native plugin updated
)
if exist "..\ReimaginedUI" rmdir /s /q "..\ReimaginedUI"
if exist "..\RINative" rmdir /s /q "..\RINative"
if exist "..\RINative" rmdir /s /q "..\RINative"
xcopy /e /i /q "..\Mods\ReimaginedUI\Source\ReimaginedUI" "..\ReimaginedUI" >nul
xcopy /e /i /q "..\Mods\ReimaginedUI\Source\RINative" "..\RINative" >nul

rem Build number (kept in BuildNumber.txt, counted up on each successful build)
rem and build time, baked into RIBuildInfo and shown on the main menu
set BUILDNUM=0
if exist "..\Mods\ReimaginedUI\BuildNumber.txt" set /p BUILDNUM=<"..\Mods\ReimaginedUI\BuildNumber.txt"
set /a BUILDNUM=BUILDNUM+1
set BUILDTIME=unknown
set BUILDDAY=
set BUILDCLOCK=
for /f "delims=" %%i in ('powershell -NoProfile -Command Get-Date -Format yyyy-MM-dd') do set BUILDDAY=%%i
for /f "delims=" %%i in ('powershell -NoProfile -Command Get-Date -Format HH:mm') do set BUILDCLOCK=%%i
if defined BUILDDAY set BUILDTIME=%BUILDDAY% %BUILDCLOCK%
> "..\ReimaginedUI\Classes\RIBuildInfo.uc" echo class RIBuildInfo extends Object abstract;
>>"..\ReimaginedUI\Classes\RIBuildInfo.uc" echo var string BuildNumber;
>>"..\ReimaginedUI\Classes\RIBuildInfo.uc" echo var string BuildTime;
>>"..\ReimaginedUI\Classes\RIBuildInfo.uc" echo defaultproperties
>>"..\ReimaginedUI\Classes\RIBuildInfo.uc" echo {
>>"..\ReimaginedUI\Classes\RIBuildInfo.uc" echo      BuildNumber="%BUILDNUM%"
>>"..\ReimaginedUI\Classes\RIBuildInfo.uc" echo      BuildTime="%BUILDTIME%"
>>"..\ReimaginedUI\Classes\RIBuildInfo.uc" echo }
echo       Build %BUILDNUM% (%BUILDTIME%)
if exist "ReimaginedUI.u" del "ReimaginedUI.u"
if exist "RINative.u" del "RINative.u"
if exist "..\Mods\ReimaginedUI\System\RINative.u" del "..\Mods\ReimaginedUI\System\RINative.u"
if exist "..\Mods\ReimaginedUI\System\ReimaginedUI.u" del "..\Mods\ReimaginedUI\System\ReimaginedUI.u"
if exist "..\Mods\ReimaginedUI\System\ReimaginedUI.u" goto locked
if exist "ReimaginedUI.u" goto locked
if exist "..\Mods\ReimaginedUI\System\RINative.u" goto locked

echo [2/3] Compiling...
UCC.exe make INI="..\Mods\ReimaginedUI\System\RIBuild.ini"

if not exist "ReimaginedUI.u" goto failed
move /y "ReimaginedUI.u" "..\Mods\ReimaginedUI\System\ReimaginedUI.u" >nul
if exist "RINative.u" move /y "RINative.u" "..\Mods\ReimaginedUI\System\RINative.u" >nul
> "..\Mods\ReimaginedUI\BuildNumber.txt" echo %BUILDNUM%
rmdir /s /q "..\ReimaginedUI"
if exist "..\RINative" rmdir /s /q "..\RINative"
echo [3/3] Build %BUILDNUM% OK: Mods\ReimaginedUI\System\ReimaginedUI.u
pause
exit /b 0

:locked
rmdir /s /q "..\ReimaginedUI"
if exist "..\RINative" rmdir /s /q "..\RINative"
echo.
echo BUILD STOPPED: ReimaginedUI.u is still in use.
echo Close Deus Ex completely (including any error box, and DeusEx.exe in Task Manager), then run this again.
pause
exit /b 1

:failed
rmdir /s /q "..\ReimaginedUI"
if exist "..\RINative" rmdir /s /q "..\RINative"
echo.
echo BUILD FAILED. Errors are listed above and in System\ucc.log
pause
exit /b 1
