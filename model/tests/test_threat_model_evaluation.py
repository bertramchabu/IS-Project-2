import csv
import tempfile
import unittest
from pathlib import Path

from src.threat_model_evaluation import _build_sequences, _read_split
from src.threat_monitor_data import (
    generate_synthetic_windows,
    load_cic_profiles,
)

class ThreatModelSplitTests(unittest.TestCase):
    def setUp(self):
        self.temporary_directory = tempfile.TemporaryDirectory()
        self.data_directory = Path(self.temporary_directory.name) / "cic"
        self.data_directory.mkdir()
        source = self.data_directory / "flows.csv"
        fields = [
            "Flow Packets/s",
            "Flow Bytes/s",
            "Flow Duration",
            "Total Fwd Packets",
            "Total Backward Packets",
            "Protocol",
            "Destination Port",
            "Label",
        ]
        rows = (
            ("20", "1000", "1000000", "10", "5", "6", "443", "BENIGN"),
            ("200", "10000", "2000000", "20", "5", "17", "53", "DDoS"),
            ("4", "100", "100000", "1", "1", "1", "80", "PortScan"),
        )
        with source.open("w", encoding="utf-8", newline="") as target:
            writer = csv.writer(target)
            writer.writerow(fields)
            writer.writerows(rows[index % len(rows)] for index in range(300))

    def tearDown(self):
        self.temporary_directory.cleanup()

    def test_sequence_splits_keep_sites_disjoint_and_preserve_time_gap(self):
        profiles = load_cic_profiles(self.data_directory, max_samples_per_class=100)
        output = Path(self.temporary_directory.name) / "windows.csv"
        with output.open("w", encoding="utf-8", newline="") as target:
            writer = None
            for row in generate_synthetic_windows(
                profiles,
                site_count=20,
                windows_per_site=500,
                gap_windows=10,
                seed=19,
            ):
                if writer is None:
                    writer = csv.DictWriter(target, fieldnames=list(row))
                    writer.writeheader()
                writer.writerow(row)

        source_splits = _read_split(output)
        sequences = {
            split: _build_sequences(rows)
            for split, rows in source_splits.items()
        }
        node_sets = {
            split: {row["node_id"] for row in group["metadata"]}
            for split, group in sequences.items()
        }
        self.assertTrue(node_sets["train"].isdisjoint(node_sets["validation"]))
        self.assertTrue(node_sets["validation"].isdisjoint(node_sets["test"]))
        self.assertTrue(node_sets["train"].isdisjoint(node_sets["test"]))
        self.assertEqual(sequences["train"]["sequences"].shape[1], 10)
        self.assertGreater(len(sequences["test"]["labels"]), 0)

        last_train_end = max(
            row["window_end_utc"] for row in source_splits["train"]
        )
        first_validation_start = min(
            row["window_start_utc"] for row in source_splits["validation"]
        )
        self.assertGreater(first_validation_start, last_train_end)


if __name__ == "__main__":
    unittest.main()
