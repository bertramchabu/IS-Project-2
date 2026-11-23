# Track 0 Evidence - Baseline Freeze and Metrics Ledger

## Freeze date
- UTC: `2026-11-23T14:47:46Z`
- Branch: `alert`
- Baseline HEAD: `d6e1f38135357aac0402629c28499c5ed6f7e150`

## Files changed
- `.github/workflows/ci.yml` - adds repeatable Flutter/Python test and metrics execution.
- `model/requirements.txt` - declares the training/evaluation dependencies that were missing from the prior manifest.
- `docs/evidence/METRICS_LEDGER.md` - creates one ledger entry per repository-backed metric.
- `docs/evidence/reports/` - stores timestamped copies of the generated JSON reports.
- `docs/evidence/TRACK_0_EVIDENCE.md` - records commands and outcomes.

## Baseline Git state

Command:
```powershell
git rev-parse HEAD
git --no-pager status --short
git --no-pager branch --show-current
```

Raw stdout/stderr:
```text
d6e1f38135357aac0402629c28499c5ed6f7e150
 M "IS project.txt"
?? NetVision_AI_Complete_Final_Document.txt
?? docs/
?? model/data/threat/
alert
```

The worktree was not clean at baseline. The existing tracked modification and untracked documentation/data directories were preserved.

## Tool versions

Command:
```powershell
flutter --version
python --version
& 'C:\Users\Bertram Chabu\Videos\github\IS-Project-2\model\.venv\Scripts\python.exe' --version
```

Raw stdout/stderr:
```text
Flutter 3.47.5 • channel stable
Framework • revision 6a19cca564 (10 weeks ago)
Engine • hash ab598368592da0064197e2bc15c7f5b0a2c6bb1f
Tools • Dart 3.13.4 • DevTools 2.60.0
Python 3.12.11
Python 3.11.15
```

## Dependency restore

Command:
```powershell
flutter pub get
```

Raw stdout/stderr:
```text
Resolving dependencies...
Got dependencies!
67 packages have newer versions incompatible with dependency constraints.
Try `flutter pub outdated` for more information.
```

## Flutter analyzer

Command:
```powershell
flutter analyze
```

Raw result:
```text
58 issues found.
```

No analyzer issues were changed in Track 0. The baseline is **not 0 issues** and therefore does not close the final QA or CI quality claim.

## Flutter tests

Command:
```powershell
flutter test --reporter expanded
```

Raw stdout/stderr:
```text
+0 -0: loading test/alert_notification_tracker_test.dart
...
+40: All tests passed!
```

**Achieved baseline:** 40 Flutter tests passed.

## Python tests

Command:
```powershell
Set-Location 'C:\Users\Bertram Chabu\Videos\github\IS-Project-2\model'
& '.\.venv\Scripts\python.exe' -m unittest discover -s tests -v
```

Raw stdout/stderr:
```text
Ran 14 tests in 4.770s

OK
```

**Achieved baseline:** 14 Python tests passed.

## Model A evaluation

Command:
```powershell
Set-Location 'C:\Users\Bertram Chabu\Videos\github\IS-Project-2\model'
& '.\.venv\Scripts\python.exe' -m src.evaluate
```

Raw result:
```text
ModuleNotFoundError: No module named 'pandas'
```

After restoring the declared missing training dependencies, the rerun failed at native TensorFlow loading:

```text
ImportError: DLL load failed while importing _pywrap_tensorflow_internal:
A dynamic link library (DLL) initialization routine failed.

[TensorFlow DLL Diagnostic] Analyzing:
C:\Users\Bertram Chabu\Videos\github\IS-Project-2\model\.venv\Lib\site-packages\tensorflow\python\_pywrap_tensorflow_internal.pyd
[Error] Failed to load _pywrap_tensorflow_common.dll: INITIALIZATION FAILED (0x45A)
Hint: this often happens if the CPU lacks required instructions (AVX/AVX2)
or the Microsoft Visual C++ Redistributable is outdated/missing.
```

No new Model A evaluation report was produced by this rerun. The JSON copied to evidence is the repository's existing 2026-10-16 report.

## Model B threat evaluation

Command:
```powershell
Set-Location 'C:\Users\Bertram Chabu\Videos\github\IS-Project-2\model'
& '.\.venv\Scripts\python.exe' -m src.threat_model_evaluation
```

Raw result:
```text
Exit code: 0
```

The evaluation regenerated `model/results/threat_monitor/threat-synthetic-v1/evaluation_report.json`.

## Copied JSON reports
- `docs/evidence/reports/evaluation_report_20261123T144746Z.json`
- `docs/evidence/reports/comparative_evaluation_20261123T144746Z.json`
- `docs/evidence/reports/threat_evaluation_report_20261123T144746Z.json`

## Claims unlocked
- Metrics are centrally indexed in `docs/evidence/METRICS_LEDGER.md`.
- CI execution is now declared in `.github/workflows/ci.yml`.
- A repeatable Flutter test count is now explicitly recorded: 40 baseline pass.
- A repeatable Python test count is now explicitly recorded: 14 baseline pass.
- Model B synthetic evaluation has an explicit rerun command and timestamped copied report.
- Training/evaluation dependencies are declared in `model/requirements.txt`.

## Claims NOT unlocked
- Runtime threshold enforcement remains missing.
- Retraining remains a queue-only workflow.
- Production telemetry collector remains missing.
- Enterprise simulation remains not implemented.
- Formal SUS and performance evidence remain missing.
- Unknown-role/MFA/CORS/rules hardening remain missing.
- `flutter analyze` is not green: baseline 58 issues.
- Local Model A evaluation rerun is blocked by the native TensorFlow DLL on this machine.
- The repository was not clean at baseline, so Track 0 is frozen evidence rather than a clean release baseline.

## Contradictions found
- The `Ground Truth` text claims first 4 replay source IDs are assets. The implementation loads `model/data/network_kpi_dataset.csv`, not `assets/network_kpi_dataset.csv`.
- The `Ground Truth` text claims 41 test declarations. The expanded run currently reports 40 passed tests; 40 is also the repository run result.
- `model/requirements.txt` omitted pandas, Matplotlib, Seaborn and TensorFlow even though `src.evaluate.py` and `src/train.py` import them.
