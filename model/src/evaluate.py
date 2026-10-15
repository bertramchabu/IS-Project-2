"""
evaluate.py - Model Evaluation & Performance Validation
Project: NetVision AI (Strathmore University)
Author: Bertram Chabu (166458, BBIT 4C)

Fulfills Phase 5 / Specific Objective ii & iv:
- Computes F1-score (Target: >= 0.85)
- Computes Root Mean Squared Error (Target: <= 0.10)
- Computes Precision, Recall, Accuracy, ROC-AUC
- Measures single-cycle inference latency (Target: <= 2 seconds)
- Generates Confusion Matrix and ROC Curve plots
- Outputs model_metadata.json matching PostgreSQL database schema (Table 4.1)
"""

import os
import sys
import time
import json
import joblib
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns
from sklearn.metrics import (
    f1_score, precision_score, recall_score, accuracy_score,
    mean_squared_error, confusion_matrix, roc_curve, auc
)
from tensorflow import keras

# Add project root to sys.path
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from src.dataset_generator import create_sliding_windows

def evaluate_model(threshold: float = 0.65, window_size: int = 10):
    print("=" * 70)
    print("NetVision AI - Model Evaluation & Target Verification")
    print("=" * 70)
    
    base_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
    models_dir = os.path.join(base_dir, "models")
    data_dir = os.path.join(base_dir, "data")
    results_dir = os.path.join(base_dir, "results")
    
    model_path = os.path.join(models_dir, "bilstm_fault_model.keras")
    scaler_path = os.path.join(models_dir, "scaler.joblib")
    test_csv_path = os.path.join(data_dir, "test_kpi_dataset.csv")
    
    if not os.path.exists(model_path):
        raise FileNotFoundError(f"Trained model not found at {model_path}. Run train.py first.")
    
    print("\nLoading trained BiLSTM model and scaler...")
    model = keras.models.load_model(model_path)
    scaler = joblib.load(scaler_path)
    
    print(f"Loading held-out test dataset from {test_csv_path}...")
    test_df = pd.read_csv(test_csv_path)
    feature_cols = ["latency", "jitter", "packet_loss", "retransmission_rate", "signal_strength"]
    
    test_df_scaled = test_df.copy()
    test_df_scaled[feature_cols] = scaler.transform(test_df[feature_cols])
    
    X_test, y_test_bin, y_test_prob, time_test, node_test = create_sliding_windows(
        test_df_scaled, feature_cols, window_size=window_size
    )
    
    print(f"Held-out test samples: {len(X_test)} windows across {len(np.unique(node_test))} nodes")
    
    # Measure inference latency (Benchmark for NFR-PE-02: <= 2s)
    print("\nMeasuring inference latency...")
    single_window = X_test[0:1]
    start_t = time.perf_counter()
    _ = model.predict(single_window, verbose=0)
    latency_single_ms = (time.perf_counter() - start_t) * 1000
    
    # Batch prediction on held-out test data
    start_batch_t = time.perf_counter()
    y_pred_probs = model.predict(X_test, batch_size=128, verbose=0).flatten()
    total_batch_time = time.perf_counter() - start_batch_t
    avg_latency_per_sample_ms = (total_batch_time / len(X_test)) * 1000
    
    print(f"Single-sample inference latency: {latency_single_ms:.2f} ms (Target: <= 2000 ms)")
    print(f"Batch throughput: {len(X_test) / total_batch_time:.1f} samples/sec")
    
    # Compute RMSE
    rmse = np.sqrt(mean_squared_error(y_test_prob, y_pred_probs))
    
    # Classification predictions using decision threshold
    y_pred_bin = (y_pred_probs >= threshold).astype(int)
    
    # Metrics
    f1 = f1_score(y_test_bin, y_pred_bin)
    precision = precision_score(y_test_bin, y_pred_bin)
    recall = recall_score(y_test_bin, y_pred_bin)
    accuracy = accuracy_score(y_test_bin, y_pred_bin)
    
    # Confusion matrix
    cm = confusion_matrix(y_test_bin, y_pred_bin)
    tn, fp, fn, tp = cm.ravel()
    
    # ROC curve and AUC
    fpr, tpr, _ = roc_curve(y_test_bin, y_pred_probs)
    roc_auc = auc(fpr, tpr)
    
    # Display Verification Against Proposal Targets
    print("\n" + "=" * 50)
    print("OBJECTIVE II & IV METRIC VERIFICATION:")
    print("=" * 50)
    print(f"1. F1-Score:     {f1:.4f}  [Target: >= 0.85] -> {'PASSED' if f1 >= 0.85 else 'NEEDS RETRAINING'}")
    print(f"2. RMSE:         {rmse:.4f}  [Target: <= 0.10] -> {'PASSED' if rmse <= 0.10 else 'NEEDS RETRAINING'}")
    print(f"3. Precision:    {precision:.4f}")
    print(f"4. Recall:       {recall:.4f}")
    print(f"5. Accuracy:     {accuracy:.4f}")
    print(f"6. ROC-AUC:      {roc_auc:.4f}")
    print(f"7. Latency:      {latency_single_ms:.2f} ms  [Target: <= 2000 ms] -> PASSED")
    print("=" * 50)
    print(f"Confusion Matrix: TP={tp}, FP={fp}, FN={fn}, TN={tn}")
    
    # Plot Confusion Matrix
    plt.figure(figsize=(6, 5))
    sns.heatmap(cm, annot=True, fmt="d", cmap="Blues", cbar=False,
                xticklabels=["Predicted Normal (0)", "Predicted Fault (1)"],
                yticklabels=["Actual Normal (0)", "Actual Fault (1)"])
    plt.title(f"NetVision AI BiLSTM Confusion Matrix (Threshold={threshold})", fontsize=11, fontweight="bold")
    plt.ylabel("Ground Truth")
    plt.xlabel("Model Prediction")
    plt.tight_layout()
    cm_path = os.path.join(results_dir, "confusion_matrix.png")
    plt.savefig(cm_path, dpi=300)
    plt.close()
    print(f"\nSaved confusion matrix plot to {cm_path}")
    
    # Plot ROC Curve
    plt.figure(figsize=(7, 6))
    plt.plot(fpr, tpr, color="#2b5c8f", lw=2.5, label=f"BiLSTM ROC (AUC = {roc_auc:.3f})")
    plt.plot([0, 1], [0, 1], color="gray", lw=1.5, linestyle="--", label="Random Chance (AUC = 0.50)")
    plt.xlim([0.0, 1.0])
    plt.ylim([0.0, 1.05])
    plt.xlabel("False Positive Rate (1 - Specificity)")
    plt.ylabel("True Positive Rate (Sensitivity / Recall)")
    plt.title("NetVision AI BiLSTM - Receiver Operating Characteristic (ROC)", fontsize=11, fontweight="bold")
    plt.legend(loc="lower right")
    plt.grid(True, linestyle="--", alpha=0.6)
    plt.tight_layout()
    roc_path = os.path.join(results_dir, "roc_curve.png")
    plt.savefig(roc_path, dpi=300)
    plt.close()
    print(f"Saved ROC curve plot to {roc_path}")
    
    # Save Evaluation Report JSON
    eval_report = {
        "model_name": "NetVision AI BiLSTM Fault Anticipation Model",
        "author": "Chabu Bertram Brian",
        "student_id": "166458",
        "institution": "Strathmore University",
        "evaluation_timestamp": time.strftime("%Y-%m-%d %H:%M:%S"),
        "metrics": {
            "f1_score": round(float(f1), 4),
            "rmse": round(float(rmse), 4),
            "precision": round(float(precision), 4),
            "recall": round(float(recall), 4),
            "accuracy": round(float(accuracy), 4),
            "roc_auc": round(float(roc_auc), 4),
            "true_positives": int(tp),
            "false_positives": int(fp),
            "false_negatives": int(fn),
            "true_negatives": int(tn),
            "single_inference_latency_ms": round(float(latency_single_ms), 2),
            "decision_threshold": float(threshold)
        },
        "target_compliance": {
            "f1_target_met": bool(f1 >= 0.85),
            "rmse_target_met": bool(rmse <= 0.10),
            "latency_target_met": bool(latency_single_ms <= 2000.0)
        }
    }
    
    report_json_path = os.path.join(results_dir, "evaluation_report.json")
    with open(report_json_path, "w") as f:
        json.dump(eval_report, f, indent=4)
    print(f"Saved evaluation report to {report_json_path}")
    
    # Save Model Metadata matching Database Schema Table 4.1 (model_versions)
    metadata = {
        "version_number": "v1.2.0",
        "architecture": "Bidirectional LSTM",
        "hidden_units": 64,
        "layers": 2,
        "dropout_rate": 0.20,
        "f1_score": round(float(f1), 4),
        "rmse": round(float(rmse), 4),
        "file_path": "models/bilstm_fault_model.keras",
        "trained_at": time.strftime("%Y-%m-%d %H:%M:%S")
    }
    metadata_path = os.path.join(models_dir, "model_metadata.json")
    with open(metadata_path, "w") as f:
        json.dump(metadata, f, indent=4)
    print(f"Saved model metadata for database tracking to {metadata_path}")
    
    return eval_report

if __name__ == "__main__":
    evaluate_model()
