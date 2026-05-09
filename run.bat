@echo off
title Liberty Reach Launcher
cd /d "%~dp0"

chcp 65001 >nul

:menu
cls
echo ========================================
echo       LIBERTY REACH LAUNCHER
echo       AI-Powered P2P Messenger
echo ========================================
echo.
echo  Project: %CD%
echo.
echo  [1] Start LocalAI (Docker) - AI Engine
echo  [2] Start Rust P2P Node    - Backend
echo  [3] Start Flutter App      - UI (Windows)
echo  [4] Start ALL              - Everything
echo  [5] Open Project Folder
echo  [6] Run flutter_rust_bridge_codegen
echo  [7] System Check (prerequisites)
echo  [0] Exit
echo.
echo ========================================
set /p choice="Select [0-7]: "

if "%choice%"=="1" goto localai
if "%choice%"=="2" goto rust_node
if "%choice%"=="3" goto flutter_app
if "%choice%"=="4" goto all
if "%choice%"=="5" goto explorer
if "%choice%"=="6" goto frb_gen
if "%choice%"=="7" goto check
if "%choice%"=="0" exit /b

echo Invalid choice!
timeout /t 2 >nul
goto menu

:localai
cls
echo Starting LocalAI (Docker)...
echo.
echo Make sure Docker Desktop is running.
echo.
docker run -p 8080:8080 ^
  -v "%CD%\localai\models:/models" ^
  localai/localai:latest
echo.
pause
goto menu

:rust_node
cls
echo Starting Rust P2P Node...
echo.
set /p node_id="Enter node name [default: my-node]: "
if "%node_id%"=="" set node_id=my-node
echo.
cargo run --release -- --identity %node_id% --port 8000
echo.
pause
goto menu

:flutter_app
cls
echo Starting Flutter App...
echo.
cd flutter_app
flutter run -d windows
cd ..
echo.
pause
goto menu

:all
cls
echo Starting ALL components...
echo.
echo [1/3] Starting LocalAI (background)...
start "LocalAI" cmd /c "docker run -p 8080:8080 -v \"%CD%\localai\models:/models\" localai/localai:latest"
echo Waiting 15 seconds for LocalAI to initialize...
timeout /t 15 /nobreak >nul
echo.
echo [2/3] Starting Rust P2P Node (background)...
start "Liberty Node" cmd /c "cargo run --release -- --identity my-node --port 8000"
echo.
echo [3/3] Starting Flutter App...
cd flutter_app
flutter run -d windows
cd ..
echo.
pause
goto menu

:explorer
start explorer "%CD%"
goto menu

:frb_gen
cls
echo Running flutter_rust_bridge_codegen...
echo.
cd flutter_app
flutter_rust_bridge_codegen generate
cd ..
echo.
echo Done! Dart bindings regenerated.
pause
goto menu

:check
cls
echo ========================================
echo       SYSTEM CHECK
echo ========================================
echo.
where rustc >nul 2>&1 && (echo [OK] Rust:    found) || (echo [MISS] Rust
where flutter >nul 2>&1 && (echo [OK] Flutter: found) || (echo [MISS] Flutter
where docker >nul 2>&1 && (echo [OK] Docker:  found) || (echo [MISS] Docker
where flutter_rust_bridge_codegen >nul 2>&1 && (echo [OK] FRB:     found) || (echo [MISS] FRB codegen)
where cargo >nul 2>&1 && (echo [OK] Cargo:   found) || (echo [MISS] Cargo
echo.
echo  Model: %CD%\localai\models\gemma-2-2b-it-Q4_K_M.gguf
if exist "%CD%\localai\models\gemma-2-2b-it-Q4_K_M.gguf" (
    echo [OK] Gemma model: present
) else (
    echo [MISS] Gemma model: not downloaded
)
echo.
echo  Binary: %CD%\target\release\liberty-reach.exe
if exist "%CD%\target\release\liberty-reach.exe" (
    echo [OK] Rust binary: built
) else (
    echo [MISS] Rust binary: not built (run 'cargo build --release')
)
echo.
pause
goto menu
