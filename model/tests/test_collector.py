import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from collector.agent import (
    jitter_ms,
    load_yaml_config,
    probe_sample,
    require_write_key,
)


class CollectorTests(unittest.TestCase):
    def test_probe_math_and_packet_loss(self):
        self.assertEqual(jitter_ms([10.0]), 0.0)
        self.assertGreater(jitter_ms([10.0, 12.0]), 0.0)
        with patch(
            "collector.agent.tcp_connect_latency_ms",
            side_effect=[10.0, 12.0],
        ):
            sample = probe_sample(
                "SYNTHETIC-DEMO-NODE",
                "127.0.0.1",
                18080,
                probe_count=2,
            )
        self.assertEqual(sample["nodeId"], "SYNTHETIC-DEMO-NODE")
        self.assertEqual(sample["source"], "collector")
        self.assertIn("packet_loss", sample)

    def test_missing_key_requires_service_account_or_emulator(self):
        import os

        old_key = os.environ.pop("NETVISION_COLLECTOR_KEY", None)
        old_emulator = os.environ.pop("FIREBASE_EMULATOR", None)
        try:
            with self.assertRaises(PermissionError):
                require_write_key(False)
        finally:
            if old_key:
                os.environ["NETVISION_COLLECTOR_KEY"] = old_key
            if old_emulator:
                os.environ["FIREBASE_EMULATOR"] = old_emulator

    def test_dry_run_does_not_require_key(self):
        self.assertEqual(require_write_key(True), "DRY-RUN")

    def test_yaml_config_loader(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "config.yml"
            path.write_text(
                "targets:\n"
                "  - nodeId: SYNTHETIC-DEMO-NODE\n"
                "    host: 127.0.0.1\n"
                "    port: 443\n"
                "    intervalSeconds: 1\n",
                encoding="utf-8",
            )
            config = load_yaml_config(path)
            self.assertEqual(config["targets"][0]["port"], 443)


if __name__ == "__main__":
    unittest.main()
