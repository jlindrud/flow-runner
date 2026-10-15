param([Parameter(Mandatory=$true)][string]$Version)
$ErrorActionPreference = 'Stop'
if ($Version -notmatch '^\d+\.\d+\.\d+\.\d+$') { throw 'An exact four-part version is required' }
if ([System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture -ne 'X64' -or $env:OS -ne 'Windows_NT') {
    throw 'Supported target: Windows x64'
}
$repository = if ($env:FLOW_RUNNER_REPOSITORY) { $env:FLOW_RUNNER_REPOSITORY } else { 'jlindrud/flow-runner' }
if ($repository -notmatch '^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$') { throw 'Invalid release repository' }
$cache = if ($env:FLOW_RUNNER_CACHE) { $env:FLOW_RUNNER_CACHE } else { Join-Path $env:LOCALAPPDATA 'FlowRunner' }
$cache = [IO.Path]::GetFullPath((Join-Path $cache $repository))
$target = Join-Path $cache "$Version-windows-x64"
if (-not (Test-Path -LiteralPath (Join-Path $target '.complete'))) {
    if (Test-Path -LiteralPath $target) { throw "Incomplete install at $target; choose another FLOW_RUNNER_CACHE" }
    $stage = Join-Path $cache ('.flow-install-' + [Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $stage -Force | Out-Null
    try {
        $asset = "FlowRunner-$Version-windows-x64.zip"
        $archive = Join-Path $stage $asset
        $url = "https://github.com/$repository/releases/download/v$Version/$asset"
        Invoke-WebRequest -Uri $url -OutFile $archive -UseBasicParsing
        $checksum = (Invoke-WebRequest -Uri "$url.sha256" -UseBasicParsing).Content
        if ($checksum -is [byte[]]) { $checksum = [Text.Encoding]::UTF8.GetString($checksum) }
        $expected = ($checksum.Trim() -split '\s+')[0]
        if ($expected -notmatch '^[a-fA-F0-9]{64}$' -or (Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash -ne $expected) {
            throw 'Runner SHA256 verification failed'
        }
        $package = Join-Path $stage 'package'
        Expand-Archive -LiteralPath $archive -DestinationPath $package
        $runner = Join-Path $package 'bin/FlowRunner.exe'
        if ((& $runner --version) -ne "FlowRunner $Version" -or $LASTEXITCODE -ne 0) { throw 'Runner version verification failed' }
        & (Join-Path $package 'bin/python-runtime/python.exe') -I -c 'import json, ssl'
        if ($LASTEXITCODE -ne 0) { throw 'Bundled Python validation failed' }
        Set-Content -LiteralPath (Join-Path $package '.complete') -Value $Version
        Move-Item -LiteralPath $package -Destination $target
    } finally {
        # Only remove the freshly-created staging directory inside this cache.
        if ([IO.Path]::GetFullPath($stage).StartsWith($cache + [IO.Path]::DirectorySeparatorChar) -and
            [IO.Path]::GetFileName($stage).StartsWith('.flow-install-') -and (Test-Path -LiteralPath $stage)) {
            Remove-Item -LiteralPath $stage -Recurse -Force
        }
    }
}
$runner = Join-Path $target 'bin/FlowRunner.exe'
if ((& $runner --version) -ne "FlowRunner $Version" -or $LASTEXITCODE -ne 0) { throw 'Cached runner version verification failed' }
if ($env:GITHUB_PATH) { Add-Content -LiteralPath $env:GITHUB_PATH -Value (Join-Path $target 'bin') -Encoding utf8 }
if ($env:GITHUB_ENV) {
    Add-Content -LiteralPath $env:GITHUB_ENV -Value "FLOW_RUNNER_HOME=$target" -Encoding utf8
    Add-Content -LiteralPath $env:GITHUB_ENV -Value "FLOW_RUNNER_PYTHON=$(Join-Path $target 'bin/python-runtime/python.exe')" -Encoding utf8
}
Write-Output $runner
