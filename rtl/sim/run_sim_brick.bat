@echo off
REM Simulation script for brick display testing
REM Place this in your sim folder

echo ================================================
echo Running Brick Display Simulation
echo ================================================
echo.

REM Check if work library exists
if not exist work (
    echo ERROR: Work library not found!
    echo Please run run_compile_brick.bat first.
    pause
    exit /b 1
)

echo Starting ModelSim...
echo.
echo After ModelSim opens:
echo   1. Type: do wave_brick.do
echo   2. Type: run 2ms
echo   3. Observe collision detection and brick erasure
echo.

vsim -t 1ns tb_brick_test