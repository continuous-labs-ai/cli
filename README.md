# Continuous CLI

Use `continuous` to call the public Continuous Simulation API. This repository and its releases require authorized GitHub access.

Speakeasy generates the command implementation. The repository owns generation settings, checks, release configuration, and this guide.

This setup remains in draft. Behavior tests expose generator defects, so no installable release is available yet.

## Install an approved release

Authenticate GitHub CLI with access to `continuous-labs-ai/cli`.

Download the Linux amd64 archive and its checksums:

```bash
gh release download v0.0.1 --repo continuous-labs-ai/cli \
  --pattern continuous_Linux_x86_64.tar.gz --pattern checksums.txt
sha256sum --ignore-missing --check checksums.txt
tar -xzf continuous_Linux_x86_64.tar.gz continuous
./continuous version
mkdir -p "$HOME/.local/bin"
install -m 755 continuous "$HOME/.local/bin/continuous"
export PATH="$HOME/.local/bin:$PATH"
```

Replace the version with an approved release. Select `Darwin` for macOS or `Windows` for Windows.

Add `$HOME/.local/bin` to your shell profile to keep the command available in new terminals.

Select `arm64` for ARM systems. Windows archives use `.zip` and contain `continuous.exe`.

Verify SHA-256 checksums before extraction. Checksum files are not signed.

Do not use unauthenticated download scripts for this private repository.

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

No license grant is specified in this repository.
