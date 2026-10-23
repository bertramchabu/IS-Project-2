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
The topology view uses `google_maps_flutter` on web and Android. For Android,
set `googleMapsApiKey` in the ignored `android/local.properties` file or provide
the `GOOGLE_MAPS_API_KEY` environment variable, and enable the Maps SDK for
Android for that key. The web Maps JavaScript API key is configured in
`web/index.html`; enable the Maps JavaScript API and restrict the key to the
deployed web origins.

## Replay location telemetry in live charts

Sign in as a network administrator and open the dashboard. Select a network
node. The dashboard automatically starts replaying the bundled
`model/data/network_kpi_dataset.csv` at one sample per second. CSV
locations are sorted by ID and assigned to active Firebase locations sorted by
name (node ID breaks ties). Replay updates all five charts and sends samples
through the same authenticated BiLSTM callable used for predictions; replay
samples are not written to Firestore. Choose **STOP REPLAY** in the app bar to
resume the selected node's Firestore telemetry. The CSV contains four locations, so only
the first four active Firebase locations in sorted order can be replayed.

The Firebase model functions must be deployed and available for the demo to
show model predictions. If the model is offline, the dashboard still shows the
replayed KPI stream and displays the inference error instead of substituting a
fake prediction.

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

The local FastAPI service is a separate option. It uses the Keras model and has
its own dependencies:

```powershell
py -3.13 -m pip install -r model\api\requirements.txt
py -3.13 -m uvicorn api.app:app --app-dir model --host 127.0.0.1 --port 8000
```

Open `http://127.0.0.1:8000/docs` for its API documentation.

Each prediction request contains a complete ten-timestep window of five aligned
metrics: latency, jitter, packet loss, retransmission rate, and signal strength.
The client builds this window from recent Firestore KPI documents, so inference
does not depend on in-memory state shared between function instances. The gauge
shows a buffering status until ten complete samples are available. If the
function is unavailable, live monitoring continues and model-based predictions
are marked unavailable. For healthy predictions below 30% fault probability,
the client follows the model response and reduces inference requests to one per
10 seconds; at elevated risk it resumes one-second inference.
