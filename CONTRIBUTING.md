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

The `publish` section of `.speakeasy/workflow.yaml` names the CLI signing secrets. `speakeasy configure publishing` reads it, writes the `Publish` workflow (`sdk_publish.yaml`), and passes the same secrets to the `Generate` workflow. Rerun that command after changing the section instead of editing the two workflows by hand. The command also adds the two CLI GPG secrets to the `Generate` workflow, but `workflow-executor.yaml` does not declare them and GitHub refuses the run, so remove those two lines after each rerun.

## Releases

Speakeasy generates the release infrastructure. Keep `cli.generateRelease: true`; it writes `.goreleaser.yaml`, `.github/workflows/release.yaml`, `scripts/install.sh`, and `scripts/install.ps1`. These files are not in `.genignore`, so do not edit them by hand.

Owned release changes live in `.speakeasy/patches/`. `.goreleaser.yaml.patch` adds `project_name: continuous` so that archives keep the `continuous_<OS>_<arch>` names the installers download, sets `directory: Formula` and `skip_upload: true` on the Homebrew formula, drops the tap token, and adds the formula to the release assets. The installer patches add archive checksum verification and release tag validation. Speakeasy applies the patches after generation. After changing a patch, regenerate twice and confirm that the second run leaves no diff.

The `Publish` workflow runs when a `.speakeasy/gen.lock` change reaches `main`. Speakeasy's action tags `v<cli.version>` at that commit, runs GoReleaser with `CLI_GPG_SECRET_KEY` and `CLI_GPG_PASSPHRASE`, publishes the GitHub release with the archives, the signed `checksums.txt`, and the `continuous.rb` formula, and reports the release to the Speakeasy dashboard.

To release, merge a pull request that sets `cli.version` in `.speakeasy/gen.yaml` and regenerates. A `gen.lock` change on `main` without a new `cli.version` fails the `Publish` workflow because the tag already exists, and that failure publishes nothing. Never push `v*` tags by hand. The `Release tags` ruleset restricts updates and deletions of `v*` tags but not creation, because GitHub does not allow the Actions app as a bypass actor.

If a `Publish` run created the tag but its publish job failed, a plain rerun fails at tag creation because the tag exists, and GoReleaser refuses to replace existing assets. An admin deletes the tag and the partial release, then reruns the `Publish` workflow.

The generated `Release` workflow (`release.yaml`) stays because `generateRelease: true` also produces the installers. It runs only on a manual tag push, so it stays inert.

`release-signing-key.asc` at the repository root is the public key that matches `CLI_GPG_SECRET_KEY`. When the key rotates, replace that file and update the fingerprint in the README.

## Homebrew

Keep `cli.distribution.homebrew.enabled: true` with the tap `continuous-labs-ai/homebrew-tap`. Speakeasy writes the `brews` section of `.goreleaser.yaml` from these settings. Speakeasy's publish job does not pass the tap token to GoReleaser, so the patch sets `skip_upload: true` and GoReleaser pushes nothing to the tap.

The owned `Publish Homebrew` workflow (`homebrew.yaml`) runs after each successful `Publish` run. It reads the latest release, checks that the formula version and its four archive URLs and SHA-256 values match the release and `checksums.txt`, and copies the exact formula to `Formula/continuous.rb` on the tap's `main` branch with `HOMEBREW_TAP_GITHUB_TOKEN`. Prereleases never reach the tap. Run the workflow by hand with the release tag to retry.

Limit that fine-grained token to the tap repository with contents read and write access. Do not reuse the generation token.
