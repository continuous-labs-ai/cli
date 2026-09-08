import importlib.util
from pathlib import Path
import unittest


spec = importlib.util.spec_from_file_location("release_checks", Path("tests/release.py"))
release_checks = importlib.util.module_from_spec(spec)
spec.loader.exec_module(release_checks)


class Checksums(unittest.TestCase):
    def setUp(self):
        self.expected = {f"archive-{index}.tar.gz": str(index) * 64 for index in range(6)}
        self.lines = [f"{digest}  {name}" for name, digest in self.expected.items()]

    def test_complete_manifest(self):
        release_checks.validate_checksums("\n".join(self.lines) + "\n", self.expected)

    def test_empty_manifest(self):
        with self.assertRaises(ValueError):
            release_checks.validate_checksums("", self.expected)

    def test_missing_archive(self):
        with self.assertRaises(ValueError):
            release_checks.validate_checksums("\n".join(self.lines[:-1]), self.expected)

    def test_duplicate_archive(self):
        with self.assertRaises(ValueError):
            release_checks.validate_checksums("\n".join(self.lines + [self.lines[0]]), self.expected)

    def test_incorrect_digest(self):
        with self.assertRaises(ValueError):
            release_checks.validate_checksums("\n".join(self.lines).replace("0" * 64, "f" * 64), self.expected)

    def test_unexpected_archive(self):
        with self.assertRaises(ValueError):
            release_checks.validate_checksums("\n".join(self.lines + ["a" * 64 + "  extra.tar.gz"]), self.expected)

    def test_malformed_entry(self):
        for entry in ["not a checksum", "a" * 64 + "  ../archive.tar.gz", "\n"]:
            with self.subTest(entry=entry), self.assertRaises(ValueError):
                release_checks.validate_checksums(entry, self.expected)


if __name__ == "__main__":
    unittest.main()
