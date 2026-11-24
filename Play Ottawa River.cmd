@echo off
setlocal
set "river_engine=%GODOT_EXE%"
if not defined river_engine if exist "%~dp0build\godot\Godot_v4.7.2-stable_win64.exe" set "river_engine=%~dp0build\godot\Godot_v4.7.2-stable_win64.exe"
if not defined river_engine if exist "%~dp0..\build\godot\Godot_v4.7.2-stable_win64.exe" set "river_engine=%~dp0..\build\godot\Godot_v4.7.2-stable_win64.exe"
if not defined river_engine for /f "delims=" %%I in ('where.exe godot.exe godot4.exe 2^>nul') do if not defined river_engine set "river_engine=%%I"
if not exist "%river_engine%" (
    echo Set GODOT_EXE to the path to Godot 4.7.2, or put the engine in build\godot.
    pause
    exit /b 1
)

set "river_project=%~dp0godot-cove"
set "river_data=%~dp0.playtest-data"
set "APPDATA=%river_data%\player\AppData"
set "LOCALAPPDATA=%river_data%\player\LocalAppData"
if not exist "%APPDATA%" mkdir "%APPDATA%"
if not exist "%LOCALAPPDATA%" mkdir "%LOCALAPPDATA%"

if exist "%river_data%\imported.ok" if exist "%river_project%\.godot\global_script_class_cache.cfg" goto play
echo Importing game assets. The first launch may take a few minutes.
start "" /wait "%river_engine%" --headless --editor --import --path "%river_project%" --log-file "%river_data%\import.log"
if errorlevel 1 (
    echo Godot could not import the project. Check .playtest-data\import.log for details.
    pause
    exit /b 1
)
> "%river_data%\imported.ok" echo Imported

:play
start "" "%river_engine%" --path "%river_project%" --log-file "%river_data%\game.log" %*
