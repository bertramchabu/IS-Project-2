import 'package:get_it/get_it.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../data/repositories/auth_repository.dart';
import '../data/repositories/node_repository.dart';
import '../data/repositories/kpi_repository.dart';
import '../data/repositories/alert_repository.dart';
import '../data/repositories/audit_repository.dart';
import '../data/repositories/prediction_repository.dart';
import '../data/repositories/model_inference_repository.dart';
import '../data/repositories/threat_repository.dart';
import '../data/repositories/threat_model_inference_repository.dart';
import '../services/threat_detection/rules_engine.dart';
import '../services/threat_detection/threat_classifier.dart';
import '../services/threat_detection/threat_decision_service.dart';
import '../services/threat_features/threat_feature_aggregator.dart';
import '../services/threat_features/threat_ingestion_service.dart';
import '../services/threat_features/threat_demo_replay.dart';
import '../services/push_notification_service.dart';

import '../presentation/auth/bloc/auth_bloc.dart';
import '../presentation/dashboard/bloc/kpi_bloc.dart';
import '../presentation/alerts/bloc/alert_bloc.dart';
import '../presentation/dashboard/bloc/prediction_bloc.dart';
import '../presentation/threat_monitoring/bloc/threat_monitoring_bloc.dart';

final sl = GetIt.instance;

Future<void> init() async {
  // ---------- Firebase singletons ----------
  sl.registerLazySingleton<FirebaseAuth>(() => FirebaseAuth.instance);
  sl.registerLazySingleton<FirebaseFirestore>(() => FirebaseFirestore.instance);

  // ---------- Repositories ----------
  sl.registerLazySingleton<AuthRepository>(
    () => AuthRepository(
      auth: sl<FirebaseAuth>(),
      firestore: sl<FirebaseFirestore>(),
    ),
  );
  sl.registerLazySingleton<PushNotificationService>(
    () => PushNotificationService(
      auth: sl<FirebaseAuth>(),
      firestore: sl<FirebaseFirestore>(),
    ),
  );

  sl.registerLazySingleton<NodeRepository>(
    () => NodeRepository(firestore: sl<FirebaseFirestore>()),
  );

  sl.registerLazySingleton<KpiRepository>(
    () => KpiRepository(firestore: sl<FirebaseFirestore>()),
  );

  sl.registerLazySingleton<AlertRepository>(
    () => AlertRepository(firestore: sl<FirebaseFirestore>()),
  );

  sl.registerLazySingleton<AuditRepository>(
    () => AuditRepository(firestore: sl<FirebaseFirestore>()),
  );
  sl.registerLazySingleton<ThreatRepository>(
    () => ThreatRepository(
      firestore: sl<FirebaseFirestore>(),
      auth: sl<FirebaseAuth>(),
    ),
  );
  sl.registerLazySingleton<ThreatModelInferenceRepository>(
    () => ThreatModelInferenceRepository(
      auth: sl<FirebaseAuth>(),
    ),
  );
  sl.registerLazySingleton<ThreatFeatureAggregator>(
    ThreatFeatureAggregator.new,
  );
  sl.registerLazySingleton<ThreatRulesEngine>(ThreatRulesEngine.new);
  sl.registerLazySingleton<ThreatClassifier>(
    () => const UnavailableThreatClassifier(),
  );
  sl.registerLazySingleton<ThreatDecisionService>(
    () => ThreatDecisionService(
      rulesEngine: sl<ThreatRulesEngine>(),
      classifier: sl<ThreatClassifier>(),
    ),
  );
  sl.registerLazySingleton<ThreatIngestionService>(
    () => ThreatIngestionService(
      aggregator: sl<ThreatFeatureAggregator>(),
      decisionService: sl<ThreatDecisionService>(),
      repository: sl<ThreatRepository>(),
      firestore: sl<FirebaseFirestore>(),
    ),
  );

  sl.registerLazySingleton<PredictionRepository>(
    () => PredictionRepository(firestore: sl<FirebaseFirestore>()),
  );
  sl.registerLazySingleton<ModelInferenceRepository>(
    () => ModelInferenceRepository(auth: sl<FirebaseAuth>()),
  );

  // ---------- Blocs ----------
  sl.registerFactory<AuthBloc>(
    () => AuthBloc(
      sl<AuthRepository>(),
      pushNotifications: sl<PushNotificationService>(),
    ),
  );
  sl.registerFactory<KpiBloc>(
    () => KpiBloc(
      nodeRepo: sl<NodeRepository>(),
      kpiRepo: sl<KpiRepository>(),
    ),
  );
  sl.registerFactory<AlertBloc>(
      () => AlertBloc(sl<AlertRepository>(), audit: sl<AuditRepository>()));
  sl.registerFactory<PredictionBloc>(
    () => PredictionBloc(
      sl<PredictionRepository>(),
      sl<ModelInferenceRepository>(),
      alerts: sl<AlertRepository>(),
    ),
  );
  sl.registerFactory<ThreatMonitoringBloc>(
    () => ThreatMonitoringBloc(
      sl<ThreatRepository>(),
      alerts: sl<AlertRepository>(),
      demoReplay: ThreatDemoReplay(
        modelClassifier: CloudThreatClassifier(
          sl<ThreatModelInferenceRepository>(),
        ),
        decisionService: sl<ThreatDecisionService>(),
      ),
    ),
  );
}
