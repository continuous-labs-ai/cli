# Maintain the CLI

Generate this CLI from the public Continuous Simulation API. Keep credentials and private API contracts out of this repository.

Change the API contract in `continuous-labs-ai/continuous`. Keep Eval and Internal APIs out of this repository.

Set command names and generator options in `.speakeasy/gen.yaml`. Do not patch generated runtime files.

Review owned settings, workflows, and documentation. Treat generated source as build output, not an exhaustive source review target.

Keep generated output marked with `linguist-generated`. Keep owned files visible during review.

The `.genignore` file protects owned documentation, licenses, release notes, review attributes, and release configuration. Confirm that these files survive regeneration.

Run generation with Speakeasy 1.796.4:

```bash
speakeasy run --target continuous-simulation-cli
```

Run checks in GitHub Actions. The `Checks` workflow verifies generation, compiles the binary, and builds snapshot archives.

CLI test suites are disabled. Keep generated test files excluded through `.genignore` and the generator settings.

## Generation workflow

Store `SPEAKEASY_API_KEY` as a repository secret. Run the `Generate` workflow in `test` mode first.

The `test` mode verifies generation without publishing changes. It does not run a CLI test suite.

Use `pr` mode after generation verification succeeds. This mode requires the `SPEAKEASY_GITHUB_TOKEN` repository secret.

Use a fine-grained token limited to this repository. Grant read and write access to contents and pull requests.

Use the scoped token for unattended generation checks. Pull requests from `GITHUB_TOKEN` can require approval before their checks run.

Do not reuse a broad personal token. Keep generation unavailable until the scoped secret exists.

Never use direct generation mode. Review generated changes before merging them.

## Releases

Release infrastructure is owned, not generated. Keep `cli.generateRelease: true` to generate `scripts/install.sh` and `scripts/install.ps1`.

Keep `.goreleaser.yaml` and `.github/workflows/release.yaml` protected in `.genignore`. This preserves owned release controls during generation.

Do not patch generated installers. The pinned generator does not add checksum verification or retain license notices during installation.

Check installer archive names against published assets after generator changes. Keep manual checksum verification and license supplement guidance in the README.

Push an approved tag that matches `cli.version`, such as `v0.1.0`. The tag must point to the current `main` commit.

Write user-facing changes in `release-notes/v<version>.md` before requesting a release. Keep the file nonempty and review it with the version change.

The release workflow passes that file through `--release-notes`. The configuration excludes raw commit lists and preserves existing release notes.

The `Release` workflow runs the same `Checks` workflow before creating a draft release. A failed check prevents release creation.

The workflow checks `main` again before packaging. Archives support Linux, macOS, and Windows on amd64 and arm64.

The archive prefix is `continuous`. GoReleaser creates platform archives and SHA-256 checksums during snapshot packaging.

Checksums are unsigned. Follow the README to download published releases without GitHub credentials.

Draft releases require authorized GitHub access. Do not publish a draft without operator approval.

Package releases from a clean checkout. The packaging script collects dependency notices for all six targets with `go-licenses/v2` at `v2.0.1`.

Keep vendor notices unchanged. Include the project license, dependency notices, and Go license and patent grant with distributed binaries.

The packaging artifact includes `LICENSE`, `third-party-notices.tar.gz`, and `legal-assets.sha256`. Use these separate assets to supplement the unchanged `v0.1.0` archives.

Do not replace the original `v0.1.0` archives, checksums, or tag. Attach the supplements only after the operator approves the reviewed change.

Do not push a release tag before the version passes review and checks.

Track generator defects in the owning issue. Do not patch generated runtime files.
