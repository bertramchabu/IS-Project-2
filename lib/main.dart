import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:netvision_ai/presentation/dashboard/bloc/kpi_bloc.dart';

import 'firebase_options.dart';
import 'di/service_locator.dart' as di;
import 'core/router/app_router.dart';
import 'presentation/auth/bloc/auth_bloc.dart';
import 'presentation/auth/bloc/auth_event.dart';
import 'presentation/auth/bloc/auth_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await di.init();
  runApp(const NetVisionApp());
}

class NetVisionApp extends StatelessWidget {
  const NetVisionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>(
          create: (_) => di.sl<AuthBloc>()..add(const AuthCheckRequested()),
        ),
        BlocProvider<KpiBloc>(
          create: (_)=> di.sl<KpiBloc>(),
        ),
      ],
      child: MaterialApp(
        title: 'NetVision AI',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.dark,
          colorSchemeSeed: Colors.cyan,
          useMaterial3: true,
        ),
        home: BlocListener<AuthBloc, AuthState>(
          listenWhen: (_, state) => state is AuthError && state.user != null,
          listener: (context, state) {
            if (state is AuthError) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(state.message)),
              );
            }
          },
          child: BlocBuilder<AuthBloc, AuthState>(
            builder: (context, state) => AppRouter.route(state),
          ),
        ),
      ),
    );
  }
}