param(
  [string]$ExportDir = (Join-Path $PSScriptRoot "..\dist"),
  [string]$IssPath = (Join-Path $PSScriptRoot "desktop-pet.iss"),
  [string]$PayloadDir = (Join-Path $PSScriptRoot "payload"),
  [string]$OutputDir = (Join-Path $PSScriptRoot "output"),
  [string]$IsccPath,
  [string]$Version,
  [string]$HelperExePath
)

$ErrorActionPreference = "Stop"

function Resolve-FullPath {
  param([string]$PathValue)
  $resolved = Resolve-Path -Path $PathValue -ErrorAction Stop
  return $resolved.Path
}

function Find-Iscc {
  param([string]$PathValue)
  if ($PathValue -and (Test-Path -LiteralPath $PathValue)) {
    return (Resolve-FullPath $PathValue)
  }

  if ($env:ISCC -and (Test-Path -LiteralPath $env:ISCC)) {
    return (Resolve-FullPath $env:ISCC)
  }

  $candidates = @(
    "C:\Program Files (x86)\Inno Setup 6\ISCC.exe",
    "C:\Program Files\Inno Setup 6\ISCC.exe"
  )

  foreach ($c in $candidates) {
    if (Test-Path -LiteralPath $c) {
      return (Resolve-FullPath $c)
    }
  }

  return $null
}

$exportFull = $null
try {
  $exportFull = Resolve-FullPath $ExportDir
} catch {
  throw "ExportDir 不存在：$ExportDir"
}

if (-not (Test-Path -LiteralPath $IssPath)) {
  throw "找不到 .iss：$IssPath"
}

if (-not (Test-Path -LiteralPath $PayloadDir)) {
  New-Item -ItemType Directory -Path $PayloadDir | Out-Null
}

if (-not (Test-Path -LiteralPath $OutputDir)) {
  New-Item -ItemType Directory -Path $OutputDir | Out-Null
}

Get-ChildItem -LiteralPath $PayloadDir -Force -ErrorAction SilentlyContinue |
  Where-Object { $_.Name -ne ".gitkeep" } |
  Remove-Item -Force -Recurse -ErrorAction SilentlyContinue

Copy-Item -Path (Join-Path $exportFull "*") -Destination $PayloadDir -Recurse -Force

if ($HelperExePath -and (-not [string]::IsNullOrWhiteSpace($HelperExePath))) {
  if (-not (Test-Path -LiteralPath $HelperExePath)) {
    throw "HelperExePath 不存在：$HelperExePath"
  }

  $helperFull = Resolve-FullPath $HelperExePath
  Copy-Item -LiteralPath $helperFull -Destination (Join-Path $PayloadDir "helper-win.exe") -Force
}

$isccFull = Find-Iscc $IsccPath
if (-not $isccFull) {
  throw "找不到 ISCC.exe。请安装 Inno Setup 6，或通过 -IsccPath 指定路径，或设置环境变量 ISCC。"
}

$issFull = Resolve-FullPath $IssPath
$outputFull = Resolve-FullPath $OutputDir

$isccArgs = @()
$isccArgs += ("/O" + $outputFull)
if ($Version -and (-not [string]::IsNullOrWhiteSpace($Version))) {
  $isccArgs += ("/DMyAppVersion=""$Version""")
}
$isccArgs += $issFull

Push-Location -LiteralPath $PSScriptRoot
try {
  & $isccFull @isccArgs
  if ($LASTEXITCODE -ne 0) {
    throw "ISCC 编译失败，退出码：$LASTEXITCODE"
  }
} finally {
  Pop-Location
}
