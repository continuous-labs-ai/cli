#!/usr/bin/env bash
set -euo pipefail

if [[ -e THIRD_PARTY_NOTICES || -e third-party-notices.tar.gz ]]; then
  echo "Build notices in a clean checkout." >&2
  exit 1
fi

notice_tmp=$(mktemp -d)
locale_module=github.com/mattn/go-localereader
if [[ $(go list -m -f '{{.Version}}' "$locale_module") != v0.0.1 ]]; then
  echo "Review the go-localereader license exception before changing its version." >&2
  exit 1
fi
GOBIN="$notice_tmp/bin" go install github.com/google/go-licenses/v2@v2.0.1
for target in linux/amd64 linux/arm64 darwin/amd64 darwin/arm64 windows/amd64 windows/arm64; do
  GOOS="${target%/*}" GOARCH="${target#*/}" CGO_ENABLED=0 \
    "$notice_tmp/bin/go-licenses" save ./cmd/continuous \
      --save_path="$notice_tmp/notices/$target" \
      --ignore="github.com/continuous-labs-ai/cli,$locale_module"
done
mkdir -p "$notice_tmp/notices/$locale_module"
cp "$(go list -m -f '{{.Dir}}' "$locale_module")/README.md" "$notice_tmp/notices/$locale_module/"
cp third-party/go-localereader-v0.0.1/MIT.txt "$notice_tmp/notices/$locale_module/"
mkdir -p "$notice_tmp/notices/go"
cp "$(go env GOROOT)/LICENSE" "$(go env GOROOT)/PATENTS" "$notice_tmp/notices/go/"
cp -R "$notice_tmp/notices" THIRD_PARTY_NOTICES
tar -czf third-party-notices.tar.gz THIRD_PARTY_NOTICES
sha256sum LICENSE third-party-notices.tar.gz > legal-assets.sha256
