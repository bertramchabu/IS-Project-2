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
├── main.py                 # Authenticated Firebase callable model_status/predict_fault
├── api/app.py              # Optional local FastAPI inference service
├── data/                   # Generated and chronological train/test KPI datasets
├── models/                 # Keras/TFLite models, scaler, and model metadata
├── results/                # Evaluation reports and plots
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
**0.8593**. The model meets its standalone F1 target, but those figures do not
show that it outperforms the baseline on F1. Reproduce and reconcile the
comparison before presenting it as a model F1 improvement.

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
