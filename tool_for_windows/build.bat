@echo off
rem Y8960UPD for Windows build script (Visual Studio 2022 MSBuild)
rem Builds both the Japanese (Y8960UpdWin.exe) and English (Y8960UpdWinEn.exe) versions.
setlocal
cd /d "%~dp0"

set VSWHERE="%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe"
for /f "usebackq tokens=*" %%i in (`%VSWHERE% -latest -requires Microsoft.Component.MSBuild -find MSBuild\**\Bin\MSBuild.exe`) do set MSBUILD="%%i"
if not defined MSBUILD (
	echo MSBuild not found. Install Visual Studio 2022.
	exit /b 1
)

rem Japanese version (default UiLanguage=Ja), including the tests project.
rem Copy the exe out before the English build: rebuilding the same project
rem makes MSBuild remove the previous build's output from bin.
%MSBUILD% Y8960UpdWin.sln -restore -p:Configuration=Release -v:minimal -nologo
if errorlevel 1 exit /b 1
copy /Y Y8960UpdWin\bin\Release\net472\Y8960UpdWin.exe . > nul
if errorlevel 1 exit /b 1

rem English version (UiLanguage=En)
%MSBUILD% Y8960UpdWin\Y8960UpdWin.csproj -restore -p:Configuration=Release -p:UiLanguage=En -v:minimal -nologo
if errorlevel 1 exit /b 1
copy /Y Y8960UpdWin\bin\Release\net472\Y8960UpdWinEn.exe . > nul
if errorlevel 1 exit /b 1
echo.
echo Output: %~dp0Y8960UpdWin.exe
echo Output: %~dp0Y8960UpdWinEn.exe
endlocal
