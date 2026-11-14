@echo off
rem Compiles the Reimagined UI add-on for one base:
rem   Build_ReimaginedUI.cmd           GMDX AE  -> Mods\ReimaginedUI\System\ReimaginedUI.u
rem   Build_ReimaginedUI.cmd Vanilla   Deus Ex  -> Mods\ReimaginedUI\System\Vanilla\ReimaginedUI.u
rem Source lives in Mods\ReimaginedUI\Source: the shared screens in ReimaginedUI,
rem plus the base's adapter classes in Base_<base>. No base mod's files are modified.
setlocal
set BASE=%~1
if "%BASE%"=="" set BASE=AE
if /i "%BASE%"=="AE" (
    set BASE=AE
    set OUT=..\Mods\ReimaginedUI\System
    set BUILDINI=..\Mods\ReimaginedUI\System\RIBuild.ini
) else if /i "%BASE%"=="Vanilla" (
    set BASE=Vanilla
    set OUT=..\Mods\ReimaginedUI\System\Vanilla
    set BUILDINI=..\Mods\ReimaginedUI\System\RIBuild_Vanilla.ini
) else (
    echo Unknown base "%BASE%". Use AE or Vanilla.
    pause
    exit /b 1
)
cd /d "%~dp0..\..\System"
if not exist "%OUT%" mkdir "%OUT%"
echo Base: %BASE%

echo [1/3] Staging source...
rem A rebuilt plugin dropped in the mod folder (Native\RINative.dll.new) goes in first
if exist "..\Mods\ReimaginedUI\Native\RINative.dll.new" copy /y "..\Mods\ReimaginedUI\Native\RINative.dll.new" "RINative.dll.new" >nul && del "..\Mods\ReimaginedUI\Native\RINative.dll.new"
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
rem The base's adapter (RIBase and the classes built on the base's own windows)
xcopy /y /q "..\Mods\ReimaginedUI\Source\Base_%BASE%\Classes\*.uc" "..\ReimaginedUI\Classes\" >nul
if errorlevel 1 goto failed

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
if exist "%OUT%\RINative.u" del "%OUT%\RINative.u"
if exist "%OUT%\ReimaginedUI.u" del "%OUT%\ReimaginedUI.u"
if exist "%OUT%\ReimaginedUI.u" goto locked
if exist "ReimaginedUI.u" goto locked
if exist "%OUT%\RINative.u" goto locked

echo [2/3] Compiling...
UCC.exe make INI="%BUILDINI%"

if not exist "ReimaginedUI.u" goto failed
move /y "ReimaginedUI.u" "%OUT%\ReimaginedUI.u" >nul
if exist "RINative.u" move /y "RINative.u" "%OUT%\RINative.u" >nul
> "..\Mods\ReimaginedUI\BuildNumber.txt" echo %BUILDNUM%
rmdir /s /q "..\ReimaginedUI"
if exist "..\RINative" rmdir /s /q "..\RINative"
echo [3/3] Build %BUILDNUM% OK: %OUT:..\=%\ReimaginedUI.u (%BASE%)
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
