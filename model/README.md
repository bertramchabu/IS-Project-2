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
modeltraining/
├── api/
│   └── app.py                            # FastAPI real-time REST service with adaptive load throttling
├── data/
│   ├── network_kpi_dataset.csv            # 5-KPI simulated dataset (4 nodes, 48,000 total records)
│   ├── train_kpi_dataset.csv              # 80% chronological training split
│   └── test_kpi_dataset.csv               # 20% held-out test split
├── models/
│   ├── bilstm_fault_model.keras          # Trained serialized Keras model
│   ├── bilstm_fault_model.tflite         # Lightweight TensorFlow Lite model for edge deployment
│   ├── scaler.joblib                      # Fitted StandardScaler for KPI preprocessing
│   └── model_metadata.json               # Schema metadata for database table model_versions
├── report/
│   └── COMPARATIVE_EVALUATION_REPORT.md  # Formal academic deliverable report
├── results/
│   ├── training_history.png              # Loss and RMSE optimization curves
│   ├── confusion_matrix.png              # Classification confusion matrix
│   ├── roc_curve.png                     # Receiver Operating Characteristic curve (AUC = 0.9999)
│   ├── comparative_metrics.png           # BiLSTM vs Baseline threshold monitoring comparison
│   ├── evaluation_report.json            # Numerical evaluation metrics
│   └── comparative_evaluation.json       # Comparative benchmarking data
├── src/
│   ├── dataset_generator.py              # Realistic network simulation with fault precursors
│   ├── model.py                          # BiLSTM architecture definition per Section 3.2.3
│   ├── train.py                          # Training pipeline with early stopping & checkpoints
│   ├── evaluate.py                       # Evaluation on held-out test split
│   ├── adaptive_inference.py             # Adaptive rate controller (90% reduction below 30% prob)
│   └── baseline_comparator.py            # Comparative evaluation against static thresholds
├── run_pipeline.py                       # Master end-to-end execution script
└── README.md                             # Documentation & instructions
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

---

## How to Run

### 1. Execute End-to-End Pipeline
To re-generate data, train the BiLSTM model, run evaluations, and generate charts:
```powershell
py -3.13 run_pipeline.py
```

### 2. Start Real-Time REST API
To launch the FastAPI server for Flutter dashboard integration:
```powershell
py -3.13 -m uvicorn api.app:app --host 127.0.0.1 --port 8000 --reload
```
Open interactive Swagger API docs at: `http://127.0.0.1:8000/docs`
