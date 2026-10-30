# NetVision AI Project Status

**Status date:** 30 October 2026
**Project:** An AI-Powered Network Monitoring Dashboard with Intelligent Fault Anticipation

## Current Position

NetVision AI has a Flutter/Firebase dashboard codebase, a trained BiLSTM model, and a Firebase Cloud Functions inference integration. The model-serving functions are deployed to the configured Firebase project, `netvision-ai-0`, in `us-central1`. The Flutter test suite passed during this status review (5 tests).

Deployment was checked with `firebase functions:list --project netvision-ai-0`. It returned the deployed callable functions `model_status` and `predict_fault` (Python 3.11, 512 MiB). This confirms the functions are deployed; a signed-in end-to-end call verifying model loading and live inference was not run as part of this review.

## What the Model Can Analyse

The deployed BiLSTM accepts a 10-sample window of the five KPIs (latency, jitter, packet loss, retransmission rate, signal strength) and outputs exactly one value: a binary fault probability in [0, 1] (sigmoid head, `models/bilstm_fault_model.tflite`, input `[1,10,5]`, output `[1,1]`). It anticipates *whether* a fault is imminent. It does not classify fault types, identify root causes, detect security attacks, or forecast individual KPI values — the training data carries only a binary `fault_label`, so no other analysis is possible without retraining with new labels or output heads.

## 30 October Verification

- Local TFLite inference smoke test passed with the production artifacts (`tflite + scaler.joblib`): a healthy test window returned probability 0.0002 (HEALTHY, 10-second sampling), a fault-precursor window returned 0.3144 (WARNING); median inference latency ~0.4 ms per window on CPU. This verifies the model artifacts and preprocessing chain; the signed-in remote callable call remains outstanding.
- `py -m src.baseline_comparator` was re-run and exactly reproduced the recorded results (baseline F1 0.9308, BiLSTM F1 0.8593, latency 31.4 s vs 1.25 s, SUS 54.2 vs 83.5). The ambiguous `+-7.7%` field is fixed to `-7.7%` with an `f1_comparison_note` explaining that the row-level baseline scoring and window-level model scoring make raw F1 an unfair comparison; lead time, false-alert rate, and usability are the defensible axes.

## Implemented

- Flutter application structure includes authentication and role-oriented dashboard areas for network administrators, ICT managers, and system administrators.
- Firebase project configuration targets `netvision-ai-0`; the app uses Firebase Auth, Firestore, and Cloud Functions.
- A BiLSTM model and its supporting artifacts are present under `model/models/`: Keras and TensorFlow Lite model files, scaler, and metadata.
- `model/main.py` defines authenticated callable functions. `model_status` reports model metadata, while `predict_fault` validates a ten-sample window of five KPIs, scales the input, and runs TensorFlow Lite inference.
- The Flutter model repository calls those Firebase functions in `us-central1` and prepares aligned KPI windows from Firestore metrics.
- Adaptive inference behavior is implemented in the cloud function: probabilities below 30% return a ten-second next sampling interval (90% fewer requests than one-second sampling); probabilities at or above 70% trigger a critical alert.
- A separate FastAPI service exists at `model/api/app.py` for local REST inference. It is distinct from the deployed Firebase callable integration.

## Model Evaluation On Record

The stored evaluation report (`model/results/evaluation_report.json`) records:

| Metric                   | Recorded result |   Proposal target | Result |
| ------------------------ | --------------: | ----------------: | ------ |
| BiLSTM F1-score          |          0.8593 |     At least 0.85 | Met    |
| BiLSTM RMSE              |          0.0197 |      At most 0.10 | Met    |
| Single-inference latency |       972.45 ms | At most 2 seconds | Met    |

The comparative file (`model/results/comparative_evaluation.json`) records 1.25 seconds average detection latency and SUS 83.5 for NetVision AI. It records the threshold baseline at 31.4 seconds and SUS 54.2. These are repository-reported results, not independently reproduced in this review.

## Important Reconciliation

The proposal expected a baseline F1 near 0.50, but the stored and now-reproduced comparative evaluation reports baseline F1 0.9308 versus 0.8593 for NetVision AI. Cause: the baseline is scored row-level (its alerts coincide with rows already labelled as faults, inflating F1), while the BiLSTM is scored on 10-sample windows and fires before thresholds are crossed. The recorded results therefore support faster anticipation (25.1x), zero false alerts, and higher usability (SUS 83.5 vs 54.2), but do **not** claim BiLSTM superiority on raw F1. This is now documented in `model/results/comparative_evaluation.json` (`f1_comparison_note`). Presenting lead time rather than F1 as the headline comparison is the defensible position.

## Remaining Work / Verification

- Run an authenticated end-to-end call to `model_status`, then submit a valid ten-sample `predict_fault` request against the deployed function (requires a signed-in Firebase user; the local artifact chain is already verified).
- Verify the reported SUS score against the participant count, questionnaire responses, and calculation records before treating it as a final user-study result (the comparator hard-codes 83.5/54.2 rather than deriving them from collected responses).
- Complete final browser-level checks of the dashboard, since passing Flutter unit/widget tests does not establish that all deployed UI flows work end to end.
- Optional extension (out of proposal scope): retrain with fault-type labels or forecasting heads if the system should analyse more than binary fault anticipation.

## Deployment Answer

**Yes.** The model-serving backend is deployed to Google Cloud through Firebase Cloud Functions: `model_status` and `predict_fault` are listed as deployed in `us-central1`. The deployment listing verifies function presence, but the model's live health and inference response still need an authenticated runtime smoke test.
