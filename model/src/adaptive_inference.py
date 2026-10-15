"""
adaptive_inference.py - Adaptive Rate Prediction Controller
Project: NetVision AI (Strathmore University)
Author: Bertram Chabu (166458, BBIT 4C)

Fulfills Specific Objective iii & Functional Requirement FR-BE-05 / FR-BE-08:
- Default fault detection threshold: 70% (0.70)
- Visual / Audio alert triggering within 2 seconds
- Adaptive computational reduction: When fault probability < 30% (0.30),
  prediction frequency is reduced by 90% (e.g. inference every 10 seconds
  instead of every 1 second), saving 90% of computational effort during normal operation.
- Immediate ramp-up to 1-second interval as soon as degradation precursors emerge (>= 30%).
"""

import time
from typing import Dict, Any, Optional

class AdaptiveThresholdController:
    """
    Dynamically throttles inference workload based on current network health probability,
    implementing energy-efficient edge/cloud inference (Storey, 2025; Catalin, 2026).
    """
    def __init__(
        self,
        alert_threshold: float = 0.70,
        reduction_threshold: float = 0.30,
        reduction_percentage: int = 90,
        base_interval_sec: float = 1.0
    ):
        self.alert_threshold = alert_threshold
        self.reduction_threshold = reduction_threshold
        self.reduction_percentage = reduction_percentage
        self.base_interval_sec = base_interval_sec
        
        # Reduced sampling step: if 90% reduction, sample every 10 cycles
        self.skip_cycles = int(100 / (100 - reduction_percentage)) # 10 cycles
        self.cycle_counters = {} # node_id -> counter
        self.last_probabilities = {} # node_id -> float
        self.last_states = {} # node_id -> str
        
    def should_execute_inference(self, node_id: str) -> bool:
        """
        Determines whether the BiLSTM model should perform forward inference
        in the current 1-second cycle for the specified node.
        """
        if node_id not in self.cycle_counters:
            self.cycle_counters[node_id] = 0
            self.last_probabilities[node_id] = 0.0
            return True
        
        last_prob = self.last_probabilities.get(node_id, 0.0)
        self.cycle_counters[node_id] += 1
        
        # If network node is healthy (< 30% probability), throttle inference
        if last_prob < self.reduction_threshold:
            if self.cycle_counters[node_id] % self.skip_cycles == 0:
                return True
            return False
        else:
            # Under elevated probability (>= 30%), execute full 1-second inference
            return True
            
    def process_prediction_result(
        self,
        node_id: str,
        probability: float,
        inference_latency_ms: float
    ) -> Dict[str, Any]:
        """
        Processes computed fault probability, checks alert thresholds,
        and determines operational mode.
        """
        self.last_probabilities[node_id] = probability
        
        # Status determination
        if probability >= self.alert_threshold:
            status = "CRITICAL_ALERT"
            severity = "HIGH"
            alert_triggered = True
            message = f"CRITICAL: High fault probability ({probability:.1%}) exceeds threshold ({self.alert_threshold:.1%})!"
        elif probability >= self.reduction_threshold:
            status = "WARNING"
            severity = "MEDIUM"
            alert_triggered = False
            message = f"WARNING: Degradation precursor detected ({probability:.1%}). Sampling at full 1s frequency."
        else:
            status = "HEALTHY"
            severity = "NORMAL"
            alert_triggered = False
            message = f"HEALTHY: Fault probability ({probability:.1%}) < {self.reduction_threshold:.1%}. Computational load reduced by {self.reduction_percentage}%."
            
        self.last_states[node_id] = status
        
        # Determine next sampling interval
        next_interval = self.base_interval_sec * self.skip_cycles if status == "HEALTHY" else self.base_interval_sec
        
        return {
            "node_id": node_id,
            "fault_probability": round(float(probability), 4),
            "status": status,
            "severity": severity,
            "alert_triggered": alert_triggered,
            "inference_latency_ms": round(float(inference_latency_ms), 2),
            "latency_compliant": bool(inference_latency_ms <= 2000.0),
            "next_sampling_interval_sec": next_interval,
            "computational_savings_percent": self.reduction_percentage if status == "HEALTHY" else 0,
            "message": message,
            "timestamp": time.time()
        }

if __name__ == "__main__":
    controller = AdaptiveThresholdController()
    print("Testing Adaptive Controller with simulated probability changes:")
    simulated_probs = [0.05, 0.08, 0.12, 0.28, 0.35, 0.55, 0.76, 0.88, 0.60, 0.20, 0.05]
    for p in simulated_probs:
        res = controller.process_prediction_result("Node-A", p, 12.5)
        print(f"Prob: {p:0.2f} -> Status: {res['status']}, Load Reduction: {res['computational_savings_percent']}%, Next Interval: {res['next_sampling_interval_sec']}s")
