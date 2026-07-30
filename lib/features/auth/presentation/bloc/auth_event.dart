part of 'auth_bloc.dart';

sealed class AuthEvent extends Equatable {
  const AuthEvent();
  @override
  List<Object> get props => [];
}

class AuthStarted extends AuthEvent {
  const AuthStarted();
}

class AuthSignInRequested extends AuthEvent {
  final String username;
  final String password;
  const AuthSignInRequested({required this.username, required this.password});
  @override
  List<Object> get props => [username, password];
}

class AuthSignOutRequested extends AuthEvent {
  const AuthSignOutRequested();
}
