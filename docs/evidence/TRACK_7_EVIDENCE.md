# Track 7 Evidence - Final Document and Diagram Regeneration

## UTC
`2026-11-23`

## Files changed
- `docs/diagrams/07_model_a_fault_architecture.drawio`
- `docs/diagrams/08_model_b_threat_architecture.drawio`
- `docs/evidence/TRACK_7_EVIDENCE.md`
- `docs/evidence/METRICS_LEDGER.md` remains the claim authority.

## Claim/evidence cross-check

| Claim | Ledger/evidence |
|---|---|
| Model A F1 0.8593 | `METRICS_LEDGER.md` → `model/results/evaluation_report.json` |
| Model A RMSE 0.0197 | `METRICS_LEDGER.md` → `model/results/evaluation_report.json` |
| Model A precision/recall/accuracy/ROC-AUC | `METRICS_LEDGER.md` → `model/results/evaluation_report.json` |
| Model A confusion matrix 1890/0/619/7055 | `METRICS_LEDGER.md` → `model/results/evaluation_report.json` |
| Model B macro-F1 0.9438538206 | `METRICS_LEDGER.md` → threat evaluation JSON |
| Model B availability-risk PR-AUC 0.7361511104 | `METRICS_LEDGER.md` → threat evaluation JSON |
| Model B OOD 13/726 | `METRICS_LEDGER.md` → threat evaluation JSON |
| Runtime threshold configuration | Track 1 evidence + unit tests |
| Retraining pipeline | Track 2 evidence + unit/dry-run tests |
| Telemetry collector dry-run 90 samples | Track 3 evidence |
| Enterprise topology 42 devices | Track 4 evidence |
| SUS raw evidence | BLOCKED - protocol/form exist, no responses |
| Deployed latency | BLOCKED - `LATENCY_RESULTS.json` is NOT_RUN |

## Diagrams

- `07_model_a_fault_architecture.drawio` - separate 10×5 BiLSTM path.
- `08_model_b_threat_architecture.drawio` - separate synthetic threat path.

Neither diagram presents Model B as production DDoS detection.

## Claims unlocked
- Separate Model A and Model B drawio architecture sources exist.
- A claim-to-ledger/evidence table is available.
- Historical report claims remain traceable rather than silently rewritten.

## Claims NOT unlocked
- Drawio PNG rendering was not available in this turn.
- The existing DOCX was not regenerated.
- The full final Markdown report was not rewritten across all chapters.
- SUS raw measurements and deployed latency remain blocked.
