import argparse
import base64
import hashlib
import json
import os
from pathlib import Path
import re
import urllib.error
import urllib.request


REPOSITORY = "continuous-labs-ai/cli"
TAP = "continuous-labs-ai/homebrew-tap"
ARCHIVES = {
    f"continuous_{platform}_{architecture}.tar.gz"
    for platform in ("Darwin", "Linux")
    for architecture in ("arm64", "x86_64")
}


def api(path, data=None, token=None):
    headers = {"Accept": "application/vnd.github+json"}
    if token:
        headers["Authorization"] = f"Bearer {token}"
    request = urllib.request.Request(
        f"https://api.github.com/repos/{path}",
        headers=headers,
        data=json.dumps(data).encode() if data is not None else None,
        method="PUT" if data is not None else "GET",
    )
    with urllib.request.urlopen(request, timeout=60) as response:
        return json.load(response)


def version(value):
    if not re.fullmatch(r"(?:0|[1-9]\d*)\.(?:0|[1-9]\d*)\.(?:0|[1-9]\d*)", value):
        raise ValueError("Use a stable semantic version.")
    return tuple(map(int, value.split(".")))


def published_release(tag):
    if not tag.startswith("v"):
        raise ValueError("Use a stable v-prefixed release tag.")
    version(tag[1:])
    token = os.environ.get("GH_TOKEN")
    release = api(f"{REPOSITORY}/releases/tags/{tag}", token=token)
    latest = api(f"{REPOSITORY}/releases/latest", token=token)
    if (release["draft"] or release["prerelease"] or not release["published_at"]
            or release["tag_name"] != tag or latest["id"] != release["id"]):
        raise ValueError("Update Homebrew from the latest public stable release only.")
    return release


def asset(release, name):
    matches = [item for item in release["assets"] if item["name"] == name]
    expected = f"https://github.com/{REPOSITORY}/releases/download/{release['tag_name']}/{name}"
    if len(matches) != 1 or matches[0]["browser_download_url"] != expected:
        raise ValueError(f"Missing, duplicate, or unexpected release asset: {name}")
    with urllib.request.urlopen(expected, timeout=60) as response:
        return response.read()


def formula_version(formula):
    matches = re.findall(r'^  version "([^"]+)"$', formula, re.MULTILINE)
    if len(matches) != 1:
        raise ValueError("The formula must have one stable version.")
    return version(matches[0])


def prepare(tag):
    release = published_release(tag)
    formula = asset(release, "continuous.rb")
    text = formula.decode()
    if formula_version(text) != version(tag[1:]):
        raise ValueError("The formula version does not match the release.")
    pairs = re.findall(r'^\s*url "([^"]+)"\n\s*sha256 "([a-f0-9]{64})"$', text, re.MULTILINE)
    prefix = f"https://github.com/{REPOSITORY}/releases/download/{tag}/"
    expected_urls = {prefix + name for name in ARCHIVES}
    if (len(pairs) != 4 or {url for url, _ in pairs} != expected_urls
            or len(re.findall(r'^\s*url ', text, re.MULTILINE)) != 4
            or len(re.findall(r'^\s*sha256 ', text, re.MULTILINE)) != 4):
        raise ValueError("The formula must reference the four published platform archives.")
    checksums = {}
    for line in asset(release, "checksums.txt").decode().splitlines():
        match = re.fullmatch(r"([a-f0-9]{64})  ([A-Za-z0-9_.-]+)", line)
        if not match or match[2] in checksums:
            raise ValueError("The release checksum manifest is malformed or has duplicate entries.")
        checksums[match[2]] = match[1]
    for url, digest in pairs:
        name = url.removeprefix(prefix)
        if checksums.get(name) != digest or hashlib.sha256(asset(release, name)).hexdigest() != digest:
            raise ValueError(f"The formula, manifest, and archive hashes must match: {name}")
    return formula


def publish(tag, formula):
    release = published_release(tag)
    if asset(release, "continuous.rb") != formula:
        raise ValueError("The verified formula must match the current release asset.")
    token = os.environ["HOMEBREW_TAP_GITHUB_TOKEN"]
    if not token:
        raise ValueError("Set the dedicated Homebrew tap token before publication.")
    endpoint = f"{TAP}/contents/Formula/continuous.rb"
    payload = {"message": f"Update Continuous to {tag}",
               "content": base64.b64encode(formula).decode(), "branch": "main"}
    try:
        existing = api(endpoint + "?ref=main", token=token)
    except urllib.error.HTTPError as error:
        if error.code != 404:
            raise
    else:
        content = base64.b64decode(existing["content"])
        if content == formula:
            print(f"The tap already contains the exact {tag} formula.")
            return
        if formula_version(content.decode()) >= version(tag[1:]):
            raise ValueError("Do not replace an existing version or downgrade the tap.")
        payload["sha"] = existing["sha"]
    published_release(tag)
    api(endpoint, data=payload, token=token)
    print(f"Updated the tap with the exact {tag} release formula.")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("command", choices=("prepare", "publish"))
    parser.add_argument("--tag", required=True)
    parser.add_argument("--formula", type=Path, required=True)
    args = parser.parse_args()
    if args.command == "prepare":
        args.formula.parent.mkdir(parents=True, exist_ok=True)
        args.formula.write_bytes(prepare(args.tag))
        print(f"Verified the public {args.tag} formula and all four archive hashes.")
    else:
        publish(args.tag, args.formula.read_bytes())


if __name__ == "__main__":
    main()
