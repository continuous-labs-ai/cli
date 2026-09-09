# Maintain the CLI

Generate this CLI from the public Continuous Simulation API. Keep the repository private.

Change the API contract in `continuous-labs-ai/continuous`. Keep Eval and Internal APIs out of this repository.

Set command names and generator options in `.speakeasy/gen.yaml`. Do not patch generated runtime files.

Review owned settings, workflows, and documentation. Treat generated source as build output, not an exhaustive source review target.

Keep generated output marked with `linguist-generated`. Keep owned files visible during review.

The `.genignore` file protects the owned README, review attributes, and release configuration. Confirm that these files survive regeneration.

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

Release infrastructure is owned, not generated. Keep `cli.generateRelease: false` so regeneration does not replace release controls.

Push an approved tag that matches `cli.version`, such as `v0.1.0`. The tag must point to the current `main` commit.

The `Release` workflow runs the same `Checks` workflow before creating a draft release. A failed check prevents release creation.

The workflow checks `main` again before packaging. Archives support Linux, macOS, and Windows on amd64 and arm64.

The archive prefix is `continuous`. GoReleaser creates platform archives and SHA-256 checksums during snapshot packaging.

Checksums are unsigned. Download private assets through authenticated GitHub CLI access, as described in the README.

Do not push a release tag before the version passes review and checks.

Track generator defects in the owning issue. Do not patch generated runtime files.
