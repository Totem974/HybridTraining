param(
    [Parameter(Mandatory)]
    [string]$DriverPath,
    [ValidateRange(1, 65535)]
    [int]$DriverPort = 4444,
    [ValidateRange(1, 65535)]
    [int]$WebPort = 7357,
    [ValidateRange(15, 300)]
    [int]$TimeoutSeconds = 90,
    [string]$ChromeExecutable
)

$ErrorActionPreference = 'Stop'
$driver = (Resolve-Path -LiteralPath $DriverPath -ErrorAction Stop).Path
$version = & $driver --version
if ($LASTEXITCODE -ne 0) { throw 'ChromeDriver did not report a version.' }
Write-Host $version
$driverMajor = [regex]::Match(($version -join ' '), '\d+').Value

$probe = [Net.Sockets.TcpClient]::new()
try {
    $probe.Connect('127.0.0.1', $DriverPort)
    throw "Port $DriverPort is already in use."
}
catch [Net.Sockets.SocketException] { }
finally { $probe.Dispose() }

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$flutter = (Get-Command flutter -ErrorAction Stop).Source
$driverProcess = $null
$flutterProcess = $null

function Stop-ProcessTree([Diagnostics.Process]$Process) {
    if ($null -eq $Process -or $Process.HasExited) { return }
    & taskkill.exe /PID $Process.Id /T /F 2>$null | Out-Null
    if ($LASTEXITCODE -ne 0 -and -not $Process.HasExited) {
        Stop-Process -Id $Process.Id -Force -ErrorAction SilentlyContinue
    }
}

$previousChromeExecutable = $env:CHROME_EXECUTABLE
if ($ChromeExecutable) {
    $resolvedChrome = (Resolve-Path -LiteralPath $ChromeExecutable -ErrorAction Stop).Path
    $chromeVersion = [Diagnostics.FileVersionInfo]::GetVersionInfo($resolvedChrome).ProductVersion
    $chromeMajor = [regex]::Match($chromeVersion, '\d+').Value
    Write-Host "Chrome $chromeVersion"
    if ($driverMajor -and $chromeMajor -and $driverMajor -ne $chromeMajor) {
        throw "ChromeDriver major $driverMajor does not match Chrome major $chromeMajor."
    }
    $env:CHROME_EXECUTABLE = $resolvedChrome
}
try {
    $driverProcess = Start-Process -FilePath $driver -ArgumentList "--port=$DriverPort" -PassThru -WindowStyle Hidden
    $ready = $false
    for ($attempt = 0; $attempt -lt 30 -and -not $ready; $attempt++) {
        Start-Sleep -Milliseconds 100
        $socket = [Net.Sockets.TcpClient]::new()
        try { $socket.Connect('127.0.0.1', $DriverPort); $ready = $true }
        catch [Net.Sockets.SocketException] { }
        finally { $socket.Dispose() }
    }
    if (-not $ready) { throw "ChromeDriver did not listen on port $DriverPort." }

    $arguments = @(
        'drive', '--driver=test_driver/integration_test.dart',
        '--target=integration_test/poc_531_calculator_flow_test.dart',
        '-d', 'web-server', '--browser-name=chrome',
        "--driver-port=$DriverPort", "--web-port=$WebPort"
    )
    $escapedFlutter = $flutter.Replace("'", "''")
    $escapedArguments = $arguments | ForEach-Object {
        "'" + $_.Replace("'", "''") + "'"
    }
    $runnerCommand = "& '$escapedFlutter' " + ($escapedArguments -join ' ') + '; exit $LASTEXITCODE'
    $encodedCommand = [Convert]::ToBase64String(
        [Text.Encoding]::Unicode.GetBytes($runnerCommand)
    )
    $runnerInfo = [Diagnostics.ProcessStartInfo]::new()
    $runnerInfo.FileName = 'powershell.exe'
    $runnerInfo.Arguments = "-NoProfile -NonInteractive -EncodedCommand $encodedCommand"
    $runnerInfo.WorkingDirectory = $repositoryRoot
    $runnerInfo.UseShellExecute = $false
    $flutterProcess = [Diagnostics.Process]::new()
    $flutterProcess.StartInfo = $runnerInfo
    if (-not $flutterProcess.Start()) {
        throw 'Chrome E2E process could not be started.'
    }
    if (-not $flutterProcess.WaitForExit($TimeoutSeconds * 1000)) {
        Stop-ProcessTree $flutterProcess
        throw "Chrome E2E exceeded the $TimeoutSeconds-second timeout."
    }
    $flutterProcess.WaitForExit()
    $flutterProcess.Refresh()
    $flutterExitCode = $flutterProcess.ExitCode
    if ($null -eq $flutterExitCode) {
        throw 'Chrome E2E process ended without an observable exit code.'
    }
    if ($flutterExitCode -ne 0) {
        throw "Chrome E2E failed with exit code $flutterExitCode."
    }
}
finally {
    Stop-ProcessTree $flutterProcess
    Stop-ProcessTree $driverProcess
    if ($ChromeExecutable) {
        if ($null -eq $previousChromeExecutable) {
            Remove-Item Env:CHROME_EXECUTABLE -ErrorAction SilentlyContinue
        } else {
            $env:CHROME_EXECUTABLE = $previousChromeExecutable
        }
    }
}
