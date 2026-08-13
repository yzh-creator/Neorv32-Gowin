<#
.SYNOPSIS
  NEORV32 GW5AT-60B Firmware Builder
.DESCRIPTION
  Compile firmware and generate IMEM initialization VHDL.
  ONLY required: riscv-none-elf-gcc toolchain.
  
  Usage:
    .\build_fw.ps1                          # use PATH
    .\build_fw.ps1 -RISCV_PATH "E:\Download\xpack-riscv-none-elf-gcc-15.2.0-1\bin"
    .\build_fw.ps1 -Clean
#>

param(
    [string]$RISCV_PATH = "",
    [switch]$Clean = $false
)

# --- Configuration ---
$MARCH     = "rv32im_zicsr_zifencei"
$MABI      = "ilp32"
$EFFORT    = "-Os"
$ROM_SIZE  = "2k"
$RAM_SIZE  = "1k"

$SCRIPT_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $SCRIPT_DIR) { $SCRIPT_DIR = $PWD }

$NEORV32_HOME = Join-Path (Join-Path $SCRIPT_DIR "..") ".."
$NEORV32_HOME = Join-Path (Join-Path $NEORV32_HOME "..") "neorv32-main"
$CORE_DIR     = Join-Path (Join-Path $SCRIPT_DIR "..") "neorv32"
$CORE_DIR     = Join-Path $CORE_DIR "core"
$BUILD_DIR    = Join-Path $SCRIPT_DIR "build"
$MAIN_C       = Join-Path $SCRIPT_DIR "main.c"

$CC      = if ($RISCV_PATH) { Join-Path $RISCV_PATH "riscv-none-elf-gcc.exe" }     else { "riscv-none-elf-gcc" }
$OBJCOPY = if ($RISCV_PATH) { Join-Path $RISCV_PATH "riscv-none-elf-objcopy.exe" } else { "riscv-none-elf-objcopy" }
$OBJDUMP = if ($RISCV_PATH) { Join-Path $RISCV_PATH "riscv-none-elf-objdump.exe" } else { "riscv-none-elf-objdump" }
$SIZE    = if ($RISCV_PATH) { Join-Path $RISCV_PATH "riscv-none-elf-size.exe" }    else { "riscv-none-elf-size" }

$SRC_PATH  = "$NEORV32_HOME/sw/lib/source"
$COM_PATH  = "$NEORV32_HOME/sw/common"
$LD_SCRIPT = "$COM_PATH/neorv32.ld"

# --- Helper ---
function Write-OK   { Write-Host "[OK]   $($args[0])" -ForegroundColor Green }
function Write-INFO { Write-Host "[INFO] $($args[0])" -ForegroundColor Gray }
function Write-FAIL { Write-Host "[FAIL] $($args[0])" -ForegroundColor Red; pause; exit 1 }

# --- Checks ---
Write-Host "============================================" -ForegroundColor Cyan
Write-Host " NEORV32 GW5AT-60B Firmware Builder"          -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""
Write-INFO "Script dir: $SCRIPT_DIR"
Write-INFO "Work dir:   $PWD"
Write-Host ""

if (-not (Test-Path $CC)) {
    Write-Host "[FAIL] riscv-none-elf-gcc not found!" -ForegroundColor Red
    Write-Host "       Check path: $CC" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Edit RISCV_BIN in build_fw.bat to your toolchain path." -ForegroundColor Yellow
    Write-Host ""
    pause; exit 1
}
else {
    Write-OK "riscv-none-elf-gcc: $CC"
    $ver = & $CC --version 2>&1 | Select-Object -First 1
    Write-INFO "  $ver"
}

if (-not (Test-Path $NEORV32_HOME)) {
    Write-Host "[FAIL] NEORV32 framework not found!" -ForegroundColor Red
    Write-Host "       Check: $NEORV32_HOME" -ForegroundColor Yellow
    pause; exit 1
}
Write-OK "NEORV32 framework: $NEORV32_HOME"

if (-not (Test-Path $CORE_DIR)) {
    Write-Host "[FAIL] Core VHDL dir not found!" -ForegroundColor Red
    Write-Host "       Check: $CORE_DIR" -ForegroundColor Yellow
    pause; exit 1
}
Write-OK "Core VHDL dir: $CORE_DIR"

if (-not (Test-Path $MAIN_C)) {
    Write-Host "[FAIL] Source not found: $MAIN_C" -ForegroundColor Red
    pause; exit 1
}
Write-OK "Source: $MAIN_C"

# --- Compile ---
Write-Host ""
Write-INFO "Compiling firmware (MARCH=$MARCH)..."

if ($Clean -and (Test-Path $BUILD_DIR)) {
    Remove-Item -Recurse -Force $BUILD_DIR
}
New-Item -ItemType Directory -Path $BUILD_DIR -Force | Out-Null

$CORE_SRC = @(Get-ChildItem "$SRC_PATH/*.c" -ErrorAction SilentlyContinue | ForEach-Object { $_.FullName })
$APP_SRC  = @($MAIN_C)
$STARTUP  = "$COM_PATH/crt0.S"
$ALL_SRC  = $APP_SRC + $CORE_SRC + @($STARTUP)

function Run-Tool([string]$tool, [string[]]$argsList) {
    $pInfo = New-Object System.Diagnostics.ProcessStartInfo
    $pInfo.FileName = $tool
    foreach ($a in $argsList) { $pInfo.Arguments += "`"$a`" " }
    $pInfo.RedirectStandardOutput = $true
    $pInfo.RedirectStandardError = $true
    $pInfo.UseShellExecute = $false
    $pInfo.CreateNoWindow = $true
    $p = [System.Diagnostics.Process]::Start($pInfo)
    $out = $p.StandardOutput.ReadToEnd()
    $err = $p.StandardError.ReadToEnd()
    $p.WaitForExit()
    return @{ExitCode=$p.ExitCode; Output=$out; Error=$err}
}

$OBJ_FILES = @()
foreach ($src in $ALL_SRC) {
    $name = [System.IO.Path]::GetFileName($src)
    $obj  = Join-Path $BUILD_DIR "$name.o"
    $OBJ_FILES += $obj
    Write-INFO "  CC $name"

    if ($src.EndsWith(".S")) {
        $r = Run-Tool $CC @("-c", "-march=$MARCH", "-mabi=$MABI", $EFFORT, "-Wall", "-Wextra", "-g", "-ffunction-sections", "-fdata-sections", "-mno-fdiv", "-mstrict-align", "-mbranch-cost=10", "-ffp-contract=off", "-I$NEORV32_HOME/sw/lib/include", "-x", "assembler-with-cpp", "-o", "$obj", "$src")
    } else {
        $r = Run-Tool $CC @("-c", "-march=$MARCH", "-mabi=$MABI", $EFFORT, "-Wall", "-Wextra", "-g", "-ffunction-sections", "-fdata-sections", "-mno-fdiv", "-mstrict-align", "-mbranch-cost=10", "-ffp-contract=off", "-I$NEORV32_HOME/sw/lib/include", "-o", "$obj", "$src")
    }
    if ($r.ExitCode -ne 0) {
        Write-Host $r.Error -ForegroundColor Red
        Write-Host $r.Output -ForegroundColor Red
        Write-FAIL "Compile FAILED: $name"
    }
}

Write-INFO "  LINK main.elf"
$ELF = Join-Path $BUILD_DIR "main.elf"
$BIN = Join-Path $BUILD_DIR "neorv32_raw_exe.bin"
$ASM = Join-Path $BUILD_DIR "main.asm"
$LD_ARGS = @($EFFORT, "-T", "$LD_SCRIPT", "-march=$MARCH", "-mabi=$MABI", "-lm", "-lc", "-lgcc", "-nostartfiles", "-Wl,--gc-sections", "-Wl,--defsym,__neorv32_rom_size=$ROM_SIZE", "-Wl,--defsym,__neorv32_ram_size=$RAM_SIZE") + $OBJ_FILES + @("-o", "$ELF")
$r = Run-Tool $CC $LD_ARGS
if ($r.ExitCode -ne 0) {
    Write-Host $r.Error -ForegroundColor Red
    Write-Host $r.Output -ForegroundColor Red
    Write-FAIL "Link FAILED!"
}

Write-INFO "  OBJCOPY neorv32_raw_exe.bin"
$r = Run-Tool $OBJCOPY @("-O", "binary", "$ELF", "$BIN")
if ($r.ExitCode -ne 0) {
    Write-Host $r.Error -ForegroundColor Red
    Write-FAIL "objcopy FAILED!"
}

Write-INFO "  OBJDUMP main.asm"
$r = Run-Tool $OBJDUMP @("-D", "$ELF")
[System.IO.File]::WriteAllText($ASM, $r.Output)

& $SIZE $ELF 2>&1 | ForEach-Object { Write-Host "       $_" -ForegroundColor Gray }
Write-OK "main.elf"
Write-OK "neorv32_raw_exe.bin"

# --- bin -> VHDL ---
Write-Host ""
Write-INFO "Generating neorv32_imem_image.vhd..."

$bytes = [System.IO.File]::ReadAllBytes($BIN)
$padding = (4 - ($bytes.Length % 4)) % 4
if ($padding -gt 0) {
    $bytes += [byte[]]::new($padding)
}

$numWords = $bytes.Length / 4
$imageSize = $bytes.Length

$VHD_FILE = Join-Path $BUILD_DIR "neorv32_imem_image.vhd"
$writer = [System.IO.StreamWriter]::new($VHD_FILE, $false, [System.Text.Encoding]::ASCII)
$writer.WriteLine("library ieee;")
$writer.WriteLine("use ieee.std_logic_1164.all;")
$writer.WriteLine("")
$writer.WriteLine("package neorv32_imem_image is")
$writer.WriteLine("")
$writer.WriteLine("type rom_t is array (0 to " + ($numWords - 1) + ") of std_ulogic_vector(31 downto 0);")
$writer.WriteLine("constant image_size_c : natural := $imageSize;")
$writer.WriteLine("constant image_data_c : rom_t := (")

for ($i = 0; $i -lt $bytes.Length; $i += 4) {
    $b0 = [int]$bytes[$i]; $b1 = [int]$bytes[$i+1]; $b2 = [int]$bytes[$i+2]; $b3 = [int]$bytes[$i+3]
    $word = ($b3 -shl 24) -bor ($b2 -shl 16) -bor ($b1 -shl 8) -bor $b0
    if ($i -lt $bytes.Length - 4) {
        $writer.WriteLine("x""{0:X8}"",", $word)
    } else {
        $writer.WriteLine("x""{0:X8}""", $word)
    }
}

$writer.WriteLine(");")
$writer.WriteLine("end neorv32_imem_image;")
$writer.Close()

Write-OK "VHDL: $VHD_FILE"
Write-INFO "  Image: $imageSize bytes ($numWords words)"

# --- Copy to core dir ---
$VHD_TARGET = Join-Path $CORE_DIR "neorv32_imem_image.vhd"
Copy-Item $VHD_FILE $VHD_TARGET -Force
Write-OK "Copied to: $VHD_TARGET"

# --- Done ---
Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host " BUILD SUCCESS!"                               -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  ELF:       $BUILD_DIR\main.elf"
Write-Host "  ASM:       $BUILD_DIR\main.asm"
Write-Host "  BIN:       $BUILD_DIR\neorv32_raw_exe.bin"
Write-Host "  VHDL:      $VHD_FILE (copied to core/)"
Write-Host ""
Write-Host "Next: Re-run Synthesize in Gowin EDA"         -ForegroundColor Yellow
Write-Host "      1. Synthesize"
Write-Host "      2. Place & Route"
Write-Host "      3. Download"
Write-Host ""

pause