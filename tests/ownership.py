from pathlib import Path
import subprocess


generated = ["cmd/continuous/main.go", "internal/cli/root.go", "internal/sdk/simulations.go",
             "USAGE.md", "go.mod", "go.sum", ".speakeasy/out.openapi.yaml", ".speakeasy/gen.lock"]
owned = ["README.md", "CONTRIBUTING.md", ".gitattributes", "internal/sdk/.gitattributes",
         ".genignore", ".goreleaser.yaml", ".speakeasy/gen.yaml", ".speakeasy/workflow.yaml",
         ".github/workflows/checks.yaml", ".github/workflows/release.yaml",
         "tests/smoke.py", "scripts/check_release.py"]
for expected, paths in [("true", generated), ("false", owned)]:
    for path in paths:
        value = subprocess.check_output(["git", "check-attr", "linguist-generated", "--", path], text=True)
        assert value.strip().endswith(": " + expected), value

ignored = set(Path(".genignore").read_text().splitlines())
for path in ["README.md", ".gitattributes", "internal/sdk/.gitattributes", ".goreleaser.yaml",
             ".github/workflows/release.yaml"]:
    assert "/" + path in ignored, path

for path in ["scripts/install.sh", "scripts/install.ps1"]:
    assert not Path(path).exists(), f"Unauthenticated installer remains: {path}"

print("Generated output and owned inputs have separate review attributes.")
