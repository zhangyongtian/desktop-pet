param(
  [string]$GodotExe
)

$ErrorActionPreference = "Stop"

function Resolve-FullPath {
  param([string]$PathValue)
  $resolved = Resolve-Path -Path $PathValue -ErrorAction Stop
  return $resolved.Path
}

function Find-Godot4Exe {
  param([string]$PathValue)

  if ($PathValue -and (-not [string]::IsNullOrWhiteSpace($PathValue))) {
    if (-not (Test-Path -LiteralPath $PathValue)) {
      throw "GodotExe 不存在：$PathValue"
    }
    return (Resolve-FullPath $PathValue)
  }

  $candidates = @()

  if ($env:GODOT4_EXE -and (Test-Path -LiteralPath $env:GODOT4_EXE)) { $candidates += $env:GODOT4_EXE }
  if ($env:GODOT_EXE -and (Test-Path -LiteralPath $env:GODOT_EXE)) { $candidates += $env:GODOT_EXE }

  $candidates += @(
    "C:\\Program Files\\Godot\\Godot_v4*.exe",
    "C:\\Program Files\\Godot\\Godot*4*.exe",
    "C:\\Program Files\\Godot4\\Godot.exe",
    "C:\\Program Files (x86)\\Godot\\Godot_v4*.exe",
    "C:\\Program Files (x86)\\Godot\\Godot*4*.exe",
    "C:\\Program Files (x86)\\Godot4\\Godot.exe",
    "C:\\Godot\\Godot_v4*.exe",
    "C:\\Godot\\Godot*4*.exe",
    "C:\\Godot4\\Godot.exe"
  )

  if ($env:LOCALAPPDATA) {
    $candidates += @(
      (Join-Path $env:LOCALAPPDATA "Programs\\Godot\\Godot_v4*.exe"),
      (Join-Path $env:LOCALAPPDATA "Programs\\Godot\\Godot*4*.exe"),
      (Join-Path $env:LOCALAPPDATA "Programs\\Godot4\\Godot.exe")
    )
  }

  if ($env:USERPROFILE) {
    $candidates += @(
      (Join-Path $env:USERPROFILE "Downloads\\Godot_v4*.exe"),
      (Join-Path $env:USERPROFILE "Downloads\\Godot*4*.exe")
    )
  }

  foreach ($c in $candidates) {
    if (-not $c) {
      continue
    }

    if ($c.Contains("*")) {
      $items = Get-ChildItem -Path $c -ErrorAction SilentlyContinue |
        Where-Object { -not $_.PSIsContainer } |
        Where-Object { $_.Name -match "(^|[^0-9])4([^0-9]|$)" -or $_.Name -match "v4" -or $_.FullName -match "Godot4" } |
        Sort-Object -Property LastWriteTime -Descending

      if ($items -and $items.Count -gt 0) {
        return $items[0].FullName
      }
      continue
    }

    if (Test-Path -LiteralPath $c) {
      return (Resolve-FullPath $c)
    }
  }

  return $null
}

$repoRoot = (Resolve-Path -Path (Join-Path $PSScriptRoot "..")).Path
$helperWinDir = Join-Path $repoRoot "apps\\desktop-pet\\helper-win"

if (-not (Test-Path -LiteralPath $helperWinDir)) {
  throw "找不到 helper-win 目录：$helperWinDir"
}

$cargoCmd = Get-Command cargo -ErrorAction SilentlyContinue
if (-not $cargoCmd) {
  throw "找不到 cargo（Rust 工具链）。请安装 rustup，并确保 cargo 在 PATH 中。"
}

Write-Host "[verify] helper-win cargo test"
Push-Location -LiteralPath $helperWinDir
try {
  & cargo test
  if ($LASTEXITCODE -ne 0) {
    throw "helper-win cargo test 失败，退出码：$LASTEXITCODE"
  }
} finally {
  Pop-Location
}

$godotFull = Find-Godot4Exe $GodotExe
if (-not $godotFull) {
  Write-Host "[verify] 未找到 Godot4 可执行文件，跳过 Godot 自检"
  exit 0
}

$godotProjectDir = Join-Path $repoRoot "apps\\desktop-pet\\godot"
if (-not (Test-Path -LiteralPath $godotProjectDir)) {
  throw "找不到 Godot 项目目录：$godotProjectDir"
}

Write-Host "[verify] godot headless self_check"
Push-Location -LiteralPath $godotProjectDir
try {
  & $godotFull --headless --quit --script "res://tests/self_check.gd"
  if ($LASTEXITCODE -ne 0) {
    throw "Godot 自检失败，退出码：$LASTEXITCODE"
  }
} finally {
  Pop-Location
}

Write-Host "[verify] PASS"
