import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/app_user.dart';

abstract class AuthRepository {
  Future<Either<Failure, AppUser?>> restoreSession();
  Future<Either<Failure, AppUser>> signIn({
    required String username,
    required String password,
  });
  Future<void> signOut();
}
