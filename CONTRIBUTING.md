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

Owned release changes live in `.speakeasy/patches/`. `.goreleaser.yaml.patch` adds `project_name: continuous` so that archives keep the `continuous_<OS>_<arch>` names the installers download, sets `directory: Formula` and `skip_upload: true` on the Homebrew formula, drops the tap token, and adds the formula to the release assets. The installer patches add archive checksum verification and release tag validation. Speakeasy applies the patches after generation. After changing a patch, regenerate twice and confirm that the second run leaves no diff.

The `Publish` workflow (`sdk_publish.yaml`) runs when a `.speakeasy/gen.lock` change reaches `main`. Its `release` job runs Speakeasy's action, which tags `v<cli.version>` at that commit. Its `publish-cli` job runs GoReleaser with `CLI_GPG_SECRET_KEY` and `CLI_GPG_PASSPHRASE`, publishes the GitHub release with the archives, the signed `checksums.txt`, and the `continuous.rb` formula, and reports the release to the Speakeasy dashboard.

`sdk_publish.yaml` is a vendored copy of the two CLI jobs of Speakeasy's reusable `sdk-publish.yaml@v15`. The upstream job pins a `goreleaser-action` commit that does not exist; the copy pins the real `v6.3.0` commit. Do not run `speakeasy configure publishing`: it would overwrite the file, and it adds the two CLI GPG secrets to the `Generate` workflow, which `workflow-executor.yaml` does not declare, so GitHub refuses the run. Restore the reusable workflow call once upstream fixes the pin.

The `publish.cli` section of `.speakeasy/workflow.yaml` gates the `publish-cli` job: the `release` job sets `publish_cli` to `true` only when both `gpgPrivateKey` and `gpgPassPhrase` are set. Their `$name` values are placeholders; the `publish-cli` job reads `CLI_GPG_SECRET_KEY` and `CLI_GPG_PASSPHRASE` directly.

To release, merge a pull request that sets `cli.version` in `.speakeasy/gen.yaml` and regenerates. A `gen.lock` change on `main` without a new `cli.version` fails the `Publish` workflow because the tag already exists, and that failure publishes nothing. Never push `v*` tags by hand. The `Release tags` ruleset restricts updates and deletions of `v*` tags but not creation, because GitHub does not allow the Actions app as a bypass actor.

If a `Publish` run created the tag but its `publish-cli` job failed, an admin deletes the tag and the partial release. If `main` has not moved since, rerun the failed `Publish` run; otherwise run the `Publish` workflow by hand from `main` or cut the next version.

The generated `Release` workflow (`release.yaml`) stays because `generateRelease: true` also produces the installers. It runs only on a manual tag push, so it stays inert.

`release-signing-key.asc` at the repository root is the public key that matches `CLI_GPG_SECRET_KEY`. When the key rotates, replace that file and update the fingerprint in the README.

## Homebrew

Keep `cli.distribution.homebrew.enabled: true` with the tap `continuous-labs-ai/homebrew-tap`. Speakeasy writes the `brews` section of `.goreleaser.yaml` from these settings. The `publish-cli` job does not pass the tap token to GoReleaser, matching upstream, so the patch sets `skip_upload: true` and GoReleaser pushes nothing to the tap.

The owned `Publish Homebrew` workflow (`homebrew.yaml`) runs after each successful `Publish` run. It reads the latest release, checks that the formula version and its four archive URLs and SHA-256 values match the release and `checksums.txt`, and copies the exact formula to `Formula/continuous.rb` on the tap's `main` branch with `HOMEBREW_TAP_GITHUB_TOKEN`. Prereleases never reach the tap. Run the workflow by hand with the release tag to retry.

Limit that fine-grained token to the tap repository with contents read and write access. Do not reuse the generation token.
