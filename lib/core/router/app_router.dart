import 'package:flutter/material.dart';
import 'package:netvision_ai/data/models/user_models.dart';
import '../../presentation/auth/bloc/auth_state.dart';
import '../../presentation/auth/pages/login_page.dart';
import '../../presentation/dashboard/pages/ict_manager_home.dart';
import '../../presentation/dashboard/pages/network_admin_home.dart';
import '../../presentation/dashboard/pages/system_admin_home.dart';

class AppRouter {

  static Widget route(AuthState state) {
    if (state is AuthAuthenticated) {
      return _homeForRole(state.user);
    }
    if (state is AuthError && state.user != null) {
      return _homeForRole(state.user!);
    }
    if (state is AuthInitial || state is AuthChecking) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return const LoginPage();
  }

  static Widget _homeForRole(UserModel user) {
    switch (user.role) {
      case UserRole.networkAdministrator:
        return const NetworkAdminHome();
      case UserRole.ictManager:
        return const ICTManagerHome();
      case UserRole.systemAdministrator:
        return const SystemAdminHome();
      case UserRole.unknown:
        return const _UnknownRoleScreen();
    }
  }


}

class _UnknownRoleScreen extends StatelessWidget {
  const _UnknownRoleScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Your account role is not recognised. Contact your system administrator.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}