import 'package:equatable/equatable.dart';
import 'package:netvision_ai/data/models/user_models.dart';


abstract class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

/// Initial state before any check has run.
class AuthInitial extends AuthState {
  const AuthInitial();
}

/// While login or check is in progress.
class AuthLoading extends AuthState {
  const AuthLoading();
}

class AuthChecking extends AuthState {
  const AuthChecking();
}

class AuthPasswordResetting extends AuthState {
  const AuthPasswordResetting();
}

class AuthPasswordResetSent extends AuthState {
  const AuthPasswordResetSent();
}

/// User is signed in and profile loaded.
class AuthAuthenticated extends AuthState {
  final UserModel user;

  const AuthAuthenticated(this.user);

  @override
  List<Object?> get props => [user];
}

/// No user is signed in.
class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated();
}

/// An error occurred during login or profile load.
class AuthError extends AuthState {
  final String message;
  final UserModel? user;

  const AuthError(this.message, {this.user});

  @override
  List<Object?> get props => [message, user];
}

UserModel? authenticatedUserFrom(AuthState state) {
  if (state is AuthAuthenticated) return state.user;
  if (state is AuthError) return state.user;
  return null;
}