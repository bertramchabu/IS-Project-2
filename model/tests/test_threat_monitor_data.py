import csv
import tempfile
import unittest
from pathlib import Path

from src.threat_monitor_data import (
    generate_synthetic_windows,
    load_cic_profiles,
    map_cic_label,
    write_dataset,
)


class ThreatMonitorDataTests(unittest.TestCase):
    def setUp(self):
        self.temporary_directory = tempfile.TemporaryDirectory()
        self.data_directory = Path(self.temporary_directory.name) / "cic"
        self.data_directory.mkdir()
        with (self.data_directory / "flows.csv").open(
            "w", encoding="utf-8", newline=""
        ) as target:
            writer = csv.DictWriter(
                target,
                fieldnames=[
                    " Source IP",
                    "Flow Packets/s",
                    "Flow Bytes/s",
                    "Flow Duration",
                    "Total Fwd Packets",
                    "Total Backward Packets",
                    "Protocol",
                    "Destination Port",
                    " Label",
                ],
            )
            writer.writeheader()
            sample_rows = [
                {
                    " Source IP": "must-not-be-retained",
                    "Flow Packets/s": "20",
                    "Flow Bytes/s": "1000",
                    "Flow Duration": "1000000",
                    "Total Fwd Packets": "10",
                    "Total Backward Packets": "5",
                    "Protocol": "6",
                    "Destination Port": "443",
                    " Label": "BENIGN",
                },
                {
                    " Source IP": "must-not-be-retained",
                    "Flow Packets/s": "200",
                    "Flow Bytes/s": "10000",
                    "Flow Duration": "2000000",
                    "Total Fwd Packets": "20",
                    "Total Backward Packets": "5",
                    "Protocol": "17",
                    "Destination Port": "53",
                    " Label": "DDoS",
                },
                {
                    " Source IP": "must-not-be-retained",
                    "Flow Packets/s": "4",
                    "Flow Bytes/s": "100",
                    "Flow Duration": "100000",
                    "Total Fwd Packets": "1",
                    "Total Backward Packets": "1",
                    "Protocol": "1",
                    "Destination Port": "80",
                    " Label": "PortScan",
                },
            ]
            writer.writerows(sample_rows[index % 3] for index in range(300))

    def tearDown(self):
        self.temporary_directory.cleanup()

    def test_maps_only_dos_ddos_to_availability(self):
        self.assertEqual(map_cic_label("DDoS"), "AVAILABILITY_ANOMALY")
        self.assertEqual(map_cic_label("DoS Hulk"), "AVAILABILITY_ANOMALY")
        self.assertEqual(map_cic_label("PortScan"), "UNKNOWN")
        self.assertEqual(map_cic_label("BENIGN"), "BENIGN")

    def test_profiles_exclude_identifiers_and_generate_disjoint_splits(self):
        profiles = load_cic_profiles(self.data_directory, max_samples_per_class=10)
        self.assertGreater(profiles.row_counts["train"]["BENIGN"], 0)
        self.assertGreater(profiles.row_counts["validation"]["AVAILABILITY_ANOMALY"], 0)
        self.assertGreater(profiles.row_counts["test"]["UNKNOWN"], 0)
        self.assertNotIn(
            "source_ip", profiles.samples["train"]["BENIGN"][0]
        )

        rows = list(
            generate_synthetic_windows(
                profiles,
                site_count=20,
                windows_per_site=100,
                gap_windows=10,
                seed=7,
            )
        )
        split_nodes = {
            split: {row["node_id"] for row in rows if row["split"] == split}
            for split in ("train", "validation", "test")
        }
        self.assertTrue(split_nodes["train"].isdisjoint(split_nodes["validation"]))
        self.assertTrue(split_nodes["validation"].isdisjoint(split_nodes["test"]))
        self.assertTrue(split_nodes["train"].isdisjoint(split_nodes["test"]))
        self.assertTrue(all("synthetic_window" in row["data_quality_flags"] for row in rows))
        self.assertTrue(all(row["source_dataset"] == "CIC-IDS2017" for row in rows))
        self.assertTrue(all(row["schema_version"] == 1 for row in rows))
        self.assertIn("OPERATIONAL_FAULT", {row["label"] for row in rows})

        train_end = max(
            row["window_end_utc"] for row in rows if row["split"] == "train"
        )
        validation_start = min(
            row["window_start_utc"]
            for row in rows
            if row["split"] == "validation"
        )
        self.assertGreater(validation_start, train_end)

    def test_write_dataset_persists_provenance_manifest(self):
        output = Path(self.temporary_directory.name) / "generated" / "data.csv"
        manifest = write_dataset(
            self.data_directory,
            output,
            site_count=20,
            windows_per_site=100,
            seed=11,
        )
        self.assertTrue(output.exists())
        self.assertTrue(output.with_suffix(".csv.manifest.json").exists())
        self.assertEqual(manifest["dataset_version"], "threat-synthetic-v1")
        self.assertEqual(manifest["source_files"], ["flows.csv"])
        self.assertGreater(manifest["split_counts"]["test"], 0)


if __name__ == "__main__":
    unittest.main()
