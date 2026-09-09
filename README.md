# Continuous CLI

Use `continuous` to call the public Continuous Simulation API.

Speakeasy generates the command implementation, the installers, and the release configuration. The repository owns generation settings, build checks, and this guide.

Build checks cover generation, compilation, and packaging. This repository does not contain a CLI test suite.

## Install

Releases are published on the [release page](https://github.com/continuous-labs-ai/cli/releases) when a version tag is pushed. Downloads do not need GitHub credentials.

Each release ships archives for Linux, macOS, and Windows on amd64 and arm64, plus `checksums.txt`. Releases published by the generated workflow also ship `checksums.txt.sig`, a detached signature made with the project's GPG key. Releases `v0.1.0` and `v0.1.1` predate signing.

### Homebrew

```bash
brew install continuous-labs-ai/tap/continuous
continuous version
```

Run `brew upgrade continuous-labs-ai/tap/continuous` to install a later version. GoReleaser pushes the formula to the tap on each release, and Homebrew checks the archive hash recorded in the formula.

### Linux and macOS

Run these commands in Bash. Replace `v0.1.1` with the version you want.

```bash
set -euo pipefail
version=v0.1.1
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

The checksum proves that the archive matches the manifest. For releases that ship `checksums.txt.sig`, import the project's public signing key and verify the manifest before you check the archive:

```bash
curl -fL "$release_url/checksums.txt.sig" -o checksums.txt.sig
gpg --verify checksums.txt.sig checksums.txt
```

### Windows

Select `x86_64` for amd64 or `arm64` for ARM64. Run these commands in PowerShell with a published version.

```powershell
$ErrorActionPreference = "Stop"
$version = "v0.1.1"
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

### Generated installers

Speakeasy generates installers for Linux, macOS, and Windows. They verify the archive against `checksums.txt` before extraction and reject missing, malformed, duplicate, or mismatched checksum entries. They do not check the signature.

For Linux or macOS, download the script:

```bash
curl -fL https://raw.githubusercontent.com/continuous-labs-ai/cli/main/scripts/install.sh -o install.sh
```

Inspect `install.sh`. Then install the latest release in your user directory:

```bash
CONTINUOUS_INSTALL_DIR="$HOME/.local/bin" bash install.sh
export PATH="$HOME/.local/bin:$PATH"
continuous version
```

For Windows, download the script in PowerShell:

```powershell
Invoke-WebRequest https://raw.githubusercontent.com/continuous-labs-ai/cli/main/scripts/install.ps1 -OutFile install.ps1
```

Inspect `install.ps1`. Then run it:

```powershell
& .\install.ps1
continuous version
```

The Windows installer can update your user `PATH`. Restart your terminal if the command is not available.

Set `CONTINUOUS_VERSION` to install a specific release and `CONTINUOUS_INSTALL_DIR` to choose another installation directory.

## Use the API

### Interactive authentication

Run these commands in a terminal:

```bash
continuous auth login
continuous auth whoami
```

Enter your API key at the prompt. This command stores credentials locally. It does not open a browser login.

The CLI uses the OS keychain when available. It falls back to its configuration file if keychain storage fails.

The `whoami` command shows masked credential settings and their sources. It does not check your key with the API.

Verify API access with a read-only request:

```bash
continuous simulators list --output-format json
```

Run `continuous auth logout` to remove stored credentials. Environment variables can still supply credentials after logout.

### Automation

Supply your API key through the `CONTINUOUS_API_KEY_AUTH` environment variable. Use your automation system's secret store.

The CLI adds the `Bearer` prefix. It also accepts a key that already includes that prefix.

Keep API keys out of commands, logs, and source files. Disable prompts and select JSON output in scripts:

```bash
continuous simulations list --no-interactive --output-format json
continuous simulators list --no-interactive --output-format json
continuous worlds list --no-interactive --output-format json
```

Use `--server-url` to select another API endpoint. Run `continuous --help` to inspect commands.

### Shell completion

Inspect the generated instructions for your shell:

```bash
continuous completion --help
```

## Maintain the CLI

Read [CONTRIBUTING.md](CONTRIBUTING.md) for generation, checks, and releases.

The project uses the [MIT license](LICENSE). Dependencies keep their own licenses.
