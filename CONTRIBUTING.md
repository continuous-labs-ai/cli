# Maintain the CLI

Generate this CLI from the public Continuous Simulation API. Do not edit generated Go files or release files.

Change the API contract in `continuous-labs-ai/continuous`. Keep Eval and Internal APIs out of this repository.

Set command names and generator options in `.speakeasy/gen.yaml`.

Run generation with Speakeasy 1.796.4:

```bash
speakeasy run --target continuous-simulation-cli
```

Run checks in GitHub Actions. The `Checks` workflow builds the binary and tests it against a local fixture server.

## Generation workflow

Store `SPEAKEASY_API_KEY` as a repository secret. Run the `Generate` workflow in `test` mode first.

Use `pr` mode after the test succeeds. This mode requires the `SPEAKEASY_GITHUB_TOKEN` repository secret.

Use a fine-grained token limited to this repository. Grant read and write access to contents and pull requests.

The token must create generation pull requests so GitHub runs their checks. The default `GITHUB_TOKEN` does not trigger these checks.

Never use direct generation mode. Review generated changes before merging them.

## Releases

Run the generated `Release` workflow by pushing an approved version tag, such as `v0.1.0`.

This workflow creates a public GitHub Release. It builds Linux, macOS, and Windows archives for amd64 and arm64.

Speakeasy 1.796.4 generates unsigned SHA-256 checksums. Its generated workflow does not sign checksums or require GPG secrets.

Do not push a release tag before the version passes review and checks.
