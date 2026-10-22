import 'package:get_it/get_it.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../data/repositories/auth_repository.dart';
import '../data/repositories/node_repository.dart';
import '../data/repositories/kpi_repository.dart';
import '../data/repositories/alert_repository.dart';
import '../data/repositories/prediction_repository.dart';
import '../data/repositories/model_inference_repository.dart';

import '../presentation/auth/bloc/auth_bloc.dart';
import '../presentation/dashboard/bloc/kpi_bloc.dart';
import '../presentation/alerts/bloc/alert_bloc.dart';
import '../presentation/dashboard/bloc/prediction_bloc.dart';

final sl = GetIt.instance;

Future<void> init() async {
  // ---------- Firebase singletons ----------
  sl.registerLazySingleton<FirebaseAuth>(() => FirebaseAuth.instance);
  sl.registerLazySingleton<FirebaseFirestore>(
      () => FirebaseFirestore.instance);

  // ---------- Repositories ----------
  sl.registerLazySingleton<AuthRepository>(
    () => AuthRepository(
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

  sl.registerLazySingleton<PredictionRepository>(
    () => PredictionRepository(firestore: sl<FirebaseFirestore>()),
  );
  sl.registerLazySingleton<ModelInferenceRepository>(
    () => ModelInferenceRepository(auth: sl<FirebaseAuth>()),
  );

  // ---------- Blocs ----------
  sl.registerFactory<AuthBloc>(() => AuthBloc(sl<AuthRepository>()));
  sl.registerFactory<KpiBloc>(
    () => KpiBloc(
      nodeRepo: sl<NodeRepository>(),
      kpiRepo: sl<KpiRepository>(),
    ),
  );
  sl.registerFactory<AlertBloc>(() => AlertBloc(sl<AlertRepository>()));
  sl.registerFactory<PredictionBloc>(
    () => PredictionBloc(
      sl<PredictionRepository>(),
      sl<ModelInferenceRepository>(),
    ),
  );
}
