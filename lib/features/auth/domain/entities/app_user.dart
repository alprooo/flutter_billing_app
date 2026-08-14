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
  bool get canAddProducts => role == AppRole.admin || role == AppRole.staff;
  bool get canRestockProducts =>
      role == AppRole.admin || role == AppRole.staff;
  bool get canEditProducts => role == AppRole.admin;
  bool get canDeleteProducts => role == AppRole.admin;
  bool get canImportProducts => role == AppRole.admin;

  @override
  List<Object> get props => [id, email, displayName, role];
}
