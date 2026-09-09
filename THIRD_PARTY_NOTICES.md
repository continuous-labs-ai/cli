# Third-party notices

The MIT license covers this project's code. Dependencies retain their own licenses and copyright notices.

Release archives include `THIRD_PARTY_NOTICES/`. This directory contains unmodified dependency notices for each supported operating system and architecture.

The directory also includes the Go license and patent grant. The release includes the same directory in `third-party-notices.tar.gz`.

The packaging script uses `google/go-licenses/v2` at version `v2.0.1`. It reads the dependencies selected by the committed Go module files.

## Manual notice exception

The [go-localereader v0.0.1 README](https://github.com/mattn/go-localereader/blob/6338b4c69507fb1f9edba3db33882a8e9ab9bfa8/README.md) declares MIT and names its author. That version does not include a license file.

Packaging preserves that README verbatim alongside the standard MIT terms. This does not claim that upstream supplied a separate license file.

The exception applies only to `github.com/mattn/go-localereader` at `v0.0.1`. Packaging fails if the module version changes.

Review the upstream license before updating this exception. Do not add unreviewed dependencies to the classifier exclusions.

## Initial release

The `v0.1.0` archives predate notice packaging. Keep their separately supplied license and notice assets with those binaries.
