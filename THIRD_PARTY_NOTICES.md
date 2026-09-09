# Third-party notices

The MIT license covers this project's code. Dependencies retain their own licenses and copyright notices.

Release archives include `THIRD_PARTY_NOTICES/`. This directory contains unmodified dependency notices for each supported operating system and architecture.

The directory also includes the Go license and patent grant. The release includes the same directory in `third-party-notices.tar.gz`.

The packaging script uses `google/go-licenses/v2` at version `v2.0.1`. It reads the dependencies selected by the committed Go module files.

The `v0.1.0` archives predate notice packaging. Keep their separately supplied license and notice assets with those binaries.
