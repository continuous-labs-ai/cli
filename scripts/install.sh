#!/usr/bin/env bash
#
# continuous CLI Installation Script
# This script downloads and installs the latest version of the continuous CLI
# for Linux and macOS systems.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/continuous-labs-ai/cli/main/scripts/install.sh | bash
#   or
#   wget -qO- https://raw.githubusercontent.com/continuous-labs-ai/cli/main/scripts/install.sh | bash
#
# Options:
#   CONTINUOUS_INSTALL_DIR - Installation directory (default: /usr/local/bin)
#   CONTINUOUS_VERSION     - Specific version to install (default: latest)
#

set -eo pipefail

# Configuration
REPO="continuous-labs-ai/cli"
DEFAULT_INSTALL_DIR="/usr/local/bin"
USER_INSTALL_DIR="$HOME/.local/bin"
VERSION="${CONTINUOUS_VERSION:-latest}"
BINARY_NAME="continuous"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Helper functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

download_file() {
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL "$1" -o "$2"
    elif command -v wget >/dev/null 2>&1; then
        wget -q "$1" -O "$2"
    else
        log_error "curl or wget is required"
        return 1
    fi
}

verify_file() {
    local manifest="$1" filename="$2" file="$3" expected actual
    expected=$(awk -v name="$filename" '
        NF != 2 || length($1) != 64 || $1 ~ /[^0-9a-fA-F]/ || $2 ~ /[^a-zA-Z0-9_.-]/ { bad=1 }
        $2 == name { count++; digest=tolower($1) }
        END { if (bad || count != 1) exit 1; print digest }
    ' "$manifest") || { log_error "Invalid checksum entry for $filename"; return 1; }
    if command -v sha256sum >/dev/null 2>&1; then
        actual=$(sha256sum "$file")
    elif command -v shasum >/dev/null 2>&1; then
        actual=$(shasum -a 256 "$file")
    else
        log_error "sha256sum or shasum is required"
        return 1
    fi
    if [ "${actual%% *}" != "$expected" ]; then
        log_error "Checksum mismatch for $filename"
        return 1
    fi
}

# Detect operating system
detect_os() {
    local os
    local uname_output="$(uname -s)"
    case "$uname_output" in
        Linux*)     os="Linux" ;;
        Darwin*)    os="Darwin" ;;
        CYGWIN*|MINGW*|MSYS*)    os="Windows" ;;
        *)
            log_error "Unsupported operating system: $uname_output"
            exit 1
            ;;
    esac
    echo "$os"
}

# Detect architecture
detect_arch() {
    local arch
    case "$(uname -m)" in
        x86_64|amd64)   arch="x86_64" ;;
        aarch64|arm64)  arch="arm64" ;;
        *)
            log_error "Unsupported architecture: $(uname -m)"
            exit 1
            ;;
    esac
    echo "$arch"
}

# Get latest version from GitHub
get_latest_version() {
    local latest_url="https://api.github.com/repos/${REPO}/releases/latest"
    local version

    if command -v curl >/dev/null 2>&1; then
        version=$(curl -fsSL "$latest_url" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
    elif command -v wget >/dev/null 2>&1; then
        version=$(wget -qO- "$latest_url" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
    else
        log_error "curl or wget is required to download the CLI"
        exit 1
    fi

    echo "$version"
}

# Determine installation directory
get_install_dir() {
    # If user specified a directory, use it
    if [ -n "${CONTINUOUS_INSTALL_DIR}" ]; then
        echo "${CONTINUOUS_INSTALL_DIR}"
        return
    fi

    # Try to use /usr/local/bin if we have write access
    if [ -w "$DEFAULT_INSTALL_DIR" ] || [ -w "$(dirname "$DEFAULT_INSTALL_DIR")" ]; then
        echo "$DEFAULT_INSTALL_DIR"
        return
    fi

    # Fall back to user directory
    log_info "No write access to $DEFAULT_INSTALL_DIR, using $USER_INSTALL_DIR instead" >&2
    echo "$USER_INSTALL_DIR"
}

# Download and install
install_cli() {
    local INSTALL_DIR=$(get_install_dir)
    local os=$(detect_os)
    local arch=$(detect_arch)

    log_info "Detected OS: $os"
    log_info "Detected Architecture: $arch"
    log_info "Installation directory: $INSTALL_DIR"

    # Get version
    if [ "$VERSION" = "latest" ]; then
        VERSION=$(get_latest_version)
        log_info "Latest version: $VERSION"
    fi
    if [[ ! "$VERSION" =~ ^v[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z]+([.-][0-9A-Za-z]+)*)?$ ]]; then
        log_error "Use a release tag such as v0.1.0"
        exit 1
    fi

    # Construct download URL based on OS
    local archive_name
    local archive_format
    if [ "$os" = "Windows" ]; then
        archive_name="${BINARY_NAME}_${os}_${arch}.zip"
        archive_format="zip"
    else
        archive_name="${BINARY_NAME}_${os}_${arch}.tar.gz"
        archive_format="tar.gz"
    fi

    local download_url="https://github.com/${REPO}/releases/download/${VERSION}/${archive_name}"

    log_info "Downloading from: $download_url"

    # Create temporary directory
    local tmp_dir=$(mktemp -d)
    trap "rm -rf $tmp_dir" EXIT

    # Download archive
    local release_url="https://github.com/${REPO}/releases/download/${VERSION}"
    download_file "$download_url" "$tmp_dir/$archive_name"
    download_file "$release_url/checksums.txt" "$tmp_dir/checksums.txt"
    verify_file "$tmp_dir/checksums.txt" "$archive_name" "$tmp_dir/$archive_name"

    log_info "Download complete"

    # Extract archive based on format
    log_info "Extracting archive..."
    if [ "$archive_format" = "zip" ]; then
        if command -v unzip >/dev/null 2>&1; then
            unzip -q "$tmp_dir/$archive_name" -d "$tmp_dir"
        else
            log_error "unzip is required to extract the archive. Please install unzip and try again."
            exit 1
        fi
    else
        tar -xzf "$tmp_dir/$archive_name" -C "$tmp_dir"
    fi

    # Create install directory if it doesn't exist
    if [ ! -d "$INSTALL_DIR" ]; then
        log_info "Creating installation directory: $INSTALL_DIR"
        mkdir -p "$INSTALL_DIR" || {
            log_error "Failed to create $INSTALL_DIR. Try running with sudo or set CONTINUOUS_INSTALL_DIR to a writable location."
            exit 1
        }
    fi

    # Install binary (Windows binaries have .exe extension)
    local source_binary="$tmp_dir/$BINARY_NAME"
    local target_binary="$INSTALL_DIR/$BINARY_NAME"

    if [ "$os" = "Windows" ]; then
        source_binary="$tmp_dir/${BINARY_NAME}.exe"
        target_binary="$INSTALL_DIR/${BINARY_NAME}.exe"
    fi

    log_info "Installing to $target_binary..."
    if ! mv "$source_binary" "$target_binary"; then
        log_error "Failed to install to $INSTALL_DIR. Try running with sudo or set CONTINUOUS_INSTALL_DIR to a writable location."
        exit 1
    fi

    # Make executable (not needed on Windows, but doesn't hurt)
    chmod +x "$target_binary" 2>/dev/null || true

    log_info "continuous ${VERSION} has been installed to $target_binary"

    # Verify installation
    local cmd_to_check="$BINARY_NAME"
    if [ "$os" = "Windows" ]; then
        cmd_to_check="${BINARY_NAME}.exe"
    fi

    if command -v "$cmd_to_check" >/dev/null 2>&1; then
        log_info "Installation successful! Run '$BINARY_NAME --help' to get started."
    else
        log_warn "Installation complete, but $BINARY_NAME is not in your PATH."
        if [ "$os" = "Windows" ]; then
            log_warn "Add $INSTALL_DIR to your PATH environment variable."
        else
            log_warn "Add $INSTALL_DIR to your PATH by adding this to your ~/.bashrc or ~/.zshrc:"
            log_warn "  export PATH=\"\$PATH:$INSTALL_DIR\""
            log_warn ""
            log_warn "Then run: source ~/.bashrc  # or source ~/.zshrc"
        fi
    fi
}

# Main execution
main() {
    log_info "Installing continuous CLI..."
    install_cli
}

main
