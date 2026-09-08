import importlib.util
from pathlib import Path
import unittest


spec = importlib.util.spec_from_file_location("release_gate", Path("scripts/check_release.py"))
release_gate = importlib.util.module_from_spec(spec)
spec.loader.exec_module(release_gate)


class ReleaseGate(unittest.TestCase):
    def test_matching_main_and_version(self):
        release_gate.validate_release("refs/tags/v0.0.1", "abc", "abc", "0.0.1")

    def test_non_main_tag_is_rejected(self):
        with self.assertRaises(ValueError):
            release_gate.validate_release("refs/tags/v0.0.1", "old", "main", "0.0.1")

    def test_version_mismatch_is_rejected(self):
        with self.assertRaises(ValueError):
            release_gate.validate_release("refs/tags/v0.0.2", "abc", "abc", "0.0.1")

    def test_branch_and_invalid_tag_are_rejected(self):
        for ref in ["refs/heads/main", "refs/tags/vlatest", "refs/tags/v0.0.1/other"]:
            with self.subTest(ref=ref), self.assertRaises(ValueError):
                release_gate.validate_release(ref, "abc", "abc", "0.0.1")


if __name__ == "__main__":
    unittest.main()
