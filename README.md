# NetVision AI

Flutter/Firebase network-monitoring dashboard with live KPI telemetry and
BiLSTM fault anticipation through authenticated Firebase callable functions.

## Run the Flutter app

From the repository root, install the Flutter dependencies and run the app:

```powershell
flutter pub get
flutter run
```

Firebase must be configured for the target platform. The dashboard provides
role-specific views for network administrators, ICT managers, and system
administrators. Network-node records and KPI documents are read from Firestore.

## Deploy the BiLSTM model function

The `model` Firebase Functions codebase runs the TFLite model and scaler from
`model/models/`. It exposes authenticated `model_status` and `predict_fault`
callables in `us-central1`; the Flutter client uses Firebase Auth tokens through
the Cloud Functions SDK. Before deploying, make sure the trained files
`bilstm_fault_model.tflite`, `scaler.joblib`, and `model_metadata.json` are
present under `model/models/`, then deploy the model codebase:

```powershell
firebase deploy --only functions:model --project netvision-ai-0
```

Cloud Functions deployment requires the Firebase project to use the Blaze
pay-as-you-go plan and have billing enabled. The model codebase is configured
for Python 3.11 and TensorFlow Lite, with a 512 MiB memory limit and at most five
instances. Deploy the existing Node.js functions separately with
`firebase deploy --only functions:default --project netvision-ai-0`.

Each prediction request contains a complete ten-timestep window of five aligned
metrics: latency, jitter, packet loss, retransmission rate, and signal strength.
The client builds this window from recent Firestore KPI documents, so inference
does not depend on in-memory state shared between function instances. The gauge
shows a buffering status until ten complete samples are available. If the
function is unavailable, live monitoring continues and model-based predictions
are marked unavailable. For healthy predictions below 30% fault probability,
the client follows the model response and reduces inference requests to one per
10 seconds; at elevated risk it resumes one-second inference.
