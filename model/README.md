# NetVision AI: Deep Learning Fault Anticipation Engine

**Project:** An AI-Powered Network Monitoring Dashboard with Intelligent Fault Anticipation  
**Institution:** School of Computing and Engineering Sciences, Strathmore University  
**Degree:** Bachelor of Business in Information Technology (BBIT 4C)  
**Student:** Chabu Bertram Brian (Admission No: 166458)  
**Supervisor:** Dr. Paul Macharia  

---

## Overview

NetVision AI provides proactive network fault anticipation using a lightweight **Bidirectional Long Short-Term Memory (BiLSTM)** neural network trained on five multivariate network Key Performance Indicators (KPIs):
- **Latency** (ms)
- **Jitter** (ms)
- **Packet Loss** (%)
- **Retransmission Rate** (%)
- **Signal Strength** (dBm)

---

## Project Structure

```
model/
├── main.py                 # Authenticated fault and simulation-only threat callables
├── api/app.py              # Optional local FastAPI inference service
├── data/                   # Generated and chronological train/test KPI datasets
├── models/                 # Fault artifacts and packaged threat inference artifacts
├── results/                # Evaluation reports, plots, and generated candidate artifacts
└── src/
    ├── dataset_generator.py
    ├── model.py            # BiLSTM architecture and built-in-ops TFLite export
    ├── train.py
    ├── evaluate.py
    ├── adaptive_inference.py
    └── baseline_comparator.py
```

---

## Target Metrics Compliance

| Target Metric | Proposal Requirement | NetVision AI Achieved | Status |
| :--- | :--- | :--- | :--- |
| **Fault Anticipation F1-Score** | $\ge 0.85$ | **0.8593** | **PASSED** |
| **Prediction RMSE** | $\le 0.10$ | **0.0197** | **PASSED** |
| **Inference Latency** | $\le 2.0\text{ seconds}$ | **972.45 ms** (batch: **0.19 ms/sample**) | **PASSED** |
| **Anticipation Lead Time** | Fast vs 30s baseline | **1.25s vs 31.4s** (25x faster anticipation) | **PASSED** |
| **System Usability Scale (SUS)**| $\ge 70.0$ | **83.5 / 100** | **PASSED** |
| **Adaptive Load Reduction** | 90% load savings when prob $< 30\%$ | **Implemented & Active** | **PASSED** |

The stored comparative results report baseline F1 **0.9308** and BiLSTM F1
**0.8593** (reproduced by `py -m src.baseline_comparator` on 30 October 2026).
The model meets its standalone F1 target, but those figures do not show that
it outperforms the baseline on F1: the baseline is scored row-level while the
BiLSTM is scored on 10-sample windows and fires before thresholds are crossed
(see `f1_comparison_note` in `results/comparative_evaluation.json`). Present
lead time, false-alert rate, and usability as the comparison axes, not raw F1.

---

## How to Run

### 1. Generate and evaluate the model
Run these commands from the `model` directory. Training regenerates the KPI
data, scaler, Keras model, and TFLite model. Evaluation scripts use the
generated held-out dataset:
```powershell
py -3.13 -m src.train
py -3.13 -m src.evaluate
py -3.13 -m src.baseline_comparator
```

The TFLite export uses built-in operators only, so it can run with the
lightweight `tflite-runtime` dependency used by Firebase Functions.

### 2. Start the local REST API
The Firebase callable functions are the inference path used by the Flutter
dashboard. To run the separate local FastAPI service:
```powershell
py -3.13 -m pip install -r api\requirements.txt
py -3.13 -m uvicorn api.app:app --host 127.0.0.1 --port 8000 --reload
```
Open interactive Swagger API docs at: `http://127.0.0.1:8000/docs`

## Separate threat-monitoring evaluation

The threat-monitoring data and evaluation path is separate from the BiLSTM
fault model above. It does not modify or use the fault-probability output.

The CIC-IDS2017 inputs contain flow rows but no timestamps, site identifiers,
or service-health labels. The generator partitions source rows and combines
their numeric flow profiles with explicitly synthetic windows, labels,
timestamps, and service outcomes. Results are pipeline simulations, not
evidence of production DDoS detection.

From the `model` directory, with the dependencies in `requirements.txt`
installed:

```powershell
.\venv\Scripts\python.exe -m src.threat_monitor_data
.\venv\Scripts\python.exe -m src.threat_model_evaluation
.\venv\Scripts\python.exe -m unittest discover -s tests -v
```

The generated dataset and manifest are written beneath
`data/threat/generated/`; evaluation artifacts, raw test predictions, and
metrics are written beneath `results/threat_monitor/`. The selected calibrated
tree classifier, availability-risk model, and OOD detector are packaged under
`models/threat/` for the authenticated `threat_model_status` and
`predict_threat` callables. The threat callable accepts only windows marked
`synthetic_demo` with the synthetic demo node/service identifiers and performs
no writes. When a cloud result classifies an anomaly during replay, the Flutter
app writes a `[SIMULATION]` alert through the existing role-checked alert
collection; the feature window and threat assessment are not persisted. The
threat model remains simulation-only and is not approved for real network
inference; the unselected temporal candidate remains an offline
evaluation artifact. See
[`THREAT_FEATURE_LABEL_SPEC.md`](../docs/THREAT_FEATURE_LABEL_SPEC.md),
[`THREAT_MODEL_CARD.md`](../docs/THREAT_MODEL_CARD.md), and
[`THREAT_EVIDENCE_RETENTION.md`](../docs/THREAT_EVIDENCE_RETENTION.md).
