param(
    [Parameter(Mandatory = $true)]
    [ValidateScript({ Test-Path -LiteralPath $_ -PathType Leaf })]
    [string]$ChromeExecutable,
    [ValidateRange(1, 65535)]
    [int]$Port = 8081,
    [ValidatePattern('^/(?:[A-Za-z0-9_~-][A-Za-z0-9._~-]*/)*$')]
    [string]$BasePath = '/',
    [string]$ContentRoot = 'build/web'
)

$ErrorActionPreference = 'Stop'
$previewScript = Join-Path $PSScriptRoot 'preview_web.ps1'
$profile = Join-Path ([IO.Path]::GetTempPath()) ("hybrid-web-smoke-" + [Guid]::NewGuid())
$preview = $null

function Test-FlutterPage([string]$Path, [string]$ReadyMarker = '') {
    $url = "http://127.0.0.1:$Port$Path"
    $arguments = @(
        '--headless=new', '--disable-gpu', '--no-first-run',
        '--disable-background-networking', '--disable-default-apps',
        "--user-data-dir=$profile", '--virtual-time-budget=5000',
        '--dump-dom', $url
    )
    $output = & $ChromeExecutable @arguments 2>&1 | Out-String
    if ($LASTEXITCODE -ne 0) {
        throw "Chrome failed to load '$url' (exit $LASTEXITCODE).`n$output"
    }
    if ($output -notmatch '<flutter-view|flt-glass-pane') {
        throw "Flutter did not start at '$url'.`n$output"
    }
    if ($ReadyMarker -and $output -notmatch ('data-hybrid-route-ready=["'']' + [regex]::Escape($ReadyMarker) + '["'']')) {
        throw "Flutter did not render the expected route '$ReadyMarker' at '$url'.`n$output"
    }
}

New-Item -ItemType Directory -Path $profile | Out-Null
try {
    $previewArguments = @(
        '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $previewScript,
        '-Port', $Port, '-BasePath', $BasePath, '-ContentRoot', $ContentRoot
    )
    $preview = Start-Process powershell -ArgumentList $previewArguments -PassThru -WindowStyle Hidden

    $ready = $false
    for ($attempt = 0; $attempt -lt 30 -and -not $ready; $attempt++) {
        try {
            $response = Invoke-WebRequest -UseBasicParsing -Uri "http://127.0.0.1:$Port$BasePath" -TimeoutSec 1
            $ready = $response.StatusCode -eq 200
        }
        catch {
            Start-Sleep -Milliseconds 100
        }
    }
    if (-not $ready) { throw 'The Web preview did not become ready.' }

    Test-FlutterPage $BasePath
    Test-FlutterPage ($BasePath + 'poc/531/generator') 'poc-531-generator'
    Write-Host "Web release smoke passed at $BasePath (entry + deep-link reload)."
}
finally {
    if ($preview -and -not $preview.HasExited) {
        Stop-Process -Id $preview.Id -Force -ErrorAction SilentlyContinue
    }
    if (Test-Path -LiteralPath $profile) {
        Remove-Item -LiteralPath $profile -Recurse -Force
    }
}
