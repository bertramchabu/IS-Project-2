import 'package:get_it/get_it.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:netvision_ai/data/repositories/kpi_repository.dart';
import 'package:netvision_ai/data/repositories/node_repository.dart';
import 'package:netvision_ai/presentation/dashboard/bloc/kpi_bloc.dart';


import '../data/repositories/auth_repository.dart';
import '../presentation/auth/bloc/auth_bloc.dart';

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
    ()=> NodeRepository(firestore: sl<FirebaseFirestore>())
  );

  sl.registerLazySingleton<KpiRepository>(
    ()=> KpiRepository(firestore: sl<FirebaseFirestore>())
  );

  // ---------- Blocs ----------
  sl.registerFactory<AuthBloc>(() => AuthBloc(sl<AuthRepository>()));
  sl.registerFactory<KpiBloc>(
    ()=> KpiBloc(
      nodeRepo: sl<NodeRepository>(),
      kpiRepo: sl<KpiRepository>(),
    ),
  );
}