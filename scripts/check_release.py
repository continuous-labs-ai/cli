import json
import os
from pathlib import Path
import re
import subprocess
import urllib.request


def validate_release(ref, head, main_head, configured_version):
    if not re.fullmatch(r"refs/tags/v\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?", ref):
        raise ValueError("Use an approved semantic version tag.")
    if head != main_head:
        raise ValueError("The release tag must point to the current main commit.")
    if ref.removeprefix("refs/tags/v") != configured_version:
        raise ValueError("The release tag must match cli.version in gen.yaml.")


def git(*args):
    return subprocess.check_output(["git", *args], text=True).strip()


def main():
    repository = os.environ["GITHUB_REPOSITORY"]
    if repository != "continuous-labs-ai/cli":
        raise ValueError("Release from continuous-labs-ai/cli only.")
    request = urllib.request.Request(
        f"https://api.github.com/repos/{repository}/git/ref/heads/main",
        headers={"Authorization": "Bearer " + os.environ["GH_TOKEN"],
                 "Accept": "application/vnd.github+json"},
    )
    with urllib.request.urlopen(request, timeout=30) as response:
        main_head = json.load(response)["object"]["sha"]
    config = Path(".speakeasy/gen.yaml").read_text()
    cli_config = config.split("\ncli:\n", 1)[1]
    version = re.search(r"^  version: ([^\s]+)$", cli_config, re.MULTILINE)[1]
    validate_release(os.environ["GITHUB_REF"], git("rev-parse", "HEAD"), main_head, version)
    if not Path(f"release-notes/v{version}.md").read_text().strip():
        raise ValueError("Write release notes before creating a draft release.")
    print("The tag matches the configured version and current main commit.")


if __name__ == "__main__":
    main()
