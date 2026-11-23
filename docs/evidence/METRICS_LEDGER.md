# NetVision AI Metrics Ledger

This ledger contains only numbers backed by repository scripts or generated JSON reports.

| metric | value | model | source script | source JSON | run date | is_target | is_achieved |
|---|---:|---|---|---|---|---|---|
| F1-score | 0.8593 | A | `model/src/evaluate.py` | `model/results/evaluation_report.json` | 2026-10-16 00:17:16 | no | yes |
| precision | 1.0 | A | `model/src/evaluate.py` | `model/results/evaluation_report.json` | 2026-10-16 00:17:16 | no | yes |
| recall | 0.7533 | A | `model/src/evaluate.py` | `model/results/evaluation_report.json` | 2026-10-16 00:17:16 | no | yes |
| accuracy | 0.9353 | A | `model/src/evaluate.py` | `model/results/evaluation_report.json` | 2026-10-16 00:17:16 | no | yes |
| RMSE | 0.0197 | A | `model/src/evaluate.py` | `model/results/evaluation_report.json` | 2026-10-16 00:17:16 | no | yes |
| ROC-AUC | 0.9999 | A | `model/src/evaluate.py` | `model/results/evaluation_report.json` | 2026-10-16 00:17:16 | no | yes |
| confusion matrix TP | 1890 | A | `model/src/evaluate.py` | `model/results/evaluation_report.json` | 2026-10-16 00:17:16 | no | yes |
| confusion matrix FP | 0 | A | `model/src/evaluate.py` | `model/results/evaluation_report.json` | 2026-10-16 00:17:16 | no | yes |
| confusion matrix FN | 619 | A | `model/src/evaluate.py` | `model/results/evaluation_report.json` | 2026-10-16 00:17:16 | no | yes |
| confusion matrix TN | 7055 | A | `model/src/evaluate.py` | `model/results/evaluation_report.json` | 2026-10-16 00:17:16 | no | yes |
| single-inference latency ms | 972.45 | A | `model/src/evaluate.py` | `model/results/evaluation_report.json` | 2026-10-16 00:17:16 | no | yes |
| F1 target | >=0.85 | A | `model/src/evaluate.py` | `model/results/evaluation_report.json` | 2026-10-16 00:17:16 | yes | no |
| RMSE target | <=0.10 | A | `model/src/evaluate.py` | `model/results/evaluation_report.json` | 2026-10-16 00:17:16 | yes | no |
| latency target ms | <=2000 | A | `model/src/evaluate.py` | `model/results/evaluation_report.json` | 2026-10-16 00:17:16 | yes | no |
| baseline threshold F1 | 0.9308 | both | `model/src/baseline_comparator.py` | `model/results/comparative_evaluation.json` | 2026-10-30 15:07:12 | no | yes |
| baseline threshold precision | 0.9995 | both | `model/src/baseline_comparator.py` | `model/results/comparative_evaluation.json` | 2026-10-30 15:07:12 | no | yes |
| baseline threshold recall | 0.8709 | both | `model/src/baseline_comparator.py` | `model/results/comparative_evaluation.json` | 2026-10-30 15:07:12 | no | yes |
| baseline threshold accuracy | 0.966 | both | `model/src/baseline_comparator.py` | `model/results/comparative_evaluation.json` | 2026-10-30 15:07:12 | no | yes |
| baseline detection latency seconds | 31.4 | both | `model/src/baseline_comparator.py` | `model/results/comparative_evaluation.json` | 2026-10-30 15:07:12 | no | yes |
| baseline false alert rate | 0.0005 | both | `model/src/baseline_comparator.py` | `model/results/comparative_evaluation.json` | 2026-10-30 15:07:12 | no | yes |
| NetVision detection latency seconds | 1.25 | A | `model/src/baseline_comparator.py` | `model/results/comparative_evaluation.json` | 2026-10-30 15:07:12 | no | yes |
| baseline SUS | 54.2 | both | not logged in script | `model/results/comparative_evaluation.json` | not logged | no | stored only |
| NetVision SUS | 83.5 | both | not logged in script | `model/results/comparative_evaluation.json` | not logged | no | stored only |
| detection speedup | 25.1x | both | `model/src/baseline_comparator.py` | `model/results/comparative_evaluation.json` | 2026-10-30 15:07:12 | no | derived result |
| threat tree macro F1 | 0.9438538205980067 | B | `model/src/threat_model_evaluation.py` | `model/results/threat_monitor/threat-synthetic-v1/evaluation_report.json` | 2026-11-13T07:12:57.193911Z | no | yes |
| threat tree BENIGN F1 | 1.0 | B | `model/src/threat_model_evaluation.py` | `model/results/threat_monitor/threat-synthetic-v1/evaluation_report.json` | 2026-11-13T07:12:57.193911Z | no | yes |
| threat tree AVAILABILITY_ANOMALY F1 | 0.8761904761904762 | B | `model/src/threat_model_evaluation.py` | `model/results/threat_monitor/threat-synthetic-v1/evaluation_report.json` | 2026-11-13T07:12:57.193911Z | no | yes |
| threat tree OPERATIONAL_FAULT F1 | 1.0 | B | `model/src/threat_model_evaluation.py` | `model/results/threat_monitor/threat-synthetic-v1/evaluation_report.json` | 2026-11-13T07:12:57.193911Z | no | yes |
| threat tree UNKNOWN F1 | 0.8992248062015504 | B | `model/src/threat_model_evaluation.py` | `model/results/threat_monitor/threat-synthetic-v1/evaluation_report.json` | 2026-11-13T07:12:57.193911Z | no | yes |
| threat rules-only macro F1 | 0.5471108075350631 | B | `model/src/threat_model_evaluation.py` | `model/results/threat_monitor/threat-synthetic-v1/evaluation_report.json` | 2026-11-13T07:12:57.193911Z | no | yes |
| availability-risk PR-AUC | 0.736151110411199 | B | `model/src/threat_model_evaluation.py` | `model/results/threat_monitor/threat-synthetic-v1/evaluation_report.json` | 2026-11-13T07:12:57.193911Z | no | yes |
| availability-risk Brier score | 0.047764164514998486 | B | `model/src/threat_model_evaluation.py` | `model/results/threat_monitor/threat-synthetic-v1/evaluation_report.json` | 2026-11-13T07:12:57.193911Z | no | yes |
| OOD abstentions | 13/726 | B | `model/src/threat_model_evaluation.py` | `model/results/threat_monitor/threat-synthetic-v1/evaluation_report.json` | 2026-11-13T07:12:57.193911Z | no | yes |
| macro-F1 node bootstrap 95% lower | 0.8828019870155419 | B | `model/src/threat_model_evaluation.py` | `model/results/threat_monitor/threat-synthetic-v1/evaluation_report.json` | 2026-11-13T07:12:57.193911Z | no | yes |
| macro-F1 node bootstrap 95% upper | 0.9614374769860996 | B | `model/src/threat_model_evaluation.py` | `model/results/threat_monitor/threat-synthetic-v1/evaluation_report.json` | 2026-11-13T07:12:57.193911Z | no | yes |
| event recall | 1.0 | B | `model/src/threat_model_evaluation.py` | `model/results/threat_monitor/threat-synthetic-v1/evaluation_report.json` | 2026-11-13T07:12:57.193911Z | no | yes |
| event recall Wilson 95% lower | 0.7411599827511859 | B | `model/src/threat_model_evaluation.py` | `model/results/threat_monitor/threat-synthetic-v1/evaluation_report.json` | 2026-11-13T07:12:57.193911Z | no | yes |
| event recall Wilson 95% upper | 1.0 | B | `model/src/threat_model_evaluation.py` | `model/results/threat_monitor/threat-synthetic-v1/evaluation_report.json` | 2026-11-13T07:12:57.193911Z | no | yes |
| availability forecast recall | 0.0 | B | `model/src/threat_model_evaluation.py` | `model/results/threat_monitor/threat-synthetic-v1/evaluation_report.json` | 2026-11-13T07:12:57.193911Z | no | yes |
