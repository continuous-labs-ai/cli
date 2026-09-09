# Maintain the CLI

Generate this CLI from the public Continuous Simulation API. Keep credentials and private API contracts out of this repository.

Change the API contract in `continuous-labs-ai/continuous`. Keep Eval and Internal APIs out of this repository.

Set command names and generator options in `.speakeasy/gen.yaml`. Do not patch generated runtime files.

Review owned settings, workflows, and documentation. Treat generated source as build output, not an exhaustive source review target.

Keep generated output marked with `linguist-generated`. Keep owned files visible during review.

The `.genignore` file protects owned documentation, the license, and review attributes. Confirm that these files survive regeneration.

Run generation with Speakeasy 1.796.4:

```bash
speakeasy run --target continuous-simulation-cli
```

Run checks in GitHub Actions. The `Checks` workflow verifies generation, compiles the binary, and builds snapshot archives.

CLI test suites are disabled. Keep generated test files excluded through `.genignore` and the generator settings.

## Generation workflow

The `Generate` workflow is the standard Speakeasy workflow that `speakeasy configure github` writes. It runs nightly, on manual dispatch, and when a pull request label changes. It opens a pull request when generation changes files; review those changes before merging them.

Store `SPEAKEASY_API_KEY` as a repository secret. Store `SPEAKEASY_GITHUB_TOKEN` too; the workflow passes it as `pr_creation_pat` so that checks run on generation pull requests. Use a fine-grained token limited to this repository with read and write access to contents and pull requests.

## Releases

Speakeasy generates the release infrastructure. Keep `cli.generateRelease: true`; it writes `.goreleaser.yaml`, `.github/workflows/release.yaml`, `scripts/install.sh`, and `scripts/install.ps1`. These files are not in `.genignore`, so do not edit them by hand.

Owned release changes live in `.speakeasy/patches/`. `.goreleaser.yaml.patch` adds `project_name: continuous` so that archives keep the `continuous_<OS>_<arch>` names the installers download, moves the Homebrew `token` under `repository`, where GoReleaser reads it, and sets `directory: Formula` to match the tap layout. The installer patches add archive checksum verification and release tag validation. Speakeasy applies the patches after generation. After changing a patch, regenerate twice and confirm that the second run leaves no diff.

To release, merge the `cli.version` change in `.speakeasy/gen.yaml`, then push the tag `v<cli.version>` at `main`. The generated `Release` workflow builds the archives, signs `checksums.txt`, publishes the GitHub release with GoReleaser's changelog, and pushes the Homebrew formula. Every `v*` tag, including a prerelease such as `v0.2.0-rc1`, updates the tap formula, so push a prerelease tag only when the tap should serve it.

The workflow needs the `CLI_GPG_SECRET_KEY`, `CLI_GPG_PASSPHRASE`, and `HOMEBREW_TAP_GITHUB_TOKEN` repository secrets and fails without them. It publishes on any `v*` tag push, so add a tag ruleset that restricts who can create `v*` tags.

`release-signing-key.asc` at the repository root is the public key that matches `CLI_GPG_SECRET_KEY`. When the key rotates, replace that file and update the fingerprint in the README.

## Homebrew

Keep `cli.distribution.homebrew.enabled: true` with the tap `continuous-labs-ai/homebrew-tap`. Speakeasy writes the `brews` section of `.goreleaser.yaml` from these settings, and GoReleaser pushes `Formula/continuous.rb` to the tap's `main` branch with `HOMEBREW_TAP_GITHUB_TOKEN`.

Limit that fine-grained token to the tap repository with contents read and write access. Do not reuse the generation token.
