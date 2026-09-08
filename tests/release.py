from pathlib import Path
import hashlib
import tarfile
import zipfile


for system in ["Linux", "Darwin", "Windows"]:
    for arch in ["x86_64", "arm64"]:
        extension = "zip" if system == "Windows" else "tar.gz"
        archive = Path(f"dist/continuous_{system}_{arch}.{extension}")
        assert archive.is_file(), f"Installer archive is missing: {archive}"
        if extension == "zip":
            with zipfile.ZipFile(archive) as package:
                assert "continuous.exe" in package.namelist()
        else:
            with tarfile.open(archive) as package:
                assert "continuous" in package.getnames()

for entry in Path("dist/checksums.txt").read_text().splitlines():
    digest, name = entry.split()
    artifact = Path("dist") / name.lstrip("*")
    assert hashlib.sha256(artifact.read_bytes()).hexdigest() == digest

print("All six installer archives and their checksums passed.")
