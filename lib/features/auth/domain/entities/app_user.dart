import 'package:equatable/equatable.dart';

enum AppRole { admin, staff }

class AppUser extends Equatable {
  final String id;
  final String email;
  final String displayName;
  final AppRole role;

  const AppUser({
    required this.id,
    required this.email,
    required this.displayName,
    required this.role,
  });

  bool get canManageInventory => role == AppRole.admin;

  @override
  List<Object> get props => [id, email, displayName, role];
}
