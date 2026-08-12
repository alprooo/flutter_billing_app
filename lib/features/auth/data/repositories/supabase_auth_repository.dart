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
    required String username,
    required String password,
  }) async {
    try {
      final response = await _client.functions.invoke('login-with-username',
          body: {'username': username.trim(), 'password': password});
      final data = response.data as Map<String, dynamic>;
      final authResponse = await _client.auth.setSession(
        data['refresh_token'] as String,
        accessToken: data['access_token'] as String,
      );
      final user = authResponse.user;
      if (user == null) return const Left(RemoteFailure('Gagal masuk.'));
      return _loadProfile(user);
    } catch (error) {
      return const Left(RemoteFailure('Invalid username or password.'));
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
      return Left(RemoteFailure('Gagal memuat profil Anda: ${error.message}'));
    } catch (error) {
      return Left(RemoteFailure(error.toString()));
    }
  }

  @override
  Future<void> signOut() => _client.auth.signOut();
}
