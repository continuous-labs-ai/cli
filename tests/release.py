from pathlib import Path
import hashlib
import re
import subprocess
import tarfile
import tempfile
import zipfile


def validate_checksums(manifest, expected):
    entries = {}
    for line in manifest.splitlines():
        match = re.fullmatch(r"([0-9a-f]{64})  ([^/\\\s]+)", line)
        if not match:
            raise ValueError("Invalid checksum entry.")
        digest, name = match.groups()
        if name in entries:
            raise ValueError("Duplicate checksum entry: " + name)
        entries[name] = digest
    if not entries or entries != expected:
        raise ValueError("Checksums must match all six release archives exactly.")

def main():
    expected = {}
    for system in ["Linux", "Darwin", "Windows"]:
        for arch in ["x86_64", "arm64"]:
            extension = "zip" if system == "Windows" else "tar.gz"
            archive = Path(f"dist/continuous_{system}_{arch}.{extension}")
            assert archive.is_file(), f"Installer archive is missing: {archive}"
            expected[archive.name] = hashlib.sha256(archive.read_bytes()).hexdigest()
            if extension == "zip":
                with zipfile.ZipFile(archive) as package:
                    assert "continuous.exe" in package.namelist()
            else:
                with tarfile.open(archive) as package:
                    assert "continuous" in package.getnames()
    validate_checksums(Path("dist/checksums.txt").read_text(), expected)

    with tempfile.TemporaryDirectory() as install_dir:
        executable = Path(install_dir) / "continuous"
        with tarfile.open("dist/continuous_Linux_x86_64.tar.gz") as package:
            executable.write_bytes(package.extractfile("continuous").read())
        executable.chmod(0o755)
        result = subprocess.run([str(executable), "version"], capture_output=True, text=True, timeout=15)
        assert result.returncode == 0, result.stderr
        assert "continuous" in result.stdout.lower(), result.stdout

    print("All six archives, checksums, and the extracted Linux binary passed.")


if __name__ == "__main__":
    main()
