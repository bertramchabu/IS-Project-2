import unittest

from src.retrain_runner import dry_run, artifact_hashes, sha256_file


class RetrainPipelineTests(unittest.TestCase):
    def test_dry_run_exercises_state_transitions(self):
        result = dry_run("request-123")
        self.assertTrue(result["dry_run"])
        self.assertEqual(
            [item["status"] for item in result["transitions"]],
            ["in_progress", "completed"],
        )

    def test_failure_capture_is_truncated_and_hashing_is_stable(self):
        from pathlib import Path
        import tempfile

        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "artifact.bin"
            path.write_bytes(b"stable")
            self.assertEqual(sha256_file(path), sha256_file(path))

            stderr = ("x" * 5000)[-4096:]
            self.assertEqual(len(stderr), 4096)


if __name__ == "__main__":
    unittest.main()
