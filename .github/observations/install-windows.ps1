param([string]$Case)
$ErrorActionPreference = 'Stop'
if ($Case) {
    $env:OBS_CASE = $Case
    function global:Invoke-WebRequest {
        param([string]$Uri, [string]$OutFile, [switch]$UseBasicParsing)
        if ($env:OBS_CASE -eq 'live') {
            Microsoft.PowerShell.Utility\Invoke-WebRequest @PSBoundParameters
            return
        }
        if ($Uri -cnotmatch '\Ahttps://github.com/continuous-labs-ai/cli/releases/download/v0\.1\.[01]/[a-zA-Z0-9_.-]+\z') {
            throw "Unexpected URL: $Uri"
        }
        $file = ($Uri -split '/')[-1]
        $fixture = Join-Path $env:OBS_ROOT 'published'
        if ($env:OBS_CASE -eq 'new') { $fixture = Join-Path $env:RUNNER_TEMP 'new-fixtures/dist' }
        if ("$env:OBS_CASE`:$file" -in @('archive-download:continuous_Windows_x86_64.zip', 'manifest-download:checksums.txt', 'legal-manifest-download:legal-assets.sha256', 'supplement-download:third-party-notices.tar.gz')) {
            throw 'Injected download failure.'
        }
        Copy-Item -LiteralPath (Join-Path $fixture $file) -Destination $OutFile
        if ($file -eq 'checksums.txt') {
            $lines = @(Get-Content -LiteralPath $OutFile)
            switch ($env:OBS_CASE) {
                'empty' { Set-Content -LiteralPath $OutFile -Value '' -NoNewline }
                'missing' { $lines | Where-Object { $_ -notmatch 'continuous_Windows_x86_64.zip$' } | Set-Content -LiteralPath $OutFile }
                'malformed' { Set-Content -LiteralPath $OutFile -Value 'bad  continuous_Windows_x86_64.zip' }
                'duplicate' { ($lines + $lines) | Set-Content -LiteralPath $OutFile }
                'mismatch' { $lines | ForEach-Object { if ($_ -match 'continuous_Windows_x86_64.zip$') { ('0' * 64) + '  continuous_Windows_x86_64.zip' } else { $_ } } | Set-Content -LiteralPath $OutFile }
            }
        } elseif ($file -eq 'legal-assets.sha256' -and $env:OBS_CASE -eq 'legal-mismatch') {
            Get-Content -LiteralPath (Join-Path $fixture $file) | ForEach-Object { if ($_ -match '  LICENSE$') { ('0' * 64) + '  LICENSE' } else { $_ } } | Set-Content -LiteralPath $OutFile
        }
    }
    function global:Expand-Archive {
        param([string]$LiteralPath, [string]$DestinationPath)
        Set-Content -LiteralPath (Join-Path $env:OBS_ROOT 'extracted') -Value 'yes'
        Microsoft.PowerShell.Archive\Expand-Archive @PSBoundParameters
    }
    & ./scripts/install.ps1
    exit $LASTEXITCODE
}

$env:OBS_ROOT = Join-Path $env:RUNNER_TEMP 'installer observation'
New-Item -ItemType Directory -Path (Join-Path $env:OBS_ROOT 'published') -Force | Out-Null
foreach ($file in @('continuous_Windows_x86_64.zip', 'checksums.txt', 'LICENSE', 'third-party-notices.tar.gz', 'legal-assets.sha256')) {
    Invoke-WebRequest "https://github.com/continuous-labs-ai/cli/releases/download/v0.1.0/$file" -OutFile (Join-Path $env:OBS_ROOT "published/$file")
}
$pwsh = (Get-Process -Id $PID).Path
$env:CONTINUOUS_INSTALL_DIR = Join-Path $env:OBS_ROOT 'live install'
$env:CONTINUOUS_VERSION = 'v0.1.0'
foreach ($attempt in 1, 2) {
    & $pwsh -NoProfile -File $PSCommandPath -Case live
    if ($LASTEXITCODE -ne 0) { throw 'Live installation failed.' }
    & (Join-Path $env:CONTINUOUS_INSTALL_DIR 'continuous.exe') version
    $noticeDir = Join-Path $env:CONTINUOUS_INSTALL_DIR 'continuous-notices/v0.1.0'
    if ((Get-FileHash (Join-Path $noticeDir 'LICENSE')).Hash -ne (Get-FileHash (Join-Path $env:OBS_ROOT 'published/LICENSE')).Hash) { throw 'Retained license mismatch.' }
    foreach ($file in @('THIRD_PARTY_NOTICES/go/LICENSE', 'THIRD_PARTY_NOTICES/go/PATENTS')) {
        if (-not (Test-Path -LiteralPath (Join-Path $noticeDir $file) -PathType Leaf)) { throw "Missing $file" }
    }
    Write-Output "PASS live v0.1.0 installation $attempt with retained notices"
}
Remove-Item -LiteralPath (Join-Path $env:OBS_ROOT 'extracted')
$env:CONTINUOUS_INSTALL_DIR = Join-Path $env:OBS_ROOT 'previous install'
New-Item -ItemType Directory -Path (Join-Path $env:CONTINUOUS_INSTALL_DIR 'continuous-notices') -Force | Out-Null
Set-Content -LiteralPath (Join-Path $env:CONTINUOUS_INSTALL_DIR 'continuous.exe') -Value 'existing binary'
Set-Content -LiteralPath (Join-Path $env:CONTINUOUS_INSTALL_DIR 'continuous-notices/sentinel') -Value 'existing notices'
foreach ($caseName in @('empty', 'missing', 'malformed', 'duplicate', 'mismatch', 'archive-download', 'manifest-download', 'legal-manifest-download', 'supplement-download', 'legal-mismatch', 'invalid-tag')) {
    $env:CONTINUOUS_VERSION = 'v0.1.0'
    if ($caseName -eq 'invalid-tag') { $env:CONTINUOUS_VERSION = 'v0.1.0/../../other' }
    & $pwsh -NoProfile -File $PSCommandPath -Case $caseName
    if ($LASTEXITCODE -eq 0) { throw "Expected failure: $caseName" }
    if ((Get-Content -Raw (Join-Path $env:CONTINUOUS_INSTALL_DIR 'continuous.exe')).Trim() -ne 'existing binary') { throw 'Existing binary changed.' }
    if ((Get-Content -Raw (Join-Path $env:CONTINUOUS_INSTALL_DIR 'continuous-notices/sentinel')).Trim() -ne 'existing notices') { throw 'Existing notices changed.' }
    if (Test-Path -LiteralPath (Join-Path $env:OBS_ROOT 'extracted')) { throw 'Extraction occurred before failed verification.' }
    Write-Output "PASS ${caseName}: failed before extraction and preserved prior installation"
}
$env:CONTINUOUS_VERSION = 'v0.1.1'
$env:CONTINUOUS_INSTALL_DIR = Join-Path $env:OBS_ROOT 'new install'
foreach ($attempt in 1, 2) {
    & $pwsh -NoProfile -File $PSCommandPath -Case new
    if ($LASTEXITCODE -ne 0) { throw 'New archive installation failed.' }
    & (Join-Path $env:CONTINUOUS_INSTALL_DIR 'continuous.exe') version
    foreach ($file in @('LICENSE', 'THIRD_PARTY_NOTICES.md', 'THIRD_PARTY_NOTICES/go/LICENSE', 'THIRD_PARTY_NOTICES/go/PATENTS')) {
        if (-not (Test-Path -LiteralPath (Join-Path $env:CONTINUOUS_INSTALL_DIR "continuous-notices/v0.1.1/$file") -PathType Leaf)) { throw "Missing $file" }
    }
    Write-Output "PASS new archive installation $attempt with notice index and Go notices"
}
