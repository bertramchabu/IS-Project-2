"""
app.py - FastAPI Real-Time Model Inference & Alerting API
  - POST /predict: Predicts fault probability from a 10-step sequence of 5 KPIs
  - POST /predict/live-metric: Ingests 1-second single metric reading, updates buffer, runs adaptive inference
  - GET /model/metadata: Model architecture, version, F1-score, RMSE
  - GET /health: API health and ready status
"""

import os
import sys
import time
import joblib
import numpy as np
from typing import List, Dict, Any, Optional
from pydantic import BaseModel, Field
from fastapi import FastAPI, HTTPException
import os
from fastapi.middleware.cors import CORSMiddleware
from tensorflow import keras

# Add project root to sys.path
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from src.adaptive_inference import AdaptiveThresholdController

app = FastAPI(
    title="NetVision AI - Network Fault Anticipation API",
    description="High-performance BiLSTM inference service with adaptive load reduction for Flutter dashboard integration.",
    version="1.2.0"
)

# Enable CORS for Flutter Web Dashboard
allowed_origins = [
    origin.strip()
    for origin in os.environ.get(
        "FASTAPI_ALLOWED_ORIGINS",
        "http://localhost:8000",
    ).split(",")
    if origin.strip()
]
app.add_middleware(
    CORSMiddleware,
    allow_origins=allowed_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Global variables
model = None
scaler = None
adaptive_controller = None
node_buffers = {} # node_id -> list of KPI dicts
WINDOW_SIZE = 10
FEATURE_COLS = ["latency", "jitter", "packet_loss", "retransmission_rate", "signal_strength"]

# Models
class KPIMeasurement(BaseModel):
    latency: float = Field(..., description="Latency in ms")
    jitter: float = Field(..., description="Jitter in ms")
    packet_loss: float = Field(..., description="Packet loss percentage (%)")
    retransmission_rate: float = Field(..., description="Retransmission rate percentage (%)")
    signal_strength: float = Field(..., description="Signal strength in dBm")

class LiveKPIRequest(BaseModel):
    node_id: str
    timestamp: Optional[str] = None
    kpis: KPIMeasurement

class SequencePredictionRequest(BaseModel):
    node_id: str
    sequence: List[KPIMeasurement] = Field(..., min_items=10, max_items=10)

class PredictionResponse(BaseModel):
    node_id: str
    fault_probability: float
    status: str
    severity: str
    alert_triggered: bool
    inference_latency_ms: float
    next_sampling_interval_sec: float
    computational_savings_percent: int
    message: str

@app.on_event("startup")
def load_artifacts():
    global model, scaler, adaptive_controller
    base_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
    model_path = os.path.join(base_dir, "models", "bilstm_fault_model.keras")
    scaler_path = os.path.join(base_dir, "models", "scaler.joblib")
    
    if os.path.exists(model_path) and os.path.exists(scaler_path):
        model = keras.models.load_model(model_path)
        scaler = joblib.load(scaler_path)
        print("Loaded BiLSTM model and scaler successfully.")
    else:
        print("Warning: Model or scaler files not found. Train the model first.")
        
    adaptive_controller = AdaptiveThresholdController(
        alert_threshold=0.70,
        reduction_threshold=0.30,
        reduction_percentage=90
    )

@app.get("/health")
def health_check():
    return {
        "status": "online",
        "model_loaded": model is not None,
        "scaler_loaded": scaler is not None,
        "framework": "TensorFlow 2.21 / Keras 3.15",
        "service": "NetVision AI Anticipation Engine"
    }

@app.get("/model/metadata")
def get_model_metadata():
    base_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
    metadata_path = os.path.join(base_dir, "models", "model_metadata.json")
    if os.path.exists(metadata_path):
        import json
        with open(metadata_path, "r") as f:
            return json.load(f)
    return {
        "version_number": "v1.2.0",
        "architecture": "Bidirectional LSTM (2x64 units, Dropout 0.2, Sigmoid)",
        "features": FEATURE_COLS
    }

@app.post("/predict", response_model=PredictionResponse)
def predict_sequence(req: SequencePredictionRequest):
    if model is None or scaler is None:
        raise HTTPException(status_code=503, detail="Model artifacts not yet loaded.")
    
    # Check adaptive controller
    execute = adaptive_controller.should_execute_inference(req.node_id)
    if not execute:
        last_prob = adaptive_controller.last_probabilities.get(req.node_id, 0.05)
        result = adaptive_controller.process_prediction_result(req.node_id, last_prob, inference_latency_ms=0.1)
        return result
        
    # Extract features matrix (10, 5)
    raw_seq = np.array([[m.latency, m.jitter, m.packet_loss, m.retransmission_rate, m.signal_strength] for m in req.sequence])
    scaled_seq = scaler.transform(raw_seq)
    input_tensor = np.expand_dims(scaled_seq, axis=0) # (1, 10, 5)
    
    start_t = time.perf_counter()
    pred = model.predict(input_tensor, verbose=0)
    latency_ms = (time.perf_counter() - start_t) * 1000
    
    fault_prob = float(pred[0][0])
    result = adaptive_controller.process_prediction_result(req.node_id, fault_prob, latency_ms)
    return result

@app.post("/predict/live-metric", response_model=PredictionResponse)
def ingest_live_metric(req: LiveKPIRequest):
    """
    Ingests 1-second metric stream for a node, maintaining sliding window buffer.
    """
    if req.node_id not in node_buffers:
        node_buffers[req.node_id] = []
        
    node_buffers[req.node_id].append(req.kpis)
    if len(node_buffers[req.node_id]) > WINDOW_SIZE:
        node_buffers[req.node_id].pop(0)
        
    # If buffer not yet filled, pad or return initial normal state
    if len(node_buffers[req.node_id]) < WINDOW_SIZE:
        return {
            "node_id": req.node_id,
            "fault_probability": 0.02,
            "status": "INITIALIZING",
            "severity": "NORMAL",
            "alert_triggered": False,
            "inference_latency_ms": 0.0,
            "next_sampling_interval_sec": 1.0,
            "computational_savings_percent": 0,
            "message": f"Buffering KPI sequence ({len(node_buffers[req.node_id])}/{WINDOW_SIZE} timesteps)"
        }
        
    seq_req = SequencePredictionRequest(node_id=req.node_id, sequence=node_buffers[req.node_id])
    return predict_sequence(seq_req)

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="127.0.0.1", port=8000)
