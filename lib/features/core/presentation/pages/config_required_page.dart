import 'package:flutter/material.dart';

class ConfigRequiredPage extends StatelessWidget {
  final String message;

  const ConfigRequiredPage({
    super.key,
    this.message =
        'Supabase belum dikonfigurasi. Jalankan aplikasi dengan '
        'SUPABASE_URL dan SUPABASE_ANON_KEY.\n\n'
        'Lihat supabase/README.md untuk pengaturan.',
  });

  @override
  Widget build(BuildContext context) => MaterialApp(
        home: Scaffold(
          body: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  message,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ),
      );
}
