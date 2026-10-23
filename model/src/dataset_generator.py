"""

Simulates 5 mandatory network KPIs:
1. Latency (ms)
2. Jitter (ms)
3. Packet Loss (%)
4. Retransmission Rate (%)
5. Signal Strength (dBm)

Implements realistic normal operation, diurnal patterns, random network jitter,
and gradual onset fault precursors (congestion, link degradation, hardware flap).
"""

import numpy as np
import pandas as pd
from datetime import datetime, timedelta

def generate_network_kpi_dataset(
    total_timesteps: int = 15000,
    sampling_rate_seconds: int = 1,
    nodes: list = None,
    fault_ratio: float = 0.18,
    random_seed: int = 42
) -> pd.DataFrame:
    """
    Generates a realistic synthetic multivariate network time-series dataset.
    
    Parameters:
    - total_timesteps: Total 1-second records per node.
    - sampling_rate_seconds: Refresh interval (1s as per Objective I).
    - nodes: List of monitored network nodes.
    - fault_ratio: Approximate ratio of fault events.
    - random_seed: Seed for reproducibility.
    """
    if nodes is None:
        nodes = ["Node-A_CoreSwitch", "Node-B_Gateway", "Node-C_Distribution", "Node-D_AccessPoint"]
    
    np.random.seed(random_seed)
    all_dfs = []
    
    start_time = datetime(2026, 6, 1, 8, 0, 0)
    
    for node_idx, node_name in enumerate(nodes):
        timestamps = [start_time + timedelta(seconds=i * sampling_rate_seconds) for i in range(total_timesteps)]
        
        # Base healthy state distributions
        # Latency: base 25-45ms
        base_latency = 30.0 + 8.0 * np.sin(np.linspace(0, 12 * np.pi, total_timesteps)) + np.random.normal(0, 3.0, total_timesteps)
        base_latency = np.clip(base_latency, 15.0, 50.0)
        
        # Jitter: base 2-6ms
        base_jitter = 3.5 + 1.2 * np.sin(np.linspace(0, 8 * np.pi, total_timesteps)) + np.random.normal(0, 0.8, total_timesteps)
        base_jitter = np.clip(base_jitter, 1.0, 7.0)
        
        # Packet Loss: base 0.0 - 0.4%
        base_loss = np.abs(np.random.normal(0.08, 0.05, total_timesteps))
        base_loss = np.clip(base_loss, 0.0, 0.5)
        
        # Retransmission Rate: base 0.2 - 0.8%
        base_retrans = 0.4 + np.random.normal(0, 0.12, total_timesteps)
        base_retrans = np.clip(base_retrans, 0.1, 0.9)
        
        # Signal Strength: base -55 to -65 dBm
        base_signal = -60.0 + 4.0 * np.sin(np.linspace(0, 4 * np.pi, total_timesteps)) + np.random.normal(0, 2.0, total_timesteps)
        base_signal = np.clip(base_signal, -68.0, -50.0)
        
        # Fault labels and target probabilities
        fault_labels = np.zeros(total_timesteps, dtype=int)
        fault_probability_ground_truth = np.zeros(total_timesteps, dtype=float)
        
        # Inject realistic fault scenarios with gradual onset precursors (Seliem, 2025)
        # Average fault duration: 120 - 300 seconds; Precursor ramp-up: 60 - 120 seconds
        t = 300 # initial warmup
        while t < total_timesteps - 400:
            if np.random.rand() < 0.22:
                fault_type = np.random.choice(["congestion", "link_degradation", "buffer_exhaustion"])
                precursor_len = np.random.randint(45, 90)
                fault_len = np.random.randint(60, 180)
                recovery_len = np.random.randint(30, 60)
                
                total_event_len = precursor_len + fault_len + recovery_len
                if t + total_event_len >= total_timesteps:
                    break
                
                # Precursor phase: progressive ramp-up
                for p in range(precursor_len):
                    prog = (p + 1) / precursor_len
                    fault_probability_ground_truth[t + p] = prog * 0.65
                    # Anticipation label activates in latter half of precursor
                    if prog >= 0.5:
                        fault_labels[t + p] = 1
                    
                    if fault_type == "congestion":
                        base_latency[t + p] += prog * 60.0 + np.random.normal(0, 5)
                        base_jitter[t + p] += prog * 15.0 + np.random.normal(0, 2)
                        base_loss[t + p] += prog * 1.8 + np.random.normal(0, 0.2)
                        base_retrans[t + p] += prog * 4.5 + np.random.normal(0, 0.5)
                    elif fault_type == "link_degradation":
                        base_signal[t + p] -= prog * 25.0 + np.random.normal(0, 2)
                        base_loss[t + p] += prog * 2.5 + np.random.normal(0, 0.3)
                        base_jitter[t + p] += prog * 18.0 + np.random.normal(0, 2)
                        base_latency[t + p] += prog * 40.0 + np.random.normal(0, 4)
                    else:
                        base_latency[t + p] += prog * 85.0 + np.random.normal(0, 8)
                        base_jitter[t + p] += prog * 22.0 + np.random.normal(0, 3)
                        base_retrans[t + p] += prog * 6.0 + np.random.normal(0, 0.6)
                
                # Active Fault phase: high severity
                for f in range(fault_len):
                    fault_probability_ground_truth[t + precursor_len + f] = np.random.uniform(0.85, 0.99)
                    fault_labels[t + precursor_len + f] = 1
                    
                    if fault_type == "congestion":
                        base_latency[t + precursor_len + f] += np.random.uniform(140, 260)
                        base_jitter[t + precursor_len + f] += np.random.uniform(30, 65)
                        base_loss[t + precursor_len + f] += np.random.uniform(4.0, 12.0)
                        base_retrans[t + precursor_len + f] += np.random.uniform(8.0, 18.0)
                    elif fault_type == "link_degradation":
                        base_signal[t + precursor_len + f] -= np.random.uniform(28, 42)
                        base_loss[t + precursor_len + f] += np.random.uniform(6.0, 18.0)
                        base_jitter[t + precursor_len + f] += np.random.uniform(35, 75)
                        base_latency[t + precursor_len + f] += np.random.uniform(110, 220)
                    else:
                        base_latency[t + precursor_len + f] += np.random.uniform(200, 380)
                        base_jitter[t + precursor_len + f] += np.random.uniform(45, 90)
                        base_loss[t + precursor_len + f] += np.random.uniform(5.0, 15.0)
                        base_retrans[t + precursor_len + f] += np.random.uniform(10.0, 22.0)
                
                # Recovery phase: cooling down
                for r in range(recovery_len):
                    prog = 1.0 - ((r + 1) / recovery_len)
                    fault_probability_ground_truth[t + precursor_len + fault_len + r] = prog * 0.45
                    if prog >= 0.7:
                        fault_labels[t + precursor_len + fault_len + r] = 1
                    
                    base_latency[t + precursor_len + fault_len + r] += prog * 40.0
                    base_jitter[t + precursor_len + fault_len + r] += prog * 10.0
                    base_loss[t + precursor_len + fault_len + r] += prog * 1.5
                    base_retrans[t + precursor_len + fault_len + r] += prog * 2.0
                
                t += total_event_len + np.random.randint(180, 500)
            else:
                # Add tiny background noise/spikes (benign spikes that don't constitute a coordinated multi-KPI fault)
                if np.random.rand() < 0.04:
                    base_latency[t] += np.random.uniform(15, 30) # single isolated spike
                t += 1
        
        # Ensure physical boundaries
        base_latency = np.clip(base_latency, 5.0, 500.0)
        base_jitter = np.clip(base_jitter, 0.5, 120.0)
        base_loss = np.clip(base_loss, 0.0, 100.0)
        base_retrans = np.clip(base_retrans, 0.0, 100.0)
        base_signal = np.clip(base_signal, -110.0, -30.0)
        
        node_df = pd.DataFrame({
            "timestamp": timestamps,
            "node_id": node_name,
            "latency": np.round(base_latency, 2),
            "jitter": np.round(base_jitter, 2),
            "packet_loss": np.round(base_loss, 3),
            "retransmission_rate": np.round(base_retrans, 3),
            "signal_strength": np.round(base_signal, 2),
            "fault_label": fault_labels,
            "fault_probability_target": np.round(fault_probability_ground_truth, 4)
        })
        all_dfs.append(node_df)
    
    full_df = pd.concat(all_dfs, ignore_index=True)
    return full_df

def create_sliding_windows(
    df: pd.DataFrame,
    feature_cols: list = None,
    target_col: str = "fault_label",
    target_prob_col: str = "fault_probability_target",
    window_size: int = 10,
    step_size: int = 1
):
    """
    Transforms multivariate time series data into sliding windows for BiLSTM input.
    
    Returns:
    - X: Array of shape (N_samples, window_size, N_features)
    - y_binary: Array of shape (N_samples,)
    - y_prob: Array of shape (N_samples,)
    - timestamps: Array of corresponding window end timestamps
    - node_ids: Array of corresponding node IDs
    """
    if feature_cols is None:
        feature_cols = ["latency", "jitter", "packet_loss", "retransmission_rate", "signal_strength"]
    
    X_list, y_bin_list, y_prob_list = [], [], []
    time_list, node_list = [], []
    
    for node_id, group in df.groupby("node_id"):
        features = group[feature_cols].values
        labels = group[target_col].values
        probs = group[target_prob_col].values
        times = group["timestamp"].values
        
        num_windows = (len(group) - window_size) // step_size + 1
        for i in range(0, len(group) - window_size + 1, step_size):
            X_list.append(features[i : i + window_size])
            y_bin_list.append(labels[i + window_size - 1])
            y_prob_list.append(probs[i + window_size - 1])
            time_list.append(times[i + window_size - 1])
            node_list.append(node_id)
            
    return (
        np.array(X_list, dtype=np.float32),
        np.array(y_bin_list, dtype=np.float32),
        np.array(y_prob_list, dtype=np.float32),
        np.array(time_list),
        np.array(node_list)
    )

if __name__ == "__main__":
    print("Generating simulated network dataset...")
    df = generate_network_kpi_dataset(total_timesteps=5000)
    print(f"Generated {len(df)} records across {df['node_id'].nunique()} nodes.")
    print("Class distribution:\n", df['fault_label'].value_counts(normalize=True))
    print(df.head())
