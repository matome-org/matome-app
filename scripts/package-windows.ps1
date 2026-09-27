param(
    [Parameter(Mandatory = $true)][string]$SourceDir,
    [Parameter(Mandatory = $true)][string]$Tag,
    [Parameter(Mandatory = $true)][string]$DistDir
)

$ErrorActionPreference = 'Stop'
$version = $Tag.TrimStart('v')
if ((Get-Content (Join-Path $SourceDir 'version.txt') -Raw).Trim() -ne $version) {
    throw 'package-windows: tag does not match version.txt'
}

$buildDir = Join-Path $env:RUNNER_TEMP 'matome-windows-build'
$stageDir = Join-Path $buildDir 'package'
New-Item -ItemType Directory -Force $buildDir, $stageDir, $DistDir | Out-Null
Push-Location $buildDir
try {
    & qmake (Join-Path $SourceDir 'matome.pro') 'CONFIG+=release'
    if ($LASTEXITCODE -ne 0) { throw 'qmake failed' }
    $qmDir = Join-Path $buildDir 'src/gui/.qm'
    New-Item -ItemType Directory -Force $qmDir | Out-Null
    $lrelease = Join-Path $env:QT_ROOT_DIR 'bin/lrelease.exe'
    foreach ($translation in Get-ChildItem (Join-Path $SourceDir 'src/gui/i18n') -Filter 'matome_*.ts') {
        $qm = Join-Path $qmDir ($translation.BaseName + '.qm')
        & $lrelease $translation.FullName -qm $qm
        if ($LASTEXITCODE -ne 0 -or -not (Test-Path $qm)) { throw "lrelease failed for $($translation.Name)" }
    }
    & nmake
    if ($LASTEXITCODE -ne 0) {
        Get-ChildItem (Join-Path $buildDir 'src/gui/.qm') | Select-Object -ExpandProperty Name
        throw 'nmake failed'
    }
} finally {
    Pop-Location
}

$binary = Join-Path $buildDir 'bin/matome-studio.exe'
if (-not (Test-Path $binary)) { throw "missing $binary" }
Copy-Item $binary $stageDir
& windeployqt --release --qmldir (Join-Path $SourceDir 'src/gui/qml') --dir $stageDir $binary
if ($LASTEXITCODE -ne 0) { throw 'windeployqt failed' }
Copy-Item (Join-Path $SourceDir 'LICENSE') $stageDir
$fontLicenses = Join-Path $stageDir 'font-licenses'
New-Item -ItemType Directory -Force $fontLicenses | Out-Null
Copy-Item (Join-Path $SourceDir 'src/gui/fonts/OFL-*.txt') $fontLicenses

$env:MATOME_VERSION = $version
$env:MATOME_PACKAGE_DIR = $stageDir
$env:MATOME_DIST_DIR = $DistDir
$automationDir = Split-Path $PSScriptRoot -Parent
$iscc = (Get-Command ISCC.exe -ErrorAction SilentlyContinue).Source
if (-not $iscc) {
    $iscc = Join-Path ${env:ProgramFiles(x86)} 'Inno Setup 6/ISCC.exe'
}
if (-not (Test-Path $iscc)) { throw 'Inno Setup ISCC.exe is missing' }
& $iscc (Join-Path $automationDir 'packaging/windows/matome.iss')
if ($LASTEXITCODE -ne 0) { throw 'ISCC failed' }
$installer = Join-Path $DistDir "matome-windows-x86_64-$Tag.exe"
if (-not (Test-Path $installer)) { throw "missing $installer" }
