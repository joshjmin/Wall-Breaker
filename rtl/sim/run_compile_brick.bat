@echo off
REM Compilation script for brick display testing
REM Place this in your sim folder

echo ================================================
echo Compiling Brick Display Test
echo ================================================

REM Set file paths
set RTL_FILES=..\brick_display.v
set TB_FILES=tb_brick_test.v

REM Clean up old work library
if exist work rmdir /S /Q work

echo.
echo Creating work library...
vlib work

echo.
echo Compiling testbench...
vlog %TB_FILES%
if errorlevel 1 (
    echo ERROR: Testbench compilation failed!
    pause
    exit /b 1
)

echo.
echo Compiling RTL files...
vlog %RTL_FILES%
if errorlevel 1 (
    echo ERROR: RTL compilation failed!
    pause
    exit /b 1
)

echo.
echo ================================================
echo Compilation successful!
echo ================================================
echo.
echo To run simulation, use: run_sim_brick.bat
echo Or manually: vsim -t 1ns tb_brick_test
echo.
pause