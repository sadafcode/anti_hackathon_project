# Reads GOOGLE_MAPS_API_KEY from root .env and generates app/web/index.html
$root = Split-Path $PSScriptRoot -Parent
$envFile = Join-Path $root ".env"
$tmpl    = Join-Path $root "app\web\index.html.tmpl"
$out     = Join-Path $root "app\web\index.html"

$mapsKey = ""
foreach ($line in Get-Content $envFile) {
    if ($line -match "^GOOGLE_MAPS_API_KEY\s*=\s*(.+)$") {
        $mapsKey = $Matches[1].Trim().Trim('"')
        break
    }
}

if (-not $mapsKey) { Write-Error "GOOGLE_MAPS_API_KEY not found in .env"; exit 1 }

(Get-Content $tmpl -Raw) -replace '\{\{MAPS_API_KEY\}\}', $mapsKey | Set-Content $out -Encoding UTF8
Write-Host "index.html generated with Maps key."
