# NetVision AI Application Documentation

**Application:** NetVision AI
**Repository:** bertramchabu/IS-Project-2
**Primary platform:** Flutter Web and Android
**Document scope:** Implemented application behavior, architecture, data design, AI components, operations, security, deployment, testing, and limitations

## 1. Executive Summary

NetVision AI is an intelligent network-monitoring dashboard that combines Firebase
authentication and cloud services with two machine-learning/simulation components:

1. A Bidirectional LSTM (BiLSTM) model for fault anticipation from five network
   KPIs over a ten-timestep window.
2. A simulation-only threat-monitoring pipeline that generates synthetic flow
   windows and predicts availability or operational threats.

The application presents role-specific dashboards for Network Administrators,
System Administrators, and ICT Managers. It provides live and replayed KPI
visualization, a fault gauge, topology and location views, alert management,
browser and Android notifications, audit logging, reporting, system-health
checks, user and node administration, model status, retraining requests, and
synthetic threat monitoring.

NetVision AI is not a complete production network-management or network
detection platform. It currently depends on selected Firebase records and
bundled demonstrations, while the threat model is explicitly restricted to
synthetic use.

## 2. Application Objectives

The implemented application is designed to:

- Anticipate network faults before they become visible in simple threshold
  monitoring.
- Present KPI and prediction information in dashboards tailored to operational
  and management roles.
- Allow administrators to acknowledge, dismiss, resolve, filter, export, and
  receive notifications for alerts.
- Provide system administrators with account, node, threshold, model, health,
  audit, and retraining controls.
- Produce management reports in PDF and CSV formats.
- Demonstrate adaptive inference behavior that reduces prediction rate during
  nominal conditions.
- Demonstrate synthetic threat classification without representing it as
  production traffic detection.
- Retain audit and forensic information for user and configuration actions.

## 3. Supported Roles and Privileges

Firebase user profiles are stored under `users/{uid}` and identify one of three
roles:

| Role ID | Display role | Implemented access |
|---|---|---|
| `role_network_admin` | Network Administrator | Main monitoring dashboard, KPI and node views, live replay, fault/threat inference, threat page, alert management, push notifications |
| `role_system_admin` | System Administrator | All network-admin monitoring capabilities plus user management, node registration, threshold controls, model management, retraining requests, health probes, and audit-log access |
| `role_ict_manager` | ICT Manager | Management/reporting dashboard, persisted KPI/prediction reporting, model status, and PDF/CSV export |

The application routes authenticated users to a role-specific home page. It
restores an existing session through Firebase Auth, verifies the matching
Firestore profile, and refuses inactive or missing-profile accounts.

Role checks are implemented in both the Flutter UI and server-side Firebase
callables. Firestore rules also require active profiles and enforce
role-specific reads and writes. Unknown role IDs default to Network
Administrator in the Flutter model parser, while server-side validation and
Firestore rules should remain the authoritative security boundary.

## 4. High-Level Architecture

```text
Flutter Web / Android
  |-- Firebase Auth
  |-- Firestore real-time streams
  |-- Firebase Cloud Functions callables
  |-- Firebase Cloud Messaging
  `-- Local CSV replay and chart/demo services

Firebase
  |-- Authentication
  |-- Firestore
  |-- Hosting
  |-- Callable Functions
  |-- Cloud Messaging
  `-- Node.js document-trigger notifications

Python model codebase
  |-- TFLite/BiLSTM fault model
  |-- Scaler and metadata
  |-- Synthetic threat artifacts
  `-- Dataset and evaluation scripts

Optional local FastAPI service
  `-- Keras/BiLSTM REST inference and live-metric buffering
```

The Flutter application follows a layered repository, dependency-injection,
Bloc, and presentation structure:

- `lib/main.dart`: Firebase initialization, dependency setup, app theme, global
  navigation keys, and push-notification startup.
- `lib/core`: routing and platform utilities.
- `lib/di`: GetIt service registration.
- `lib/data/models`: typed data structures for users, nodes, KPIs, predictions,
  alerts, and threat records.
- `lib/data/repositories`: Firebase Auth, Firestore, alert, prediction, model,
  threat, audit, and notification access.
- `lib/services`: replay, simulation, threat rules, feature aggregation,
  classification, audio, and notifications.
- `lib/presentation`: authentication, dashboards, alerts, threat monitoring,
  widgets, and Bloc state management.

## 5. Technology Stack

### Flutter

- Flutter/Dart
- `flutter_bloc` for state management
- `get_it` for dependency injection
- `equatable` for state/data equality
- `fl_chart` for KPI line charts
- `google_maps_flutter` for node topology/location
- `pdf` and `printing` for report export
- `csv` for CSV parsing and export
- `intl` for dates and formatting
- `crypto` for forensic hashes in Dart-side threat evidence
- `path_provider` and `permission_handler` for exports on supported platforms

### Firebase

- Firebase Core and Auth
- Cloud Firestore
- Cloud Functions
- Firebase Messaging
- Firebase Hosting
- Firebase Storage dependency is installed but is not a primary implemented
  application workflow

### AI and Python

- TensorFlow/Keras for training and the optional local API
- TensorFlow Lite runtime for the deployed Firebase callable
- scikit-learn for scaling and threat evaluation
- NumPy and joblib for inference and artifact loading
- FastAPI and Uvicorn for optional local REST serving
- pytest/unittest for Python tests

### Telemetry Collector

The repository includes `model/collector/agent.py`, an on-ramp for real KPI
collection. It probes TCP connection latency and derives jitter, TCP packet-loss
rate and retransmission state. Signal strength is optional and is omitted cleanly
when unavailable. `--dry-run` prints samples and performs no writes.

Real writes require `NETVISION_COLLECTOR_KEY` to reference a Firebase service
account file or `FIREBASE_EMULATOR=1`. Samples are written to
`networkNodes/{nodeId}/kpiMetrics/{metricId}` with `source=collector`.

The collector has not yet been used to establish a production dataset or real
incident ground truth. The dashboard still also uses operator-entered Firestore
telemetry, CSV replay and deterministic simulation.

## 6. Application Startup and Session Flow

At startup, Flutter initializes Firebase using the generated platform-specific
`DefaultFirebaseOptions`, initializes GetIt dependencies, creates the root
application, restores the signed-in session if possible, and starts the push
notification service asynchronously.

The authentication flow is:

1. Firebase Auth signs in with email and password.
2. The matching `users/{uid}` profile is loaded.
3. The profile must exist and have `isActive != false`.
4. Successful login updates `lastLogin`.
5. The app routes to the role-specific dashboard.
6. Logout removes the current device push token and signs out of Firebase Auth.

Password reset sends a Firebase password-reset email. Account provisioning is
performed only by a system administrator through an authenticated callable.

## 7. Network Monitoring

### 7.1 Node inventory

Network nodes are Firestore documents at `networkNodes/{nodeId}`. A node contains:

- Name and IP address
- Node type: router, switch, gateway, access point, or firewall
- Status: healthy, warning, critical, or unknown
- Geographic coordinates or GeoPoint
- Region and zone
- Active/inactive state
- Registration and modification timestamps
- Registered-by information

The Network Administrator dashboard watches all active node inventory and KPI
streams. The System Administrator view allows node registration and status
updates.

### 7.2 KPI data

The monitoring model uses five metrics:

| Metric | Internal ID | Unit | Purpose |
|---|---|---|:---|
| Latency | `latency` | ms | Response delay |
| Jitter | `jitter` | ms | Variation in timing |
| Packet loss | `packet_loss` | % | Lost packet proportion |
| Retransmission rate | `retransmission_rate` | % | Repeated packet proportion |
| Signal strength | `signal_strength` | dBm | Link quality |

Firestore stores recent metrics under:

```text
networkNodes/{nodeId}/kpiMetrics/{metricId}
```

Each metric includes its type, value, unit, timestamp, source, and optional
quality label. Sources include simulated, CSV replay, API, and file upload.

The KPI repository subscribes to the latest document of each metric type.
The dashboard groups received values into an aligned ten-timestep window. Only
a window with all five metric types at each timestep is sent to the fault
model.

### 7.3 KPI visualization

The Network Administrator dashboard provides:

- Selected-node navigation
- Live KPI line charts
- Latest-value and quality views
- Fault gauge
- Node-map/topology view
- Active alert panel
- Replay controls
- Threat-model summary
- Model-status card
- Browser notification controls

The topology view supports geographic markers and in-app node selection. Web and
Android use platform-specific map implementations/configuration.

## 8. BiLSTM Fault Anticipation

### 8.1 Model architecture

The fault model is a two-layer Bidirectional LSTM with 64 hidden units per
direction and dropout at 0.20. The final sigmoid output returns a fault
probability from zero to one.

Deployed artifacts are:

- `model/models/bilstm_fault_model.tflite`
- `model/models/scaler.joblib`
- `model/models/model_metadata.json`
- `model/models/bilstm_fault_model.keras` for Keras tooling/local use

The deployed Firebase Python function loads the TFLite interpreter and scaler,
validates the input shape, scales each sequence, and executes inference.

### 8.2 Input contract

`predict_fault` requires:

- An authenticated active Network or System Administrator
- A non-empty node ID
- Exactly ten samples
- Exactly five finite numeric fields per sample:
  `latency`, `jitter`, `packet_loss`, `retransmission_rate`, and
  `signal_strength`
- An explicit UTC input timestamp
- A valid `demo_only` Boolean

Production node IDs must not begin with `SYNTHETIC-DEMO-`. Replay inference must
use that prefix and is not persisted as a production prediction.

### 8.3 Model response

The callable returns:

- Fault probability
- Severity
- Alert-triggered flag
- Status message
- Inference latency
- Model version
- Scaler version
- Threshold configuration version
- Input timestamp
- Next sampling interval
- Computed reduction value
- Prediction ID and persistence status

Production predictions are persisted under:

```text
networkNodes/{nodeId}/predictions/{predictionId}
```

The callable also writes a hashed forensic fault-inference record and creates
an alert when the fixed alert threshold is crossed.

The deployed function returns:

- Normal below 30% probability
- Warning from 30% to below 70%
- Critical/high alert at 70% or above

### 8.4 Adaptive inference

The intended adaptive behavior is:

- Nominal probability below 30%: run one inference per 10 seconds.
- Elevated probability at or above 30%: reduce the interval toward one second.
- Critical alert probability at or above 70%: raise a model alert.

The local FastAPI implementation includes an adaptive controller. The Flutter
client also honors the `next_sampling_interval_sec` returned by the Firebase
callable, so its prediction loop changes based on server response.

### 8.5 Runtime threshold configuration

The System Administrator threshold page writes:

- `globalThreshold`
- `adaptiveReductionEnabled`
- `reductionThreshold`
- `reductionPercentage`

to `systemConfig/thresholds`.

The page loads and saves settings through the system-admin-only
`get_thresholds` and `set_thresholds` callables. The server validates each
setting, records who changed it, and assigns a timestamp-based configuration
version. `predict_fault` reads the same document and includes the active version
in prediction and forensic records. Warm function instances cache settings for
up to 60 seconds; missing or invalid configuration falls back to validated
defaults. The defaults are:

- Alert threshold: 70%
- Warning/reduction threshold: 30%
- Healthy interval: 10 seconds
- Adaptive reduction: enabled, with a reported 90% reduction.

When adaptive reduction is disabled, healthy predictions keep one-second
sampling and report no computational savings. Warning and alert thresholds
remain active independently of the adaptive sampling setting.

## 9. CSV Replay and Demo Behavior

Live replay reads `model/data/network_kpi_dataset.csv`, containing sorted source
locations and the five KPI fields. The app loads the first four locations in
source-ID order and maps them to the first four active Firebase nodes sorted by
node name, with node ID as a tie-breaker.

The 33-device organizational network described in the research report is an
evaluation scenario, not preloaded Firestore content. Demo nodes must be
registered in the configured Firebase project; the CSV provides four local
telemetry source locations and does not create node or KPI documents.

When replay is active:

- Firestore metric subscriptions are suppressed.
- KPI values are generated locally once per second.
- Fault sequences are sent to `predict_fault` with `demo_only = true`.
- Results are labeled as replay or simulation.
- Replay predictions are not written to production prediction collections.
- Replay fault alerts are labeled `[SIMULATION]`.
- Synthetic threat scenarios are generated in parallel.
- Normal monitoring resumes when replay is stopped.

The replay CSV is demonstration data, not a substitute for a production data
collector.

## 10. Threat-Monitoring Component

### 10.1 Scope and limitations

The threat-monitoring feature is deliberately simulation-only. It does not
connect to a production flow collector and does not establish real-world
detection quality.

The dataset builder uses CIC-IDS2017 flow rows only as numeric source profiles.
It creates synthetic:

- 60-second windows
- Node and service identifiers
- Timestamps
- Service-health outcomes
- Operational-fault labels
- Synthetic dataset splits

Therefore, a result in this system should be described as a pipeline
demonstration rather than validated production cyberattack detection.

### 10.2 Threat features

The synthetic feature window includes 27 ordered values covering:

- Packets, bytes, and flow-start rates
- Inbound/outbound ratio
- Concurrent and total connections
- Failed and incomplete connections
- Average connection duration
- TCP, UDP, ICMP, and other protocol proportions
- Destination port concentration
- TCP SYN, ACK, RST, and FIN counts
- Source/destination entropy
- Destination share
- Success, error, and timeout rates
- 95th-percentile latency
- Queue saturation

Cloud threat inference accepts only windows containing
`synthetic_demo`, synthetic node IDs, synthetic service IDs, and matching
synthetic timing fields.

### 10.3 Threat outputs

The threat callable can classify each window as:

- `BENIGN`
- `AVAILABILITY_ANOMALY`
- `OPERATIONAL_FAULT`
- `UNKNOWN`

It also provides:

- Confidence
- A 10-minute availability risk forecast
- Out-of-distribution status
- An uncertainty reason
- Model and dataset version

An `UNKNOWN` response can indicate model abstention or out-of-distribution
input. The cloud threat callable is explicitly non-persisting.

### 10.4 Synthetic replay

The demo replay runs three scenarios:

1. A normal/benign scenario.
2. An availability anomaly scenario.
3. An operational-fault scenario.

If the cloud model detects an availability or operational anomaly, the app
creates a regular `[SIMULATION]` alert in the normal alert collection.
The synthetic feature window and model assessment are not persisted during this
cloud replay path.

The rules-only fallback can still produce demonstrations locally, but it is
clearly separate from the cloud model. The package must not imply that local
rules equal model inference.

## 11. Alert Management

Alerts are stored beneath the affected node:

```text
networkNodes/{nodeId}/alerts/{alertId}
```

An alert contains:

- Node ID and optional prediction/assessment ID
- Severity
- Status
- Title and description
- Fault probability
- Model version
- Creation, acknowledgment, dismissal, and resolution timestamps
- Acknowledging user and dismissal reason

Supported statuses are:

- `Active`
- `Acknowledged`
- `Dismissed`
- `Resolved`

### 11.1 Alert lifecycle

Network and System Administrators can:

- Filter by status, severity, node, or free text
- Sort newest, oldest, or severity
- Acknowledge one alert or a bulk selection
- Dismiss with a required reason
- Resolve alerts
- Export the currently visible alert queue to CSV

Every lifecycle action writes an audit entry.

### 11.2 Duplicate suppression

The application suppresses duplicate model alerts of the same severity and
model version for the same node for five minutes. Simulation and production
alerts are treated separately.

### 11.3 In-app notification behavior

The alert page can enable an audio chime for critical alerts. Browsers only
allow audio after a user interaction, so the user toggle itself is used to
establish the first allowed chime.

The app also tracks newly active alerts and can display foreground Snackbar or
browser notifications.

## 12. Push Notifications

The Node.js Firebase Functions code monitors document creation for:

- `networkNodes/{nodeId}/alerts/{alertId}`
- `threatAssessments/{assessmentId}`

Notifications are sent to active Network and System Administrator profiles.
Device tokens are stored beneath:

```text
users/{uid}/devices/{deviceId}
```

Supported platforms are Android and web. Invalid Firebase Messaging tokens are
removed. The web service worker is `web/firebase-messaging-sw.js`.

Notification delivery:

- Works in-app for foreground Flutter web sessions
- Supports browser push on HTTPS deployments with notification permission
- Supports Android FCM delivery on a physical device
- Uses a Node.js document-trigger function

## 13. System Administrator Features

The System Administrator dashboard contains five main areas:

### 13.1 User management

- Live user directory
- Add managed Firebase Auth users
- Create matching UID-keyed Firestore profiles
- Assign Network Administrator, ICT Manager, or System Administrator roles
- Activate or deactivate accounts
- Change user roles
- Send password-setup/reset email where configured
- Record user-management actions in `auditLogs`

### 13.2 Network node management

- Live node table
- Register nodes
- Capture name, IP address, type, status, region, zone, and location
- Update active status
- Record node registration/status changes in the audit log

### 13.3 Threshold and resource policies

- Fault alert threshold slider, bounded at 50%-95%
- Adaptive resource toggle
- Reduction trigger bounded at 10% to below the alert threshold
- Reduction percentage bounded at 50%-95%
- Healthy sampling interval bounded at 1-60 seconds
- Effective values loaded through the system-admin-only `get_thresholds` callable
- Writes through the system-admin-only `set_thresholds` callable
- Persistence to `systemConfig/thresholds`
- Timestamp-derived `thresholds-v<updatedAtUnix>` version stamping
- Threshold audit entry

The `predict_fault` callable loads effective threshold values at runtime with a
60-second cache. Missing or malformed configuration falls back to 70% alert,
30% reduction trigger, 90% reduction and a 10-second healthy interval.

### 13.4 Model management

- Live model status
- Model version
- Architecture and input dimensions
- Holdout F1 and RMSE
- Callable health latency
- Threat-model status
- Synthetic threat demo launch
- Firestore retraining request queue
- Live latest-request status banner for queued, in-progress, completed or failed states
- System-admin callable `process_retrain_request`
- Subprocess execution of `src.train` followed by `src.evaluate`
- Completed requests include F1, RMSE and artifact SHA-256 values
- Failed requests include stderr truncated to 4KB

Retraining requests are written to `retrainRequests`. They do not automatically
execute cloud retraining. The Python training pipeline must be run separately
by an operator.

### 13.5 Audit and system health

The system view:

- Streams audit logs
- Exports audit logs to CSV
- Checks Firebase Auth
- Checks a Firestore round trip
- Calls `model_status`
- Calls the threat-model status endpoint
- Checks recent telemetry freshness
- Shows model and cloud-service health

## 14. ICT Manager Reporting

The ICT Manager dashboard provides management reporting rather than operational
alert administration.

Available report types include:

- Executive Reliability Summary
- AI Fault Anticipation Audit
- Network SLA Compliance Report
- Incident and Outage Prevention Log

Date windows include:

- Last 24 hours
- Last 7 days
- Last 30 days
- Quarter to date

Reports combine:

- Persisted KPI samples
- Persisted predictions
- Active node count
- Model status and metadata
- KPI averages and ranges
- Prediction counts and critical event counts

Outputs include:

- PDF reports
- CSV KPI and prediction exports

Exports use persisted records in the selected time range. Empty data may still
produce a CSV with no result rows or an explicit report state.

## 15. Cloud Functions

Firebase defines two function codebases.

### 15.1 Node.js `default`

Configured in `functions/index.js`:

- `notifyOnNetworkAlert`
- `notifyOnThreatAssessment`
- Firebase Admin initialization
- FCM multicast delivery
- Device-token invalidation
- Admin recipient filtering

### 15.2 Python `model`

Configured in `model/main.py`:

| Callable | Required role | Purpose |
|---|---|---|
| `create_managed_user` | System Administrator | Create Auth account and Firestore profile |
| `model_status` | Active signed-in user | Load/return fault-model status |
| `predict_fault` | Network or System Administrator | Run TFLite fault inference |
| `threat_model_status` | Network or System Administrator | Load/return synthetic threat-model status |
| `predict_threat` | Network or System Administrator | Run synthetic threat inference |

Callable requests use Firebase Auth ID tokens. The Python functions enforce
roles independently of Flutter and Firestore rules.

The optional local FastAPI API exposes:

- `POST /predict`
- `POST /predict/live-metric`
- `GET /model/metadata`
- `GET /health`

It is not the main deployed Flutter inference path.

## 16. Firestore Data Model

### 16.1 Main collections

| Collection/path | Purpose |
|---|---|
| `users/{uid}` | Profiles and roles |
| `users/{uid}/devices/{deviceId}` | FCM web/Android device tokens |
| `networkNodes/{nodeId}` | Node inventory |
| `networkNodes/{nodeId}/kpiMetrics/{metricId}` | KPI records |
| `networkNodes/{nodeId}/predictions/{predictionId}` | Production fault predictions |
| `networkNodes/{nodeId}/alerts/{alertId}` | Model and simulation alerts |
| `systemConfig/thresholds` | UI/system threshold state |
| `auditLogs/{logId}` | Security and administrative audit trail |
| `retrainRequests/{requestId}` | Offline retraining queue |
| `threatFeatureWindows/{windowId}` | Persisted threat feature windows for applicable ingestion |
| `threatAssessments/{assessmentId}` | Threat assessments |
| `forensicEvidence/{evidenceId}` | Forensic payloads and hashes |

### 16.2 Audit log

Audit entries contain:

- Acting user ID
- Display name
- Action
- Detail text
- Timestamp

Typical actions include acknowledge, dismiss, resolve, threshold changes,
account changes, node changes, retraining requests, threat lifecycle events,
threat evidence exports, and model actions.

### 16.3 Threat forensic records

Threat evidence support includes canonical JSON payload serialization and
SHA-256 hashing. Forensic records cover fault inference, threat inference,
alert events, administrative actions, configuration changes, and model promotion.
Evidence collection read access is restricted to system administrators.

## 17. Security and Authorization

### Authentication

- Firebase Email/Password Auth
- Session restoration
- Active-profile checks
- Password-reset email
- Optional managed user setup workflow

### Firestore

Rules enforce:

- Signed-in access
- Active `isActive` profile checks
- System Administrator account/node/config/audit control
- Network/System Administrator alert access
- Role-restricted alert creation and updates
- Restricted device-token writes
- Immutable forensic and threat evidence records
- Restricted threat lifecycle collections
- Collection-group read conditions for appropriate active roles

### Cloud callables

Callables independently verify Firebase Auth and Firestore role documents.
Fault and threat inference require active Network or System Administrator
profiles. Account creation requires a System Administrator.

### Security considerations

- The local development `allow_origins=["*"]` setting applies to the optional
  FastAPI service and is not the Firebase callable boundary.
- Browser map API keys and Firebase web settings must be restricted and
  configured separately for deployments.
- The app stores FCM device tokens only in the signed-in user's device
  subcollection.
- The threat and replay features are limited to simulation-only inputs.
- The system currently validates runtime role and active status; it should not
  rely on an unknown-role fallback for authorization.
- Any future threshold or retraining automation should add server-side validation
  and preserve audit/configuration versioning.

## 18. Model Evaluation and Performance

### 18.1 Fault model

The bundled model metadata and documentation report:

| Measure | Recorded value |
|---|---:|
| Model version | `v1.2.0` |
| F1-score | 0.8593 |
| RMSE | 0.0197 |
| Architecture | 2x64-unit BiLSTM |
| Dropout | 0.20 |

Evaluation scripts calculate F1, precision, recall, accuracy, RMSE, ROC-AUC,
confusion matrices, and plots.

The comparative script also reports a row-level baseline F1 of 0.9308 and a
10-step windowed NetVision F1 of 0.8593. It states that these scores are not
directly comparable because the baseline is row-level and the BiLSTM is
window-based and designed to anticipate thresholds. The documentation should
not claim that the BiLSTM outperformed the baseline solely from those F1
numbers.

The recorded project targets include:

- F1 >= 0.85
- RMSE <= 0.10
- Inference latency <= 2 seconds
- Adaptive 90% load reduction below 30% probability
- SUS target >= 70

The `README` records a SUS figure and one comparative latency/lead-time result,
but final quality claims must continue to cite the exact dataset, evaluation
script, and run date.

### 18.2 Threat model

The threat component has a separate synthetic evaluation pipeline:

- CIC flow profile sampling
- Synthetic window generation
- Calibrated tree classification
- Availability-risk modeling
- Out-of-distribution detection
- 95% bootstrap and Wilson-style reporting
- Macro F1 and per-class metrics
- Risk precision/recall and PR-AUC
- Explicit simulation-only packaging

The threat artifacts are hash-pinned. A cloud result must be reported with
simulation-only qualification.

## 19. Testing

### Flutter tests

The `test/` directory includes tests for:

- Alert notification tracking
- Application error logging
- CSV replay and CSV utilities
- Demo telemetry simulation
- Fault gauge
- Model inference repository behavior
- Network node parsing
- Threat decision and rules engines
- Threat feature aggregation
- Threat demo replay

The tests cover important parsing, replay, aggregation, and state behavior,
but they do not prove production network detection quality or end-to-end
Firebase deployment behavior.

### Python tests

`model/tests/` covers:

- Synthetic threat dataset/data generation
- Threat-model evaluation
- Managed-user validation
- UTC timestamp validation
- Network/System role access
- Threat feature vector shape and synthetic-only restrictions
- Hash-pinned threat artifact loading
- Candidate and risk model inference

Run Flutter tests with:

```powershell
flutter test
```

Run Python threat/model tests from `model`:

```powershell
py -m unittest discover -s tests -v
```

## 20. Build and Deployment

### Flutter dependencies

```powershell
flutter pub get
```

### Local Flutter run

```powershell
flutter run
```

Configure Firebase for Android and web and ensure the deployed profile and
Firebase rules match.

### Android

- Set `googleMapsApiKey` in `android/local.properties`, or provide
  `GOOGLE_MAPS_API_KEY`
- Enable the Android Maps SDK for the key
- Configure `android/app/google-services.json`
- Test FCM notifications on a physical device

### Web

- Build for release
- Configure the web Maps API key
- Restrict it to deployment origins
- Enable HTTPS
- Confirm `firebase-messaging-sw.js` is deployed
- Allow notification permission in the browser

### Firestore

Deploy rules and indexes:

```powershell
firebase deploy --only firestore:rules,firestore:indexes --project netvision-ai-0
```

### Node.js notifications

```powershell
firebase deploy --only functions:default --project netvision-ai-0
```

### Python model callables

Before deployment, confirm the TFLite fault artifacts and threat artifacts exist
under `model/models/`, then run:

```powershell
firebase deploy --only functions:model --project netvision-ai-0
```

The model codebase is configured for Python 3.11, 512 MiB memory, and at most
five instances. Firebase Python Functions deployment requires the applicable
Firebase billing plan.

### Hosting

```powershell
flutter build web --release
firebase deploy --only hosting --project netvision-ai-0
```

A combined deployment can include Hosting, Firestore, and both function
codebases.

## 21. Optional Local FastAPI Service

The local API loads `bilstm_fault_model.keras` and `scaler.joblib`, maintains
per-node sliding windows, and exposes live-metric buffering.

Run:

```powershell
& .\model\.venv\Scripts\python.exe -m pip install -r model\api\requirements.txt
& .\model\.venv\Scripts\python.exe -m uvicorn api.app:app --app-dir model --host 127.0.0.1 --port 8000
```

Use the Python 3.11 model environment for the packaged threat artifacts. They
were serialized with scikit-learn 1.4.2; the cloud requirements pin that
version, while other versions may not be able to load the files.

Swagger documentation is available at:

```text
http://127.0.0.1:8000/docs
```

This service is separate from deployed Firebase callable inference.

## 22. Repository Structure

```text
lib/
  main.dart
  firebase_options.dart
  core/
  data/
  di/
  presentation/
  services/

model/
  main.py
  api/
  data/
  models/
  results/
  src/
  tests/
  README.md

functions/
  index.js
  package.json

test/
docs/
assets/
web/
android/
```

## 23. Operational Workflows

### Operator monitoring

1. Sign in as Network or System Administrator.
2. Select a network node.
3. Observe live KPIs and the model gauge.
4. Wait for ten aligned KPI samples before inference is available.
5. Review normal/warning/critical model status.
6. Open alert management for active, acknowledged, dismissed, or resolved items.

### CSV demonstration

1. Sign in as Network Administrator.
2. Select an eligible node.
3. Start LIVE REPLAY.
4. Watch the KPI stream and replay fault/threat results.
5. Observe any `[SIMULATION]` alerts.
6. Stop replay to restore Firestore telemetry.

### Alert response

1. Filter the alert queue.
2. Acknowledge relevant alerts.
3. Add a dismissal reason if dismissing.
4. Resolve completed incidents.
5. Export the visible queue when needed.

### User provisioning

1. Sign in as System Administrator.
2. Open User Management.
3. Add a user with username, email, role, and department.
4. The callable creates Firebase Auth and the UID-keyed profile.
5. Configure Firebase email templates and send password setup/reset as required.

### Retraining request

1. Open Model Management.
2. Review deployed model status.
3. Request retraining.
4. A Firestore `retrainRequests` record and audit entry are created.
5. An operator runs the Python training pipeline outside the automatic app flow.

### Management reporting

1. Sign in as ICT Manager.
2. Choose report type and date range.
3. Load KPI/prediction data.
4. Export PDF or CSV.

## 24. Known Constraints and Limitations

1. Invalid or unavailable threshold configuration falls back to defaults, and
   warm inference instances can retain effective values for up to 60 seconds.
2. Retraining can now be invoked through `process_retrain_request`, but a real
   executed training run was not verified in this environment. The runner dry-run
   is verified and full execution remains a Firebase/runtime operation.
3. The threat model is synthetic and cannot be treated as production threat
   detection.
4. Threat replay creates `[SIMULATION]` alerts but does not persist replay feature
   windows or assessments through the cloud demo path.
5. The CSV replay is limited to the locations represented in the bundled CSV
   and to the first four active nodes.
6. Live production telemetry ingestion is not implemented as a full network
   collector.
7. The app primarily reads operator-entered Firestore nodes and KPI records.
8. Model status and inference depend on deployed callable/model artifacts.
9. MFA is represented as a profile field but is not a complete production MFA
   implementation.
10. System health checks are dashboard probes, not a separate monitoring
    agent/SLA engine.
11. Cross-browser push behavior depends on HTTPS, browser support, Firebase
    configuration, and notification permission.
12. Reports cover records stored in the selected Firestore time window.
13. Baseline and BiLSTM F1 comparisons use different prediction units and must
    not be interpreted as a direct fairness claim.

## 25. Recommended Future Enhancements

- Expose the healthy sampling interval as an editable system-administrator setting.
- Show the active threshold configuration version in the administration view.
- Add a real telemetry collector and gateway integration.
- Connect retraining requests to an authenticated training job or CI pipeline.
- Promote trained threat models only after realistic, production-signed
  validation.
- Add automated Firebase emulator and security-rules tests.
- Add end-to-end Flutter tests for role routing, replay, alerts, and push setup.
- Add metrics retention policies, node/KPI archival, and backup procedures.
- Strengthen MFA and account lifecycle workflows.
- Add row-level model explainability or KPI contribution information.
- Add real service/SLA APIs rather than health probe approximations.
- Add formal incident integration and assignment workflows.
- Separate synthetic model UI states from live production health views more
  strongly.

## 26. Maintenance Checklist

Before a production or demonstration release:

- Confirm Firebase project IDs and generated configuration.
- Confirm Firestore rules and indexes are deployed.
- Confirm Android and web Maps API restrictions.
- Confirm FCM service worker and platform setup.
- Confirm fault and threat model artifacts are present and hash-valid.
- Confirm the model metadata matches the deployed TFLite artifact.
- Confirm Firebase Auth email/password sign-in is enabled.
- Confirm active profiles exist for all test accounts.
- Confirm no synthetic replay is presented as production telemetry.
- Run Flutter tests and analyzer.
- Run Python unit tests and the relevant evaluation scripts.
- Review audit and alert duplicate behavior.
- Build Android and web release artifacts.
- Test notification delivery on physical Android and supported HTTPS web clients.

## 27. Primary Source Files

- Application entry point: `lib/main.dart`
- Dependency injection: `lib/di/service_locator.dart`
- Role routing: `lib/core/router/app_router.dart`
- Firestore rules: `firestore.rules`
- Firestore indexes: `firestore.indexes.json`
- Firebase deployment config: `firebase.json`
- Node notification functions: `functions/index.js`
- Python cloud callables: `model/main.py`
- Fault model metadata: `model/models/model_metadata.json`
- FastAPI service: `model/api/app.py`
- Training entry point: `model/src/train.py`
- Fault evaluation: `model/src/evaluate.py`
- Threat dataset: `model/src/threat_monitor_data.py`
- Threat evaluation: `model/src/threat_model_evaluation.py`
- Flutter setup documentation: `README.md`
- Existing generated Word documentation: `docs/NetVision_AI_Final_Documentation.docx`
