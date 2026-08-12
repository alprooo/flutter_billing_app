import 'dart:convert';

class SupabaseConfig {
  const SupabaseConfig._();

  static const url = String.fromEnvironment('SUPABASE_URL');
  static const anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static bool get isConfigured => url.isNotEmpty && anonKey.isNotEmpty;

  static String? get validationError {
    if (!isConfigured) {
      return 'Supabase belum dikonfigurasi.\n\n'
          'Untuk debug: flutter run --dart-define-from-file=config/supabase.local.json\n\n'
          'Untuk APK release: flutter build apk --release '
          '--dart-define-from-file=config/supabase.local.json';
    }
    if (_isServiceRoleKey(anonKey)) {
      return 'Kunci Supabase yang dipakai tidak aman untuk aplikasi Flutter.\n\n'
          'Gunakan ANON key atau publishable key dari Supabase Project Settings > API, '
          'bukan service-role key.';
    }
    return null;
  }

  static bool _isServiceRoleKey(String key) {
    if (key.startsWith('sb_publishable_')) {
      return false;
    }
    if (key.startsWith('sb_secret_')) {
      return true;
    }

    final parts = key.split('.');
    if (parts.length != 3) {
      return false;
    }

    try {
      final normalized = base64Url.normalize(parts[1]);
      final payload = utf8.decode(base64Url.decode(normalized));
      final claims = jsonDecode(payload);
      return claims is Map<String, dynamic> && claims['role'] == 'service_role';
    } catch (_) {
      return false;
    }
  }
}
