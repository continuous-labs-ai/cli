#!/usr/bin/env bash
set -euo pipefail

observation_dir="$RUNNER_TEMP/installer observation"
mkdir -p "$observation_dir/published" "$observation_dir/tmp with spaces"
export OBS_ROOT="$observation_dir"
export CONTINUOUS_INSTALL_DIR="$observation_dir/live install"
export CONTINUOUS_VERSION=v0.1.0
for file in continuous_Linux_x86_64.tar.gz checksums.txt LICENSE third-party-notices.tar.gz legal-assets.sha256; do
  curl -fsSL "https://github.com/continuous-labs-ai/cli/releases/download/v0.1.0/$file" -o "$observation_dir/published/$file"
done
for attempt in 1 2; do
  TMPDIR="$observation_dir/tmp with spaces" bash scripts/install.sh
  "$CONTINUOUS_INSTALL_DIR/continuous" version
  cmp "$CONTINUOUS_INSTALL_DIR/continuous-notices/v0.1.0/LICENSE" "$observation_dir/published/LICENSE"
  test -f "$CONTINUOUS_INSTALL_DIR/continuous-notices/v0.1.0/THIRD_PARTY_NOTICES/go/LICENSE"
  test -f "$CONTINUOUS_INSTALL_DIR/continuous-notices/v0.1.0/THIRD_PARTY_NOTICES/go/PATENTS"
  test -z "$(find "$observation_dir/tmp with spaces" -mindepth 1 -print -quit)"
  echo "PASS live v0.1.0 installation $attempt with retained notices"
done

curl() {
  local url="$2" output="$4" file="${2##*/}" fixture="$OBS_ROOT/published"
  case "$url" in
    https://github.com/continuous-labs-ai/cli/releases/download/v0.1.0/*|https://github.com/continuous-labs-ai/cli/releases/download/v0.1.1/*) ;;
    *) echo "Unexpected URL: $url" >&2; return 22 ;;
  esac
  if [[ "$OBS_CASE" = new ]]; then fixture="$RUNNER_TEMP/new-fixtures/dist"; fi
  if [[ "$OBS_CASE:$file" = archive-download:continuous_Linux_x86_64.tar.gz ||
        "$OBS_CASE:$file" = manifest-download:checksums.txt ||
        "$OBS_CASE:$file" = legal-manifest-download:legal-assets.sha256 ||
        "$OBS_CASE:$file" = supplement-download:third-party-notices.tar.gz ]]; then return 22; fi
  cp "$fixture/$file" "$output"
  if [[ "$file" = checksums.txt ]]; then
    case "$OBS_CASE" in
      empty) : > "$output" ;;
      missing) sed '/continuous_Linux_x86_64.tar.gz$/d' "$fixture/$file" > "$output" ;;
      malformed) printf 'bad  continuous_Linux_x86_64.tar.gz\n' > "$output" ;;
      duplicate) cat "$fixture/$file" "$fixture/$file" > "$output" ;;
      mismatch) awk '$2 == "continuous_Linux_x86_64.tar.gz" {$1="0000000000000000000000000000000000000000000000000000000000000000"} {print}' "$fixture/$file" > "$output" ;;
    esac
  elif [[ "$file" = legal-assets.sha256 && "$OBS_CASE" = legal-mismatch ]]; then
    awk '$2 == "LICENSE" {$1="0000000000000000000000000000000000000000000000000000000000000000"} {print}' "$fixture/$file" > "$output"
  fi
}
tar() {
  touch "$OBS_ROOT/extracted"
  command tar "$@"
}
export -f curl tar
export CONTINUOUS_INSTALL_DIR="$observation_dir/previous install"
mkdir -p "$CONTINUOUS_INSTALL_DIR/continuous-notices"
printf 'existing binary\n' > "$CONTINUOUS_INSTALL_DIR/continuous"
printf 'existing notices\n' > "$CONTINUOUS_INSTALL_DIR/continuous-notices/sentinel"
mkdir "$observation_dir/no-hash-tools"
for tool in awk cp mktemp rm uname; do
  ln -s "$(command -v "$tool")" "$observation_dir/no-hash-tools/$tool"
done
for OBS_CASE in empty missing malformed duplicate mismatch archive-download manifest-download legal-manifest-download supplement-download legal-mismatch invalid-tag no-hash-tool; do
  export OBS_CASE
  export CONTINUOUS_VERSION=v0.1.0
  if [[ "$OBS_CASE" = invalid-tag ]]; then export CONTINUOUS_VERSION='v0.1.0/../../other'; fi
  case_path="$PATH"
  if [[ "$OBS_CASE" = no-hash-tool ]]; then case_path="$observation_dir/no-hash-tools"; fi
  set +e
  PATH="$case_path" TMPDIR="$observation_dir/tmp with spaces" /bin/bash scripts/install.sh
  result=$?
  set -e
  test "$result" -ne 0
  test "$(cat "$CONTINUOUS_INSTALL_DIR/continuous")" = 'existing binary'
  test "$(cat "$CONTINUOUS_INSTALL_DIR/continuous-notices/sentinel")" = 'existing notices'
  test ! -e "$OBS_ROOT/extracted"
  test -z "$(find "$observation_dir/tmp with spaces" -mindepth 1 -print -quit)"
  echo "PASS $OBS_CASE: failed before extraction and preserved prior installation"
done
export OBS_CASE=new CONTINUOUS_VERSION=v0.1.1
export CONTINUOUS_INSTALL_DIR="$observation_dir/new install"
for attempt in 1 2; do
  TMPDIR="$observation_dir/tmp with spaces" bash scripts/install.sh
  "$CONTINUOUS_INSTALL_DIR/continuous" version
  test -f "$CONTINUOUS_INSTALL_DIR/continuous-notices/v0.1.1/LICENSE"
  test -f "$CONTINUOUS_INSTALL_DIR/continuous-notices/v0.1.1/THIRD_PARTY_NOTICES.md"
  test -f "$CONTINUOUS_INSTALL_DIR/continuous-notices/v0.1.1/THIRD_PARTY_NOTICES/go/LICENSE"
  test -f "$CONTINUOUS_INSTALL_DIR/continuous-notices/v0.1.1/THIRD_PARTY_NOTICES/go/PATENTS"
  echo "PASS new archive installation $attempt with notice index and Go notices"
done
