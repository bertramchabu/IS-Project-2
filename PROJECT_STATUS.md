# NetVision AI Project Status

**Status date:** 19 October 2026
**Project:** An AI-Powered Network Monitoring Dashboard with Intelligent Fault Anticipation

## Current Position

NetVision AI has a Flutter/Firebase dashboard codebase, a trained BiLSTM model, and a Firebase Cloud Functions inference integration. The model-serving functions are deployed to the configured Firebase project, `netvision-ai-0`, in `us-central1`. The Flutter test suite passed during this status review (5 tests).

Deployment was checked with `firebase functions:list --project netvision-ai-0`. It returned the deployed callable functions `model_status` and `predict_fault` (Python 3.11, 512 MiB). This confirms the functions are deployed; a signed-in end-to-end call verifying model loading and live inference was not run as part of this review.

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

The proposal describes a target baseline F1-score of 0.50, but the stored comparative evaluation reports a baseline F1-score of 0.9308, compared with 0.8593 for NetVision AI. Thus, the recorded results support faster anticipation and a higher SUS score, but do **not** show the BiLSTM outperforming the baseline on F1-score. The `f1_improvement` field is also recorded as `+-7.7%`, which is ambiguous. Before presenting the comparison as evidence, reconcile the baseline method, test split, threshold selection, and metric calculations, then regenerate the report from a reproducible evaluation.

## Remaining Work / Verification

- Run an authenticated end-to-end call to `model_status`, then submit a valid ten-sample `predict_fault` request and confirm the deployed function loads the model artifacts and returns a prediction.
- Reconcile comparative metrics with the proposal and correct the ambiguous improvement fields; explain any difference between the proposed baseline target and the evaluated baseline.
- Verify the reported SUS score against the participant count, questionnaire responses, and calculation records before treating it as a final user-study result.
- Align project documentation: the root README describes Firebase callable deployment, while the FastAPI service remains available as a separate local path. State clearly which path is used for the final demonstration.
- Complete any remaining proposal/documentation updates and final browser-level checks of the dashboard, since passing Flutter unit/widget tests does not establish that all deployed UI flows work end to end.

## Deployment Answer

**Yes.** The model-serving backend is deployed to Google Cloud through Firebase Cloud Functions: `model_status` and `predict_fault` are listed as deployed in `us-central1`. The deployment listing verifies function presence, but the model's live health and inference response still need an authenticated runtime smoke test.
