# Ground Truth Contradictions

## Replay asset path

- Contradictory attached inventory: “Replay: assets/network_kpi_dataset.csv”.
- Repository implementation: [csv_telemetry_replay.dart](/C:/Users/Bertram%20Chabu/Videos/github/IS-Project-2/lib/services/csv_telemetry_replay.dart:10) declares:

  ```dart
  static const assetPath = 'model/data/network_kpi_dataset.csv';
  ```

- [pubspec.yaml](/C:/Users/Bertram%20Chabu/Videos/github/IS-Project-2/pubspec.yaml:53) declares the same `model/data/network_kpi_dataset.csv` asset.
- `assets/network_kpi_dataset.csv` does NOT exist.
- **Code-supported fact:** the replay source is `model/data/network_kpi_dataset.csv`.

## Flutter test count

- Contradictory attached inventory: “Flutter (12 files, 41 test()/testWidgets())”.
- Source scan found declarations in 12 files, but the baseline expanded run completed with 40 tests passed.
- **Code-supported baseline:** 40 passed tests; the declaration count may include declarations grouped or split differently, but the runner count is 40.

## Training dependency manifest

- Attached Ground Truth assumes the repository environment already supports evaluation.
- `model/src/evaluate.py` and `model/src/train.py` require pandas, Matplotlib, Seaborn and TensorFlow.
- [model/requirements.txt](/C:/Users/Bertram%20Chabu/Videos/github/IS-Project-2/model/requirements.txt:1) did not declare them at baseline.
- Track 0 adds these dependencies.
