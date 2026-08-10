# ============================================================
# Rupidex KiCad 10 Library Setup
#
# Configures:
#   RUPIDEX_LIBS
#   RUPIDEX_3DMODEL_DIR
#
# Adds:
#   Rupidex symbol libraries directly
#   Rupidex footprint libraries directly
#
# KiCad's official libraries remain as nested Table entries.
#
# Footprint library directories must use the .pretty suffix.
# The KiCad library nickname does NOT contain .pretty.
# ============================================================

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "# Rupidex KiCad Library Setup" -ForegroundColor Cyan
Write-Host ""

# ------------------------------------------------------------
# Paths
# ------------------------------------------------------------

$LibRoot = "C:\Rupidex\KiCad\kicad-libs"
$ConfigRoot = Join-Path $env:APPDATA "kicad\10.0"

$SymbolDir = Join-Path $LibRoot "symbols"
$FootprintDir = Join-Path $LibRoot "footprints"
$ModelDir = Join-Path $LibRoot "3dmodels"

$SymTable = Join-Path $ConfigRoot "sym-lib-table"
$FpTable = Join-Path $ConfigRoot "fp-lib-table"

$KiCadSymTable =
    "C:/Program Files/KiCad/10.0/share/kicad/template/sym-lib-table"

$KiCadFpTable =
    "C:/Program Files/KiCad/10.0/share/kicad/template/fp-lib-table"

Write-Host "Library root: $LibRoot"
Write-Host "KiCad config: $ConfigRoot"
Write-Host ""

# ------------------------------------------------------------
# Validate required paths
# ------------------------------------------------------------

foreach ($Path in @(
    $LibRoot,
    $ConfigRoot,
    $SymbolDir,
    $FootprintDir,
    $ModelDir
)) {
    if (-not (Test-Path $Path)) {
        throw "Required path does not exist: $Path"
    }
}

if (-not (Test-Path $KiCadSymTable)) {
    throw "KiCad symbol table not found: $KiCadSymTable"
}

if (-not (Test-Path $KiCadFpTable)) {
    throw "KiCad footprint table not found: $KiCadFpTable"
}

# ------------------------------------------------------------
# Make sure KiCad is closed
# ------------------------------------------------------------

$KiCadProcesses = Get-Process `
    kicad, `
    eeschema, `
    pcbnew, `
    cvpcb, `
    footprint_editor, `
    symbol_editor `
    -ErrorAction SilentlyContinue

if ($KiCadProcesses) {

    Write-Host ""
    Write-Host "KiCad is currently running." -ForegroundColor Yellow
    Write-Host "Close KiCad completely and run this script again."
    Write-Host ""

    exit 1
}

# ------------------------------------------------------------
# Configure Rupidex path variables
# ------------------------------------------------------------

[Environment]::SetEnvironmentVariable(
    "RUPIDEX_LIBS",
    $LibRoot,
    "User"
)

[Environment]::SetEnvironmentVariable(
    "RUPIDEX_3DMODEL_DIR",
    $ModelDir,
    "User"
)

Write-Host "Library variables:"
Write-Host "  RUPIDEX_LIBS        = $LibRoot"
Write-Host "  RUPIDEX_3DMODEL_DIR = $ModelDir"
Write-Host ""

# ------------------------------------------------------------
# Backup existing KiCad tables
# ------------------------------------------------------------

$Timestamp = Get-Date -Format "yyyyMMdd-HHmmss"

if (Test-Path $SymTable) {

    $Backup = "$SymTable.backup-$Timestamp"

    Copy-Item `
        $SymTable `
        $Backup `
        -Force

    Write-Host "Backed up symbol table:"
    Write-Host "  $Backup"
}

if (Test-Path $FpTable) {

    $Backup = "$FpTable.backup-$Timestamp"

    Copy-Item `
        $FpTable `
        $Backup `
        -Force

    Write-Host "Backed up footprint table:"
    Write-Host "  $Backup"
}

Write-Host ""

# ------------------------------------------------------------
# Find symbol libraries
# ------------------------------------------------------------

$SymbolLibraries = @(
    Get-ChildItem `
        $SymbolDir `
        -File `
        -Filter "*.kicad_sym" `
        -ErrorAction SilentlyContinue |
    Sort-Object Name
)

Write-Host "Symbol libraries found: $($SymbolLibraries.Count)"
Write-Host ""

foreach ($lib in $SymbolLibraries) {
    Write-Host "- $($lib.BaseName)"
}

Write-Host ""

# ------------------------------------------------------------
# Find footprint libraries
#
# All Rupidex footprint library directories should end in
# .pretty.
#
# Example:
#
#   RPX_Crystal.pretty
#
# The nickname will be:
#
#   RPX_Crystal
#
# ------------------------------------------------------------

$FootprintLibraries = @(
    Get-ChildItem `
        $FootprintDir `
        -Directory `
        -Filter "*.pretty" `
        -ErrorAction SilentlyContinue |
    Sort-Object Name
)

Write-Host "Footprint libraries found: $($FootprintLibraries.Count)"
Write-Host ""

foreach ($lib in $FootprintLibraries) {
    Write-Host "- $($lib.Name)"
}

Write-Host ""

# ------------------------------------------------------------
# Build symbol table
# ------------------------------------------------------------

$SymLines = New-Object System.Collections.Generic.List[string]

$SymLines.Add("(sym_lib_table")
$SymLines.Add("    (version 7)")

# KiCad official symbol libraries
$SymLines.Add(
    '    (lib (name "KiCad") (type "Table") (uri "' +
    $KiCadSymTable +
    '") (options "") (descr "KiCad Default Libraries"))'
)

foreach ($lib in $SymbolLibraries) {

    # Example:
    #
    # File:
    #   RPX_Diode.kicad_sym
    #
    # Nickname:
    #   RPX_Diode

    $Name = $lib.BaseName

    # Actual file path
    $Uri = '${RUPIDEX_LIBS}/symbols/' + $lib.Name

    $SymLines.Add(
        '    (lib (name "' +
        $Name +
        '") (type "KiCad") (uri "' +
        $Uri +
        '") (options "") (descr "Rupidex custom symbols"))'
    )
}

$SymLines.Add(")")

# ------------------------------------------------------------
# Build footprint table
# ------------------------------------------------------------

$FpLines = New-Object System.Collections.Generic.List[string]

$FpLines.Add("(fp_lib_table")
$FpLines.Add("    (version 7)")

# KiCad official footprint libraries
$FpLines.Add(
    '    (lib (name "KiCad") (type "Table") (uri "' +
    $KiCadFpTable +
    '") (options "") (descr "KiCad Default Libraries"))'
)

foreach ($lib in $FootprintLibraries) {

    # IMPORTANT:
    #
    # Directory:
    #   RPX_Crystal.pretty
    #
    # KiCad nickname:
    #   RPX_Crystal
    #
    # Do NOT use $lib.BaseName here.
    # For DirectoryInfo, BaseName also returns .pretty.
    #
    # Explicitly remove the .pretty suffix.

    $Name = $lib.Name -replace '\.pretty$', ''

    # Actual directory path retains .pretty
    $Uri = '${RUPIDEX_LIBS}/footprints/' + $lib.Name

    $FpLines.Add(
        '    (lib (name "' +
        $Name +
        '") (type "KiCad") (uri "' +
        $Uri +
        '") (options "") (descr "Rupidex custom footprints"))'
    )
}

$FpLines.Add(")")

# ------------------------------------------------------------
# Write tables as UTF-8 without BOM
# ------------------------------------------------------------

$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)

[System.IO.File]::WriteAllLines(
    $SymTable,
    $SymLines,
    $Utf8NoBom
)

[System.IO.File]::WriteAllLines(
    $FpTable,
    $FpLines,
    $Utf8NoBom
)

# ------------------------------------------------------------
# Validation
# ------------------------------------------------------------

Write-Host ""
Write-Host "Validating generated tables..." -ForegroundColor Cyan
Write-Host ""

# Check that no Rupidex footprint nickname ends in .pretty
$BadFootprintNicknames = $FpLines |
    Where-Object {
        $_ -match '\(lib \(name "[^"]+\.pretty"'
    }

if ($BadFootprintNicknames) {

    Write-Host "ERROR: Footprint nicknames still contain .pretty:" `
        -ForegroundColor Red

    $BadFootprintNicknames | ForEach-Object {
        Write-Host $_ -ForegroundColor Red
    }

    throw "Invalid footprint nickname(s) detected."
}

# Check expected diode library
$DiodeLibrary = $FootprintLibraries |
    Where-Object {
        $_.Name -eq "RPX_Diode_SMD.pretty"
    }

if (-not $DiodeLibrary) {

    Write-Host "WARNING: RPX_Diode_SMD.pretty was not found." `
        -ForegroundColor Yellow
}

# Check expected diode footprint
$DiodeFootprint = Join-Path `
    $FootprintDir `
    "RPX_Diode_SMD.pretty\D_SOD-323F.kicad_mod"

if (Test-Path $DiodeFootprint) {

    Write-Host "Verified diode footprint:"
    Write-Host "  $DiodeFootprint"
}
else {

    Write-Host ""
    Write-Host "WARNING: D_SOD-323F.kicad_mod was not found." `
        -ForegroundColor Yellow
}

# Check expected crystal library
$CrystalLibrary = $FootprintLibraries |
    Where-Object {
        $_.Name -eq "RPX_Crystal.pretty"
    }

if (-not $CrystalLibrary) {

    Write-Host "WARNING: RPX_Crystal.pretty was not found." `
        -ForegroundColor Yellow
}

# Check expected crystal footprint
$CrystalFootprint = Join-Path `
    $FootprintDir `
    "RPX_Crystal.pretty\XTAL_ECS-240-18-33-JGN-TR3.kicad_mod"

if (Test-Path $CrystalFootprint) {

    Write-Host "Verified crystal footprint:"
    Write-Host "  $CrystalFootprint"
}
else {

    Write-Host ""
    Write-Host "WARNING: crystal footprint was not found." `
        -ForegroundColor Yellow
}

# ------------------------------------------------------------
# Final summary
# ------------------------------------------------------------

Write-Host ""
Write-Host "============================================================"
Write-Host "Rupidex KiCad setup complete"
Write-Host "============================================================"
Write-Host ""

Write-Host "Symbol libraries:"
Write-Host "  Found : $($SymbolLibraries.Count)"
Write-Host "  Added : $($SymbolLibraries.Count)"
Write-Host ""

Write-Host "Footprint libraries:"
Write-Host "  Found : $($FootprintLibraries.Count)"
Write-Host "  Added : $($FootprintLibraries.Count)"
Write-Host ""

Write-Host "Path variables:"
Write-Host "  RUPIDEX_LIBS        = $LibRoot"
Write-Host "  RUPIDEX_3DMODEL_DIR = $ModelDir"
Write-Host ""

Write-Host "Symbol table:"
Write-Host "  $SymTable"
Write-Host ""

Write-Host "Footprint table:"
Write-Host "  $FpTable"
Write-Host ""

Write-Host "Configuration:"
Write-Host "  KiCad default libraries remain nested Table entries."
Write-Host "  Rupidex libraries are direct entries."
Write-Host "  Footprint nicknames exclude .pretty."
Write-Host "  Footprint paths retain .pretty."
Write-Host ""

Write-Host "Start KiCad and check:"
Write-Host "  Preferences -> Manage Symbol Libraries"
Write-Host "  Preferences -> Manage Footprint Libraries"
Write-Host ""

Write-Host "Expected footprint examples:"
Write-Host "  RPX_Diode_SMD:D_SOD-323F"
Write-Host "  RPX_Crystal:XTAL_ECS-240-18-33-JGN-TR3"
Write-Host ""