import base64
import copy
import importlib.util
import io
import json
import os
from pathlib import Path
import re
from unittest.mock import patch
from urllib.error import HTTPError


spec = importlib.util.spec_from_file_location("publication", "scripts/publish_homebrew.py")
publication = importlib.util.module_from_spec(spec)
spec.loader.exec_module(publication)
tag = "v9.8.7"
prefix = f"https://github.com/continuous-labs-ai/cli/releases/download/{tag}/"
formula = Path("dist/homebrew/Formula/continuous.rb").read_text()
formula = re.sub(r'^  version "[^"]+"$', '  version "9.8.7"', formula, flags=re.MULTILINE)
formula = re.sub(r"/releases/download/[^/]+/", f"/releases/download/{tag}/", formula).encode()
original_files = {name: Path("dist", name).read_bytes() for name in publication.ARCHIVES}
original_files.update({"continuous.rb": formula, "checksums.txt": Path("dist/checksums.txt").read_bytes()})
original_release = {"id": 123, "draft": False, "prerelease": False,
                    "published_at": "2026-09-09T00:00:00Z", "tag_name": tag,
                    "assets": [{"name": name, "browser_download_url": prefix + name}
                               for name in original_files]}
files = {}
release = {}
latest = {}
existing = None
writes = []


def reset():
    global files, release, latest, existing, writes
    files = copy.deepcopy(original_files)
    release = copy.deepcopy(original_release)
    latest = copy.deepcopy(original_release)
    existing = None
    writes = []


def response(request, timeout):
    url = request if isinstance(request, str) else request.full_url
    if url.startswith(prefix):
        name = url.removeprefix(prefix)
        if name not in files:
            raise HTTPError(url, 404, "Missing fixture asset", {}, None)
        return io.BytesIO(files[name])
    if url == f"https://api.github.com/repos/{publication.REPOSITORY}/releases/tags/{tag}":
        return io.BytesIO(json.dumps(release).encode())
    if url == f"https://api.github.com/repos/{publication.REPOSITORY}/releases/latest":
        return io.BytesIO(json.dumps(latest).encode())
    if url == f"https://api.github.com/repos/{publication.TAP}/contents/Formula/continuous.rb?ref=main":
        if existing is None:
            raise HTTPError(url, 404, "Missing fixture formula", {}, None)
        return io.BytesIO(json.dumps({"content": base64.b64encode(existing).decode(), "sha": "fixture-sha"}).encode())
    if url == f"https://api.github.com/repos/{publication.TAP}/contents/Formula/continuous.rb":
        assert request.get_method() == "PUT"
        payload = json.loads(request.data)
        assert base64.b64decode(payload["content"]) == formula
        assert payload["branch"] == "main"
        writes.append(payload)
        return io.BytesIO(b"{}")
    raise AssertionError(f"Unexpected observation request: {url}")


def reject(name, operation):
    try:
        operation()
    except (ValueError, HTTPError, KeyError):
        assert not writes
        print(f"Rejected {name} without a tap write.")
    else:
        raise AssertionError(f"Accepted {name}")


with patch.object(publication.urllib.request, "urlopen", response), patch.dict(os.environ, {"HOMEBREW_TAP_GITHUB_TOKEN": "observation-only"}):
    reset()
    assert publication.prepare(tag) == formula
    publication.publish(tag, formula)
    assert len(writes) == 1
    print("Copied the exact generated formula after matching all four archive hashes.")
    reset()
    existing = formula
    publication.publish(tag, formula)
    assert not writes
    print("Repeated publication made no tap write.")
    reset()
    existing = formula.replace(b'  version "9.8.7"', b'  version "9.8.6"')
    publication.publish(tag, formula)
    assert writes[0]["sha"] == "fixture-sha"
    print("An upgrade used the existing file SHA.")
    for invalid in ("v9.8.7-rc1", "v9.8.7/extra", "v09.8.7", "9.8.7"):
        reset()
        reject("invalid tag", lambda: publication.prepare(invalid))
    for field in ("draft", "prerelease"):
        reset()
        release[field] = True
        reject(field, lambda: publication.prepare(tag))
    reset()
    latest["id"] += 1
    reject("stale release", lambda: publication.prepare(tag))
    for changed in (b"", b"malformed\n", original_files["checksums.txt"] * 2):
        reset()
        files["checksums.txt"] = changed
        reject("missing, malformed, or duplicate checksums", lambda: publication.prepare(tag))
    reset()
    files["continuous_Darwin_arm64.tar.gz"] += b"corrupt"
    reject("archive hash mismatch", lambda: publication.prepare(tag))
    reset()
    files.pop("continuous.rb")
    reject("formula download failure", lambda: publication.prepare(tag))
    reset()
    release["assets"].append(copy.deepcopy(release["assets"][0]))
    reject("duplicate asset", lambda: publication.prepare(tag))
    reset()
    release["assets"][0]["browser_download_url"] = "https://example.invalid/archive"
    reject("foreign asset URL", lambda: publication.prepare(tag))
    reset()
    files["continuous.rb"] = formula.replace(b"/releases/download/v9.8.7/", b"/releases/download/v9.8.6/")
    reject("wrong formula URLs", lambda: publication.prepare(tag))
    for old in (formula.replace(b'  version "9.8.7"', b'  version "10.0.0"'), formula + b"\n"):
        reset()
        existing = old
        reject("downgrade or changed existing version", lambda: publication.publish(tag, formula))
    reset()
    files["continuous.rb"] += b"\n"
    reject("changed formula asset", lambda: publication.publish(tag, formula))
    reset()
    os.environ["HOMEBREW_TAP_GITHUB_TOKEN"] = ""
    reject("missing tap token", lambda: publication.publish(tag, formula))
