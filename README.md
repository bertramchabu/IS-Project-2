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

Sign in as a network administrator and open the dashboard. Predictions start
from the selected node's Firestore telemetry; the bundled CSV is not replayed
automatically. Use **LIVE REPLAY** in the app bar to opt in to a local chart
demonstration. Replay samples are sent to the authenticated cloud BiLSTM with a
synthetic demo node ID and demo-only flag; replay predictions are not stored as
production prediction records. When the fault model crosses its alert
threshold, the app writes a clearly labeled `[SIMULATION]` alert and invokes
the configured administrator notifications. Choose **STOP REPLAY** to resume
the selected node's Firestore telemetry. The CSV contains four locations, so
only the first four active Firebase locations in sorted order can be replayed.

The updated Firebase model functions are deployed for isolated replay
inference. If the model is unavailable or the deployment is stale, the
dashboard still shows the replayed KPI stream and displays the inference
error instead of substituting a fake prediction.

## Run the cloud threat-model simulation

Choose **LIVE REPLAY** on the Network Admin dashboard to exercise both models
in the same clearly labeled replay session: the fault model receives its
time-aligned 10-step KPI sequence, while the threat model receives three
parallel synthetic aggregate-flow scenarios. The inputs satisfy each
model's own schema; the KPI CSV is not misrepresented as raw flow telemetry.
Open **Threat monitoring** to view the cloud model output, or use **Run
synthetic demo** to run the threat scenarios again. The selected threat
classifier and availability-risk model were trained and evaluated using
synthetic windows;
their inference responses are simulation-only, may abstain as `UNKNOWN`, and
are not stored as prediction records or treated as production detections. If
either cloud model flags an anomaly, the app creates a regular alert explicitly
titled `[SIMULATION]` and the configured administrator notification flow
delivers it. The alert is persisted in the normal alert collection so it
appears in the alert feed; the
synthetic feature windows and model assessments themselves are not persisted.
This demo does not connect a production flow collector or establish real-world
detection quality.
Both cloud inference callables require an active Network or System
Administrator profile. Firestore access remains role-restricted.

While **LIVE REPLAY** is active, the threat results and model-detected
simulation alerts are also summarized on the dashboard and are available
from the shield icon or compact dashboard menu.

Network and System Administrators also get a threat-model status card on their
dashboards, with model/dataset version, input size, forecast horizon, status
refresh, and a direct synthetic-demo action. This model is a fixed simulation
artifact; online retraining and production enablement are not available.

## Manage alerts, audit trail, and exports

The updated `predict_fault` callable persists each prediction and its hashed
forensic record. When the fault threshold is crossed, it creates an alert in
`networkNodes/{nodeId}/alerts`; an active alert of the same severity for the
same node suppresses duplicates for five minutes. Open **Manage alerts** from
the dashboard alert panel to filter by
status, severity, node, or search text, sort the queue, acknowledge, dismiss with
a required reason, resolve, or bulk-acknowledge alerts. The toolbar can enable an
in-app notification when a new active alert arrives. After deploying
`functions:default`, active network and system administrators can also receive
Android and browser Firebase Cloud Messaging notifications for fault alerts and
availability/operational threat assessments. Device tokens are stored under the
signed-in user's profile, and invalid tokens are removed after delivery
failures. The full alert page can
enable an audio chime for newly active critical alerts (browsers only allow
sound after a click, so the toggle itself plays the first chime), and **Export
CSV** saves the currently visible rows. Web uses foreground in-app
notifications and browser push. On the web dashboard, select the notification
bell and allow the browser permission; push then works in the foreground and
while the page is in the background. Browser push requires a supported browser,
an HTTPS deployment, and the deployed `firebase-messaging-sw.js` service worker.
Users can revoke permission in their browser's site settings.

Every acknowledge, dismiss, resolve, threshold change, user or node edit, and
retrain request is appended to the `auditLogs` collection. The system
administrator view renders that stream live, exports it to CSV, shows real model
health from the `model_status` callable, probes Firebase Auth, Firestore, and KPI
telemetry recency, reads and writes the global thresholds in `systemConfig`, and
queues retrain requests in `retrainRequests`.

Deploy the declared indexes before using these queries:
`firebase deploy --only firestore:indexes --project netvision-ai-0`.

System administrators create accounts through the authenticated
`create_managed_user` callable. It creates the Firebase Auth account and
matching UID-keyed Firestore profile, writes an audit entry, then the app sends
the user a password-setup email. Enable Email/Password sign-in and configure
the Firebase Auth email template in the Firebase console before using account
provisioning. Callable access is limited to active system administrators;
fault inference is limited to active network and system administrators.

## Deploy the BiLSTM model function

The `model` Firebase Functions codebase runs the TFLite model and scaler from
`model/models/`. It exposes authenticated `model_status` and `predict_fault`
callables and the system-admin-only `create_managed_user` callable in
`us-central1`; the Flutter client uses Firebase Auth tokens through the Cloud
Functions SDK. Before deploying, make sure the trained files
`bilstm_fault_model.tflite`, `scaler.joblib`, and `model_metadata.json` are
present under `model/models/`, then deploy the model codebase:

```powershell
firebase deploy --only functions:model --project netvision-ai-0
```

The model codebase contains the BiLSTM fault predictor plus a selected
simulation-only threat classifier and availability-risk model. The threat
callable rejects non-demo windows and performs no Firestore writes.

Deploy the built Flutter web app and Firebase configuration with:

```powershell
flutter build web --release
firebase deploy --only hosting,firestore:rules,firestore:indexes,functions:default,functions:model --project netvision-ai-0
```

The configured Hosting rewrite serves the Flutter web application for
client-side routes. Build an Android package with
`flutter build apk --release`; test notification permission and delivery on a
physical Android device signed in as an active network or system administrator.

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
