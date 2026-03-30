$ErrorActionPreference = "Stop"

Write-Host "[1/4] Stop flutter/dart processes..."
Get-Process dart -ErrorAction SilentlyContinue | Stop-Process -Force
Get-Process flutter -ErrorAction SilentlyContinue | Stop-Process -Force

Write-Host "[2/4] Remove build directory..."
if (Test-Path build) {
  attrib -R build\* /S /D 2>$null
  Remove-Item -LiteralPath build -Recurse -Force
}

Write-Host "[3/4] Flutter clean..."
flutter clean

Write-Host "[4/4] Done. Now run: flutter run -d chrome"
