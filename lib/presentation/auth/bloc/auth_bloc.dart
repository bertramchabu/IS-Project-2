import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../data/repositories/auth_repository.dart';
import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository _repo;

  AuthBloc(this._repo) : super(const AuthInitial()) {
    on<AuthCheckRequested>(_onCheckRequested);
    on<AuthLoginRequested>(_onLoginRequested);
    on<AuthLogoutRequested>(_onLogoutRequested);
    on<AuthProfileUpdateRequested>(_onProfileUpdateRequested);
  }

  Future<void> _onCheckRequested(
    AuthCheckRequested event,
    Emitter<AuthState> emit,
  ) async {
    final user = _repo.currentUser;
    if (user == null) {
      return emit(const AuthUnauthenticated());
    }

    final profile = await _repo.getUserProfile(user.uid);
    if (profile == null || !profile.isActive) {
      await _repo.signOut();
      return emit(const AuthUnauthenticated());
    }

    emit(AuthAuthenticated(profile));
  }

  Future<void> _onLoginRequested(
    AuthLoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());

    try {
      final cred = await _repo.signIn(
        email: event.email,
        password: event.password,
      );

      final profile = await _repo.getUserProfile(cred.user!.uid);

      if (profile == null) {
        return emit(const AuthError('User profile not found.'));
      }

      if (!profile.isActive) {
        await _repo.signOut();
        return emit(const AuthError('Account is deactivated. Contact admin.'));
      }

      emit(AuthAuthenticated(profile));
    } catch (err) {
      print(err);
      emit(AuthError(_mapError(err)));
    }
  }

  Future<void> _onLogoutRequested(
    AuthLogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    await _repo.signOut();
    emit(const AuthUnauthenticated());
  }

  Future<void> _onProfileUpdateRequested(
    AuthProfileUpdateRequested event,
    Emitter<AuthState> emit,
  ) async {
    final current = state;
    if (current is! AuthAuthenticated) return;

    try {
      final updated = await _repo.updateUserProfile(
        userId: current.user.userId,
        username: event.username,
        department: event.department,
        phoneNumber: event.phoneNumber,
        mfaEnabled: event.mfaEnabled,
      );
      emit(AuthAuthenticated(updated));
    } catch (err) {
      // Keep authenticated with current user on error
      emit(AuthAuthenticated(current.user));
    }
  }

  String _mapError(Object e) {
    final s = e.toString();
    if (s.contains('user-not-found')) return 'No account found with that email.';
    if (s.contains('wrong-password')) return 'Incorrect password.';
    if (s.contains('invalid-email')) return 'Invalid email format.';
    if (s.contains('user-disabled')) return 'This account has been disabled.';
    if (s.contains('too-many-requests')) {
      return 'Too many attempts. Try again later.';
    }
    if (s.contains('network-request-failed')) {
      return 'No network connection. Check your internet.';
    }
    return 'Authentication failed. Please try again.';
  }
}