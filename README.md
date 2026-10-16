# NetVision AI

Flutter/Firebase network-monitoring dashboard with live KPI telemetry and
optional BiLSTM fault anticipation through the FastAPI model service.

## Run the Flutter app

From the repository root, install the Flutter dependencies and run the app:

```powershell
flutter pub get
flutter run
```

Firebase must be configured for the target platform. The dashboard provides
role-specific views for network administrators, ICT managers, and system
administrators. Network-node records and KPI documents are read from Firestore.

## Run the model API

The model API is optional; monitoring remains available when the API is offline,
but model-based predictions are shown as unavailable. First install the Python
dependencies used by `model/api/app.py` and make sure the trained model and
scaler exist under `model/models/`. Then, from the `model` directory, start the
service:

```powershell
python -m uvicorn api.app:app --host 0.0.0.0 --port 8000
```

The API health endpoint is `http://127.0.0.1:8000/health`; interactive API
documentation is at `http://127.0.0.1:8000/docs`. For Android emulators the app
defaults to `http://10.0.2.2:8000`; for web and desktop it defaults to
`http://127.0.0.1:8000`. Override the base URL at build/run time when needed:

```powershell
flutter run --dart-define=MODEL_API_BASE_URL=http://<host>:8000
```

The live inference endpoint accepts one combined KPI sample per node. The API
buffers ten samples before returning a prediction, so the model status can show
as initializing while this window fills. The five required values are latency,
jitter, packet loss, retransmission rate, and signal strength.
