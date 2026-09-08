from pathlib import Path
import hashlib
import subprocess
import tarfile
import tempfile
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

with tempfile.TemporaryDirectory() as install_dir:
    executable = Path(install_dir) / "continuous"
    with tarfile.open("dist/continuous_Linux_x86_64.tar.gz") as package:
        executable.write_bytes(package.extractfile("continuous").read())
    executable.chmod(0o755)
    result = subprocess.run([str(executable), "version"], capture_output=True, text=True, timeout=15)
    assert result.returncode == 0, result.stderr
    assert "continuous" in result.stdout.lower(), result.stdout

print("All six archives, checksums, and the extracted Linux binary passed.")
