<#
.SYNOPSIS
  NEORV32 VHDL 库修复/还原脚本
.DESCRIPTION
  将 neorv32/core/*.vhd 和顶层 wrapper 中的 neorv32 库引用替换为 work 库。
  解决 Gowin EDA 不支持多 VHDL 库的问题。
  
  修复模式（默认）:
    powershell -ExecutionPolicy Bypass -File fix_vhdl_lib.ps1
    
  还原模式（恢复原始 neorv32 库引用）:
    powershell -ExecutionPolicy Bypass -File fix_vhdl_lib.ps1 -Revert
#>

param([switch]$Revert = $false)

$coreDir  = "..\neorv32\core"
$srcDir   = "."
$topFiles = @("neorv32_gowin_top.vhd")

if (-not (Test-Path $coreDir)) {
    Write-Host "[ERROR] Cannot find $coreDir" -ForegroundColor Red
    Write-Host "        Run this script from the src/ directory." -ForegroundColor Red
    pause
    exit 1
}

# 处理 core 目录下的所有 .vhd 文件
$vhdFiles = Get-ChildItem -Path $coreDir -Filter "*.vhd"
$count = 0

foreach ($file in $vhdFiles) {
    $content = Get-Content $file.FullName -Raw
    $newContent = $content
    
    if (-not $Revert) {
        # 修复模式: neorv32 → work
        $newContent = $newContent -replace 'library\s+neorv32\s*;', 'library work;'
        $newContent = $newContent -replace '(\s)use\s+neorv32\.', '$1use work.'
        $newContent = $newContent -replace 'entity\s+neorv32\.', 'entity work.'
    } else {
        # 还原模式: work → neorv32
        $newContent = $newContent -replace 'library\s+work\s*;', 'library neorv32;'
        $newContent = $newContent -replace '(\s)use\s+work\.', '$1use neorv32.'
        $newContent = $newContent -replace 'entity\s+work\.', 'entity neorv32.'
    }
    
    if ($content -ne $newContent) {
        Set-Content -Path $file.FullName -Value $newContent -NoNewline
        $count++
    }
}

# 处理顶层 wrapper
foreach ($top in $topFiles) {
    $topPath = Join-Path $srcDir $top
    if (Test-Path $topPath) {
        $content = Get-Content $topPath -Raw
        $newContent = $content
        
        if (-not $Revert) {
            $newContent = $newContent -replace 'library\s+neorv32\s*;', 'library work;'
            $newContent = $newContent -replace '(\s)use\s+neorv32\.', '$1use work.'
        } else {
            $newContent = $newContent -replace 'library\s+work\s*;', 'library neorv32;'
            $newContent = $newContent -replace '(\s)use\s+work\.', '$1use neorv32.'
        }
        
        if ($content -ne $newContent) {
            Set-Content -Path $topPath -Value $newContent -NoNewline
            $count++
            Write-Host "[FIXED] $top" -ForegroundColor Green
        }
    }
}

if (-not $Revert) {
    Write-Host "Done! Fixed $count file(s). library/use/entity neorv32.* -> work.*" -ForegroundColor Green
} else {
    Write-Host "Done! Reverted $count file(s). library/use/entity work.* -> neorv32.*" -ForegroundColor Green
}
Write-Host ""
Write-Host "NOTE: If you update neorv32/core/*.vhd from the original source," -ForegroundColor Yellow
Write-Host "      re-run this script to apply the work-library fix again." -ForegroundColor Yellow
