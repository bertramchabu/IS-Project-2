import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../data/repositories/auth_repository.dart';
import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository _repo;

  AuthBloc(this._repo) : super(const AuthInitial()) {
    on<AuthCheckRequested>(_onCheckRequested);
    on<AuthLoginRequested>(_onLoginRequested);
    on<AuthPasswordResetRequested>(_onPasswordResetRequested);
    on<AuthLogoutRequested>(_onLogoutRequested);
    on<AuthProfileUpdateRequested>(_onProfileUpdateRequested);
  }

  @override
  void onError(Object error, StackTrace stackTrace) {
    print('[AuthBloc] Unhandled error: $error');
    super.onError(error, stackTrace);
  }

  Future<void> _onCheckRequested(
    AuthCheckRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthChecking());
    try {
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
    } catch (error) {
      print('[AuthBloc] Failed to restore session: $error');
      emit(AuthError('Unable to verify your session. Please try again.'));
    }
  }

  Future<void> _onLoginRequested(
    AuthLoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    UserCredential? credential;

    try {
      credential = await _repo.signIn(
        email: event.email,
        password: event.password,
      );

      final signedInUser = credential.user;
      if (signedInUser == null) {
        throw StateError('Firebase sign-in completed without a user.');
      }
      final profile = await _repo.getUserProfile(signedInUser.uid);

      if (profile == null) {
        await _repo.signOut();
        print('[AuthBloc] Login failed: user profile not found.');
        return emit(const AuthError('User profile not found.'));
      }

      if (!profile.isActive) {
        await _repo.signOut();
        print('[AuthBloc] Login blocked: account is deactivated.');
        return emit(const AuthError('Account is deactivated. Contact admin.'));
      }

      try {
        await _repo.recordSuccessfulLogin(profile.userId);
      } catch (error) {
        print('[AuthBloc] Could not update last-login timestamp: $error');
      }
      emit(AuthAuthenticated(profile));
    } catch (err) {
      print('[AuthBloc] Login failed: $err');
      final signedInUid = credential?.user?.uid;
      if (signedInUid != null && _repo.currentUser?.uid == signedInUid) {
        try {
          await _repo.signOut();
        } catch (signOutError) {
          print('[AuthBloc] Could not clear incomplete login: $signOutError');
          emit(const AuthError(
            'Sign-in could not finish and the session could not be cleared. '
            'Please restart the app and try again.',
          ));
          return;
        }
      }
      emit(AuthError(_mapError(err)));
    }
  }

  Future<void> _onPasswordResetRequested(
    AuthPasswordResetRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthPasswordResetting());
    try {
      await _repo.sendPasswordResetEmail(event.email);
      emit(const AuthPasswordResetSent());
    } catch (error) {
      print('[AuthBloc] Password reset failed: $error');
      emit(AuthError(_mapError(error)));
    }
  }

  Future<void> _onLogoutRequested(
    AuthLogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    try {
      await _repo.signOut();
      emit(const AuthUnauthenticated());
    } catch (error) {
      print('[AuthBloc] Logout failed: $error');
      final current = state;
      emit(AuthError(
        'Unable to sign out. Please try again.',
        user: current is AuthAuthenticated ? current.user : null,
      ));
    }
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
      print('[AuthBloc] Profile update failed: $err');
      emit(AuthError(
        'Unable to update your profile. Please try again.',
        user: current.user,
      ));
    }
  }

  String _mapError(Object e) {
    final s = e.toString();
    if (s.contains('user-not-found'))
      return 'No account found with that email.';
    if (s.contains('wrong-password')) return 'Incorrect password.';
    if (s.contains('invalid-email')) return 'Invalid email format.';
    if (s.contains('user-disabled')) return 'This account has been disabled.';
    if (s.contains('too-many-requests')) {
      return 'Too many attempts. Try again later.';
    }
    if (s.contains('network-request-failed')) {
      return 'No network connection. Check your internet.';
    }
    if (s.contains('permission-denied')) {
      return 'Signed in, but unable to load your account profile. '
          'Check your account access and try again.';
    }
    return 'Authentication failed. Please try again.';
  }
}
