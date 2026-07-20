param(
    [ValidatePattern('^/(?:[A-Za-z0-9_~-][A-Za-z0-9._~-]*/)*$')]
    [string]$BaseHref = '/'
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
Push-Location $repositoryRoot
try {
    & flutter build web --release --base-href $BaseHref
    if ($LASTEXITCODE -ne 0) {
        throw "Flutter Web release build failed with exit code $LASTEXITCODE."
    }
    Write-Host "Web release ready in build/web (base href: $BaseHref)."
}
finally {
    Pop-Location
}
