"""
model.py - BiLSTM Neural Network Architecture for Fault Anticipation
Project: NetVision AI (Strathmore University)
Author: Bertram Chabu (166458, BBIT 4C)

Architecture adheres strictly to Proposal Section 3.2.3:
- Input layer: accepting multivariate sequences of 5 KPIs (latency, jitter, packet loss, retransmission rate, signal strength)
- Two BiLSTM hidden layers (each with 64 units)
- Dropout layer (rate 0.2 for regularization)
- Dense output layer with sigmoid activation producing fault probability [0, 1]
- Lightweight export to TensorFlow Lite (.tflite) for edge-responsive inference
"""

import os
import tensorflow as tf
from tensorflow import keras
from keras import layers, models, metrics

def build_bilstm_model(
    window_size: int = 10,
    num_features: int = 5,
    hidden_units: int = 64,
    dropout_rate: float = 0.2,
    learning_rate: float = 0.001
) -> keras.Model:
    """
    Constructs the NetVision AI BiLSTM model according to proposal specifications.
    
    Parameters:
    - window_size: Time steps in each historical sequence window.
    - num_features: Number of multivariate KPIs (default: 5).
    - hidden_units: BiLSTM hidden units per layer (default: 64).
    - dropout_rate: Dropout regularization rate (default: 0.2).
    - learning_rate: Adam optimizer learning rate.
    """
    inputs = layers.Input(shape=(window_size, num_features), name="kpi_sequence_input")
    
    # Hidden Layer 1: Bidirectional LSTM with sequence return
    x = layers.Bidirectional(
        layers.LSTM(hidden_units, return_sequences=True),
        name="bilstm_layer_1"
    )(inputs)
    
    # Hidden Layer 2: Bidirectional LSTM returning final state
    x = layers.Bidirectional(
        layers.LSTM(hidden_units, return_sequences=False),
        name="bilstm_layer_2"
    )(x)
    
    # Regularization: Dropout layer
    x = layers.Dropout(dropout_rate, name="dropout_regularization")(x)
    
    # Output Layer: Dense sigmoid activation for fault probability [0, 1]
    outputs = layers.Dense(1, activation="sigmoid", name="fault_probability_output")(x)
    
    model = models.Model(inputs=inputs, outputs=outputs, name="NetVision_BiLSTM_Fault_Anticipator")
    
    optimizer = keras.optimizers.Adam(learning_rate=learning_rate)
    
    model.compile(
        optimizer=optimizer,
        loss="binary_crossentropy",
        metrics=[
            "accuracy",
            metrics.RootMeanSquaredError(name="rmse"),
            metrics.Precision(name="precision"),
            metrics.Recall(name="recall")
        ]
    )
    
    return model

def export_to_tflite(model: keras.Model, output_tflite_path: str):
    """
    Exports a runtime-compatible TFLite model without Select TensorFlow ops.
    """
    inputs = layers.Input(shape=model.input_shape[1:], name="kpi_sequence_input")
    x = inputs

    for layer_name in ("bilstm_layer_1", "bilstm_layer_2"):
        source_layer = model.get_layer(layer_name)
        lstm_config = source_layer.forward_layer.get_config()
        lstm_config["unroll"] = True
        x = layers.Bidirectional(
            layers.LSTM.from_config(lstm_config),
            merge_mode=source_layer.merge_mode,
            name=layer_name,
        )(x)

    x = layers.Dropout(
        model.get_layer("dropout_regularization").rate,
        name="dropout_regularization",
    )(x)
    outputs = layers.Dense.from_config(
        model.get_layer("fault_probability_output").get_config()
    )(x)
    tflite_model = keras.Model(inputs, outputs, name=model.name)
    tflite_model.set_weights(model.get_weights())

    converter = tf.lite.TFLiteConverter.from_keras_model(tflite_model)
    converter.target_spec.supported_ops = [tf.lite.OpsSet.TFLITE_BUILTINS]
    tflite_model = converter.convert()
    
    os.makedirs(os.path.dirname(output_tflite_path), exist_ok=True)
    with open(output_tflite_path, "wb") as f:
        f.write(tflite_model)
    print(f"Exported TFLite model successfully to: {output_tflite_path}")

if __name__ == "__main__":
    netvision_model = build_bilstm_model()
    netvision_model.summary()
