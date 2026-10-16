import 'package:equatable/equatable.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

/// Fired at app startup to check if a user is already signed in.
class AuthCheckRequested extends AuthEvent {
  const AuthCheckRequested();
}

/// Fired when the user submits the login form.
class AuthLoginRequested extends AuthEvent {
  final String email;
  final String password;

  const AuthLoginRequested({
    required this.email,
    required this.password,
  });

  @override
  List<Object?> get props => [email, password];
}

/// Fired when the user taps "Logout".
class AuthLogoutRequested extends AuthEvent {
  const AuthLogoutRequested();
}

/// Fired when the user updates their profile.
class AuthProfileUpdateRequested extends AuthEvent {
  final String username;
  final String? department;
  final String? phoneNumber;
  final bool? mfaEnabled;

  const AuthProfileUpdateRequested({
    required this.username,
    this.department,
    this.phoneNumber,
    this.mfaEnabled,
  });

  @override
  List<Object?> get props => [username, department, phoneNumber, mfaEnabled];
}