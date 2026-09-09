#
# continuous CLI Installation Script for Windows
# This script downloads and installs the latest version of the continuous CLI
#
# Usage:
#   iwr -useb https://raw.githubusercontent.com/continuous-labs-ai/cli/main/scripts/install.ps1 | iex
#   or
#   Invoke-WebRequest -Uri https://raw.githubusercontent.com/continuous-labs-ai/cli/main/scripts/install.ps1 -UseBasicParsing | Invoke-Expression
#
# Options:
#   $env:CONTINUOUS_INSTALL_DIR - Installation directory (default: $env:LOCALAPPDATA\Programs\continuous)
#   $env:CONTINUOUS_VERSION     - Specific version to install (default: latest)
#

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

# Configuration
$Repo = "continuous-labs-ai/cli"
$BinaryName = "continuous.exe"
$DefaultInstallDir = Join-Path $env:LOCALAPPDATA "Programs\continuous"
$InstallDir = if ($env:CONTINUOUS_INSTALL_DIR) { $env:CONTINUOUS_INSTALL_DIR } else { $DefaultInstallDir }
$Version = if ($env:CONTINUOUS_VERSION) { $env:CONTINUOUS_VERSION } else { "latest" }

# Helper functions
function Write-ColorOutput {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,
        [string]$Color = "White"
    )
    Write-Host $Message -ForegroundColor $Color
}

function Get-LatestVersion {
    try {
        $response = Invoke-RestMethod -Uri "https://api.github.com/repos/$Repo/releases/latest" -UseBasicParsing
        return $response.tag_name
    }
    catch {
        Write-ColorOutput "Failed to get latest version: $_" -Color Red
        exit 1
    }
}

function Get-Architecture {
    $arch = $env:PROCESSOR_ARCHITECTURE
    switch ($arch) {
        "AMD64" { return "x86_64" }
        "ARM64" { return "arm64" }
        default {
            Write-ColorOutput "Unsupported architecture: $arch" -Color Red
            exit 1
        }
    }
}

function Confirm-Download {
    param([string]$Manifest, [string]$FileName, [string]$FilePath)
    $count = 0
    $expected = $null
    foreach ($line in Get-Content -LiteralPath $Manifest) {
        if ($line -cnotmatch '\A([0-9a-fA-F]{64})[ \t]+([a-zA-Z0-9_.-]+)\z') {
            throw "Malformed checksum manifest."
        }
        if ($Matches[2] -ceq $FileName) {
            $count++
            $expected = $Matches[1]
        }
    }
    if ($count -ne 1) { throw "Missing or duplicate checksum for $FileName." }
    if ((Get-FileHash -LiteralPath $FilePath -Algorithm SHA256).Hash -ne $expected) {
        throw "Checksum mismatch for $FileName."
    }
}

function Install-CLI {
    Write-ColorOutput "Installing continuous CLI..." -Color Green

    # Detect architecture
    $arch = Get-Architecture
    Write-ColorOutput "Detected Architecture: $arch" -Color Cyan

    # Get version
    if ($Version -eq "latest") {
        $Version = Get-LatestVersion
        Write-ColorOutput "Latest version: $Version" -Color Cyan
    }
    if ($Version -cnotmatch '\Av[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z]+([.-][0-9A-Za-z]+)*)?\z') {
        throw "Use a release tag such as v0.1.0."
    }

    # Construct download URL
    $archiveName = "continuous_Windows_$arch.zip"
    $downloadUrl = "https://github.com/$Repo/releases/download/$Version/$archiveName"

    Write-ColorOutput "Downloading from: $downloadUrl" -Color Cyan

    # Create temporary directory
    $tempDir = Join-Path $env:TEMP "continuous-install-$(New-Guid)"
    New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

    try {
        # Download archive
        $archivePath = Join-Path $tempDir $archiveName
        try {
            Invoke-WebRequest -Uri $downloadUrl -OutFile $archivePath -UseBasicParsing
        }
        catch {
            Write-ColorOutput "Failed to download from $downloadUrl" -Color Red
            Write-ColorOutput "Error: $_" -Color Red
            exit 1
        }

        Write-ColorOutput "Download complete" -Color Green
        $releaseUrl = "https://github.com/$Repo/releases/download/$Version"
        $manifest = Join-Path $tempDir "checksums.txt"
        Invoke-WebRequest -Uri "$releaseUrl/checksums.txt" -OutFile $manifest -UseBasicParsing
        Confirm-Download $manifest $archiveName $archivePath
        if ($Version -eq "v0.1.0") {
            $legalManifest = Join-Path $tempDir "legal-assets.sha256"
            Invoke-WebRequest -Uri "$releaseUrl/legal-assets.sha256" -OutFile $legalManifest -UseBasicParsing
            foreach ($fileName in @("LICENSE", "third-party-notices.tar.gz")) {
                $filePath = Join-Path $tempDir $fileName
                Invoke-WebRequest -Uri "$releaseUrl/$fileName" -OutFile $filePath -UseBasicParsing
                Confirm-Download $legalManifest $fileName $filePath
            }
        }

        # Extract archive
        Write-ColorOutput "Extracting archive..." -Color Cyan
        $archiveDir = Join-Path $tempDir "archive"
        Expand-Archive -LiteralPath $archivePath -DestinationPath $archiveDir
        if ($Version -eq "v0.1.0") {
            & tar -xzf (Join-Path $tempDir "third-party-notices.tar.gz") -C $archiveDir
            if ($LASTEXITCODE -ne 0) { throw "Notice extraction failed." }
            Copy-Item -LiteralPath (Join-Path $tempDir "LICENSE") -Destination $archiveDir
        } elseif (-not (Test-Path -LiteralPath (Join-Path $archiveDir "THIRD_PARTY_NOTICES.md") -PathType Leaf)) {
            throw "The archive is missing THIRD_PARTY_NOTICES.md."
        }
        if (-not (Test-Path -LiteralPath (Join-Path $archiveDir "LICENSE") -PathType Leaf) -or
            -not (Test-Path -LiteralPath (Join-Path $archiveDir "THIRD_PARTY_NOTICES") -PathType Container) -or
            -not (Test-Path -LiteralPath (Join-Path $archiveDir $BinaryName) -PathType Leaf)) {
            throw "The archive is missing the binary or license notices."
        }

        # Create install directory if it doesn't exist
        if (-not (Test-Path $InstallDir)) {
            Write-ColorOutput "Creating installation directory: $InstallDir" -Color Cyan
            New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
        }

        # Install binary
        $binaryPath = Join-Path $InstallDir $BinaryName
        Write-ColorOutput "Installing to $binaryPath..." -Color Cyan

        $noticeDir = Join-Path $InstallDir "continuous-notices/$Version"
        New-Item -ItemType Directory -Path $noticeDir -Force | Out-Null
        Copy-Item -LiteralPath (Join-Path $archiveDir "LICENSE") -Destination $noticeDir
        Copy-Item -LiteralPath (Join-Path $archiveDir "THIRD_PARTY_NOTICES") -Destination $noticeDir -Recurse -Force
        $noticeIndex = Join-Path $archiveDir "THIRD_PARTY_NOTICES.md"
        if (Test-Path -LiteralPath $noticeIndex -PathType Leaf) {
            Copy-Item -LiteralPath $noticeIndex -Destination $noticeDir
        }
        Copy-Item -LiteralPath (Join-Path $archiveDir $BinaryName) -Destination $binaryPath -Force

        Write-ColorOutput "continuous $Version has been installed to $binaryPath" -Color Green

        # Add to PATH if not already there
        $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
        if ($userPath -notlike "*$InstallDir*") {
            Write-ColorOutput "Adding $InstallDir to your PATH..." -Color Cyan
            [Environment]::SetEnvironmentVariable(
                "Path",
                "$userPath;$InstallDir",
                "User"
            )
            $env:Path = "$env:Path;$InstallDir"
            Write-ColorOutput "Added to PATH. You may need to restart your terminal for changes to take effect." -Color Yellow
        }

        Write-ColorOutput "Installation successful! Run 'continuous --help' to get started." -Color Green
        Write-ColorOutput "Note: You may need to restart your terminal or run 'refreshenv' for the PATH changes to take effect." -Color Yellow
    }
    finally {
        # Cleanup
        if (Test-Path -LiteralPath $tempDir) {
            Remove-Item -LiteralPath $tempDir -Recurse -Force
        }
    }
}

# Main execution
try {
    Install-CLI
}
catch {
    Write-ColorOutput "Installation failed: $_" -Color Red
    exit 1
}
