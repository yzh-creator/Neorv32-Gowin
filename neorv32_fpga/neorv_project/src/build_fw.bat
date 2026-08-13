@echo off
REM ==============================================================================
REM NEORV32 GW5AT-60B Firmware Builder (official common.mk + make)
REM ==============================================================================
setlocal

cd /d "%~dp0"

REM ---- Toolchain paths ----
set RISCV_BIN=E:\Download\xpack-riscv-none-elf-gcc-15.2.0-1\bin
set MINGW_BIN=E:\mingw64\bin

REM ---- Check tools ----
if not exist "%RISCV_BIN%\riscv-none-elf-gcc.exe" (
    echo [ERROR] RISC-V GCC not found at %RISCV_BIN%
    pause & exit /b 1
)
if not exist "%MINGW_BIN%\mingw32-make.exe" (
    echo [ERROR] mingw32-make not found at %MINGW_BIN%
    pause & exit /b 1
)

REM ---- Setup PATH ----
set PATH=%RISCV_BIN%;%MINGW_BIN%;%PATH%

REM ---- Build ----
echo ============================================
echo  NEORV32 GW5AT-60B Firmware Builder
echo  (using official common.mk)
echo ============================================
echo.
echo [INFO] Toolchain: %RISCV_BIN%
echo [INFO] Make:      %MINGW_BIN%\mingw32-make.exe
echo.

mingw32-make hw
if %ERRORLEVEL% neq 0 (
    echo.
    echo [FAIL] Build failed. See messages above.
    pause & exit /b 1
)

echo.
echo ============================================
echo  BUILD SUCCESS!
echo ============================================
echo.
echo Next: Re-run Synthesize in Gowin EDA.
echo.

pause
