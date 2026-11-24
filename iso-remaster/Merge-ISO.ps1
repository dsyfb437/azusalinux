# Run beside the four downloaded 0.1.1 ISO parts in PowerShell.
$ErrorActionPreference = 'Stop'
$releaseDirectory = $PSScriptRoot
$isoPath = Join-Path $releaseDirectory 'azusalinux-0.1.1-amd64.iso'
$expectedHash = '69132f27a2d86410992c079882c6ef56526e27757c5e3b8c8b730c5e086e2f31'
$partPaths = 0..3 | ForEach-Object {
    Join-Path $releaseDirectory ('azusalinux-0.1.1-amd64.iso.part-{0:00}' -f $_)
}
foreach ($partPath in $partPaths) {
    if (-not (Test-Path -LiteralPath $partPath -PathType Leaf)) {
        throw "Missing part: $partPath"
    }
}
if (Test-Path -LiteralPath $isoPath) {
    throw "Output already exists: $isoPath"
}
$outputStream = [System.IO.File]::Open($isoPath, [System.IO.FileMode]::CreateNew)
try {
    foreach ($partPath in $partPaths) {
        $inputStream = [System.IO.File]::OpenRead($partPath)
        try { $inputStream.CopyTo($outputStream) }
        finally { $inputStream.Dispose() }
    }
}
finally { $outputStream.Dispose() }
$actualHash = (Get-FileHash -LiteralPath $isoPath -Algorithm SHA256).Hash.ToLowerInvariant()
if ($actualHash -ne $expectedHash) {
    throw "SHA256 mismatch; do not boot this file: $isoPath"
}
Write-Host "Verified ISO: $isoPath"
