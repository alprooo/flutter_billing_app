import 'package:fpdart/fpdart.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/error/failure.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/repositories/auth_repository.dart';

class SupabaseAuthRepository implements AuthRepository {
  final SupabaseClient _client;

  SupabaseAuthRepository(this._client);

  @override
  Future<Either<Failure, AppUser?>> restoreSession() async {
    final user = _client.auth.currentUser;
    if (user == null) return const Right(null);
    return _loadProfile(user);
  }

  @override
  Future<Either<Failure, AppUser>> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      final user = response.user;
      if (user == null) return const Left(RemoteFailure('Sign-in failed.'));
      return _loadProfile(user);
    } on AuthException catch (error) {
      return Left(RemoteFailure(error.message));
    } catch (error) {
      return Left(RemoteFailure(error.toString()));
    }
  }

  Future<Either<Failure, AppUser>> _loadProfile(User user) async {
    try {
      final data = await _client
          .from('profiles')
          .select('display_name, role')
          .eq('id', user.id)
          .single();
      final role = data['role'] == 'admin' ? AppRole.admin : AppRole.staff;
      return Right(AppUser(
        id: user.id,
        email: user.email ?? '',
        displayName:
            (data['display_name'] as String?)?.trim().isNotEmpty == true
                ? data['display_name'] as String
                : (user.email ?? 'User'),
        role: role,
      ));
    } on PostgrestException catch (error) {
      return Left(
          RemoteFailure('Could not load your profile: ${error.message}'));
    } catch (error) {
      return Left(RemoteFailure(error.toString()));
    }
  }

  @override
  Future<void> signOut() => _client.auth.signOut();
}
