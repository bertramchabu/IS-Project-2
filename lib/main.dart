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
          scaffoldBackgroundColor: const Color(0xFF070B14),
          useMaterial3: true,
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xC9121B2B),
            foregroundColor: Color(0xFFF1F5F9),
            surfaceTintColor: Colors.transparent,
            elevation: 0,
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: const Color(0xFF111C2C).withValues(alpha: 0.72),
            labelStyle: const TextStyle(color: Color(0xFFB5C3D8)),
            hintStyle: const TextStyle(color: Color(0xFF7789A3)),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: 0.12),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: 0.14),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF00D9FF), width: 1.4),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFFF5577)),
            ),
          ),
          cardTheme: CardThemeData(
            color: const Color(0xCC152033),
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
            ),
          ),
          dialogTheme: DialogThemeData(
            backgroundColor: const Color(0xF2111928),
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: Colors.white.withValues(alpha: 0.14)),
            ),
          ),
          snackBarTheme: SnackBarThemeData(
            backgroundColor: const Color(0xF2111928),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
            ),
          ),
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