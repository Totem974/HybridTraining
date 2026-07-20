param(
    [ValidateRange(1, 65535)]
    [int]$Port = 8080,
    [ValidatePattern('^/(?:[A-Za-z0-9_~-][A-Za-z0-9._~-]*/)*$')]
    [string]$BasePath = '/',
    [string]$ContentRoot = 'build/web'
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$rootInput = if ([IO.Path]::IsPathRooted($ContentRoot)) {
    $ContentRoot
} else {
    Join-Path $repositoryRoot $ContentRoot
}
$resolvedRoot = [IO.Path]::GetFullPath($rootInput).TrimEnd(
    [IO.Path]::DirectorySeparatorChar,
    [IO.Path]::AltDirectorySeparatorChar
)
$rootPrefix = $resolvedRoot + [IO.Path]::DirectorySeparatorChar
if (-not (Test-Path -LiteralPath (Join-Path $resolvedRoot 'index.html') -PathType Leaf)) {
    throw "No Web release found at '$resolvedRoot'. Run tool/build_web_release.ps1 first."
}

$mimeTypes = @{
    '.css' = 'text/css'; '.html' = 'text/html; charset=utf-8'
    '.ico' = 'image/x-icon'; '.js' = 'text/javascript'
    '.json' = 'application/json'; '.png' = 'image/png'
    '.svg' = 'image/svg+xml'; '.wasm' = 'application/wasm'
}
$listener = [Net.HttpListener]::new()
$listener.Prefixes.Add("http://127.0.0.1:$Port/")
$listener.Start()
Write-Host "Preview: http://127.0.0.1:$Port$BasePath (Ctrl+C to stop)"

try {
    while ($listener.IsListening) {
        $context = $listener.GetContext()
        try {
            $requestPath = [Uri]::UnescapeDataString($context.Request.Url.AbsolutePath)
            if (-not $requestPath.StartsWith($BasePath, [StringComparison]::Ordinal)) {
                $context.Response.StatusCode = 404
                $context.Response.Close()
                continue
            }
            $relativePath = $requestPath.Substring($BasePath.Length).TrimStart('/')
            if ([string]::IsNullOrWhiteSpace($relativePath)) { $relativePath = 'index.html' }
            $candidate = [IO.Path]::GetFullPath((Join-Path $resolvedRoot $relativePath))
            if (-not $candidate.StartsWith($rootPrefix, [StringComparison]::OrdinalIgnoreCase)) {
                $context.Response.StatusCode = 404
                $context.Response.Close()
                continue
            }
            if (-not (Test-Path -LiteralPath $candidate -PathType Leaf)) {
                $candidate = Join-Path $resolvedRoot 'index.html'
            }
            $bytes = [IO.File]::ReadAllBytes($candidate)
            $extension = [IO.Path]::GetExtension($candidate).ToLowerInvariant()
            $contentType = $mimeTypes[$extension]
            if (-not $contentType) { $contentType = 'application/octet-stream' }
            $context.Response.ContentType = $contentType
            $context.Response.ContentLength64 = $bytes.Length
            $context.Response.OutputStream.Write($bytes, 0, $bytes.Length)
            $context.Response.Close()
        }
        catch {
            $context.Response.StatusCode = 500
            $context.Response.Close()
        }
    }
}
finally {
    $listener.Stop()
    $listener.Close()
}
