# Continuous CLI

Use `continuous` to call the public Continuous Simulation API.

Speakeasy generates the command implementation. The repository owns generation settings, build checks, release configuration, and this guide.

Build checks cover generation, compilation, and packaging. This repository does not contain a CLI test suite.

## Install an approved release

Use a published release from the [release page](https://github.com/continuous-labs-ai/cli/releases). Published downloads do not need GitHub credentials.

Draft releases are not available through anonymous downloads. Version `v0.1.0` is published.

Use the manual instructions below to verify archive checksums before installation.

### Homebrew

Homebrew distribution starts with the next approved public release. It is not available for `v0.1.0`.

After the first formula reaches the public tap, install it with:

```bash
brew install continuous-labs-ai/tap/continuous
continuous version
```

Run `brew upgrade continuous-labs-ai/tap/continuous` to install a later published version.

The formula verifies archive hashes and retains licenses and notices under `$(brew --prefix continuous)/share/continuous`.

The formula also installs Bash, Zsh, and Fish completions from the generated CLI.

Use the installers below until the tap has a published formula. Windows users must use the Windows installer or archive.

### Linux and macOS

Run these commands in Bash. Replace `v0.1.0` with the approved, published version.

```bash
set -euo pipefail
version=v0.1.0
case "$(uname -s)" in
  Linux) platform=Linux ;;
  Darwin) platform=Darwin ;;
  *) echo "Use the Windows instructions for Windows." >&2; exit 1 ;;
esac
case "$(uname -m)" in
  x86_64) architecture=x86_64 ;;
  arm64|aarch64) architecture=arm64 ;;
  *) echo "Unsupported architecture." >&2; exit 1 ;;
esac
archive="continuous_${platform}_${architecture}.tar.gz"
release_url="https://github.com/continuous-labs-ai/cli/releases/download/$version"
download_dir=$(mktemp -d)
cd "$download_dir"
curl -fL "$release_url/$archive" -o "$archive"
curl -fL "$release_url/checksums.txt" -o checksums.txt
awk -v archive="$archive" '$2 == archive { print; count++ } END { if (count != 1) exit 1 }' checksums.txt > selected.sha256
if [ "$platform" = Darwin ]; then
  shasum -a 256 -c selected.sha256
else
  sha256sum --check selected.sha256
fi
tar -xzf "$archive"
mkdir -p "$HOME/.local/bin"
install -m 755 continuous "$HOME/.local/bin/continuous"
export PATH="$HOME/.local/bin:$PATH"
continuous version
```

Add `$HOME/.local/bin` to your shell profile to keep the command available in new terminals.

Keep the extracted license and notices with the binary. Checksums verify file integrity but are not signed.

### Windows

Select `x86_64` for amd64 or `arm64` for ARM64. Run these commands in PowerShell with a published version.

```powershell
$ErrorActionPreference = "Stop"
$version = "v0.1.0"
$architecture = "x86_64"
$archive = "continuous_Windows_$architecture.zip"
$releaseUrl = "https://github.com/continuous-labs-ai/cli/releases/download/$version"
$downloadDir = New-Item -ItemType Directory -Path (Join-Path ([IO.Path]::GetTempPath()) ([guid]::NewGuid()))
Set-Location $downloadDir
curl.exe -fL "$releaseUrl/$archive" -o $archive
if ($LASTEXITCODE -ne 0) { throw "Archive download failed." }
curl.exe -fL "$releaseUrl/checksums.txt" -o checksums.txt
if ($LASTEXITCODE -ne 0) { throw "Checksum download failed." }
$entries = @(Get-Content checksums.txt | Where-Object { ($_ -split '\s+', 2)[1] -eq $archive })
if ($entries.Count -ne 1) { throw "Missing or duplicate checksum." }
$expected = ($entries[0] -split '\s+', 2)[0]
if ((Get-FileHash $archive -Algorithm SHA256).Hash -ne $expected) { throw "Checksum mismatch." }
Expand-Archive $archive -DestinationPath continuous
$env:PATH = "$((Resolve-Path continuous).Path);$env:PATH"
continuous version
```

Move the extracted directory to a permanent location. Add that location to your user `PATH`.

### Optional generated installers

Speakeasy generates installers for Linux, macOS, and Windows. Maintained patches verify archive SHA-256 checksums before extraction or installation.

The installers reject missing, malformed, duplicate, or mismatched checksum entries. Download or verification failures leave an existing installation unchanged.

Checksums are unsigned. They detect corruption and mismatched files but do not prove publisher identity.

The installers retain notices in `continuous-notices/<version>` under the installation directory. They also download and verify the separate [v0.1.0 supplements](#initial-v010-notices).

For Linux or macOS, download the script:

```bash
curl -fL https://raw.githubusercontent.com/continuous-labs-ai/cli/main/scripts/install.sh -o install.sh
```

Inspect `install.sh`. Then install the selected version in your user directory:

```bash
CONTINUOUS_VERSION=v0.1.0 CONTINUOUS_INSTALL_DIR="$HOME/.local/bin" bash install.sh
export PATH="$HOME/.local/bin:$PATH"
continuous version
```

For Windows, download the script in PowerShell:

```powershell
Invoke-WebRequest https://raw.githubusercontent.com/continuous-labs-ai/cli/main/scripts/install.ps1 -OutFile install.ps1
```

Inspect `install.ps1`. Then run it:

```powershell
$env:CONTINUOUS_VERSION = "v0.1.0"
$env:CONTINUOUS_INSTALL_DIR = Join-Path $env:LOCALAPPDATA "Programs\continuous"
& .\install.ps1
continuous version
```

The Windows installer can update your user `PATH`. Restart your terminal if the command is not available.

Omit `CONTINUOUS_VERSION` to select the latest published release. Set `CONTINUOUS_INSTALL_DIR` to choose another installation directory.

### Initial v0.1.0 notices

The original `v0.1.0` archives predate license packaging. They are not rebuilt or replaced.

Download `LICENSE`, `third-party-notices.tar.gz`, and `legal-assets.sha256` from the same release before redistributing those binaries.

Verify both supplemental files against `legal-assets.sha256`. Keep them alongside the original archive and `checksums.txt`.

## Use the API

Set `CONTINUOUS_API_KEY_AUTH` to `Bearer <API-key>`. Keep API keys out of commands, logs, and source files.

```bash
continuous simulations list --output-format json
continuous simulators list --output-format json
continuous worlds list --output-format json
```

Use `--server-url` to select another API endpoint. Run `continuous --help` to inspect commands.

## Maintain the CLI

Read [CONTRIBUTING.md](CONTRIBUTING.md) for generation, checks, and release controls.

The project uses the [MIT license](LICENSE). Dependencies retain their [own licenses and notices](THIRD_PARTY_NOTICES.md).
