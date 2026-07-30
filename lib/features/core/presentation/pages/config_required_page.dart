import 'package:flutter/material.dart';

class ConfigRequiredPage extends StatelessWidget {
  const ConfigRequiredPage({super.key});

  @override
  Widget build(BuildContext context) => const MaterialApp(
        home: Scaffold(
          body: SafeArea(
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Supabase is not configured. Run the app with SUPABASE_URL and SUPABASE_ANON_KEY.\n\nSee supabase/README.md for setup.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ),
      );
}
