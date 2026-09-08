# Maintain the CLI

Generate this CLI from the public Continuous Simulation API. Keep the repository private.

Change the API contract in `continuous-labs-ai/continuous`. Keep Eval and Internal APIs out of this repository.

Set command names and generator options in `.speakeasy/gen.yaml`. Do not patch generated runtime files.

Review owned settings, workflows, documentation, and behavior tests. Treat generated source as build output, not an exhaustive source review target.

Keep generated output marked with `linguist-generated`. Keep owned files visible during review.

The `.genignore` file protects the owned README, review attributes, and release configuration. Confirm that these files survive regeneration.

Run generation with Speakeasy 1.796.4:

```bash
speakeasy run --target continuous-simulation-cli
```

Run checks in GitHub Actions. The `Checks` workflow builds the binary and tests it against a local fixture server.

## Generation workflow

Store `SPEAKEASY_API_KEY` as a repository secret. Run the `Generate` workflow in `test` mode first.

Use `pr` mode after the test succeeds. This mode requires the `SPEAKEASY_GITHUB_TOKEN` repository secret.

Use a fine-grained token limited to this repository. Grant read and write access to contents and pull requests.

Use the scoped token for unattended generation checks. Pull requests from `GITHUB_TOKEN` can require approval before their checks run.

Do not reuse a broad personal token. Keep generation unavailable until the scoped secret exists.

Never use direct generation mode. Review generated changes before merging them.

## Releases

Release infrastructure is owned, not generated. Keep `cli.generateRelease: false` so regeneration does not replace release controls.

Push an approved tag that matches `cli.version`, such as `v0.0.1`. The tag must point to the current `main` commit.

The `Release` workflow runs the same `Checks` workflow before creating a draft release. A failed check prevents release creation.

The workflow checks `main` again before packaging. Archives support Linux, macOS, and Windows on amd64 and arm64.

The archive prefix is `continuous`. Checks verify archive names, binary extraction, execution, and SHA-256 checksums.

Checksums are unsigned. Download private assets through authenticated GitHub CLI access, as described in the README.

Do not push a release tag before the version passes review and checks.

## Current generator defects

Keep the failing behavior tests enabled until the generator fixes their behavior:

- JSON error output contains more than one document.
- `--agent-mode=false` does not override agent environment detection.
- The generated Simulator build example omits its requested name.

Speakeasy 1.796.4 remains the latest verified release. Do not replace these tests with handwritten runtime patches.
