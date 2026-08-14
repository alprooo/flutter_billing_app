import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/foundation.dart';

import '../../../admin/presentation/pages/web_admin_dashboard_page.dart';
import '../../../billing/presentation/bloc/billing_bloc.dart';
import '../../domain/entities/app_user.dart';
import '../bloc/auth_bloc.dart';
import 'login_page.dart';
import '../../../shell/presentation/pages/pos_shell.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listenWhen: (previous, current) =>
          previous is Authenticated && current is AuthUnauthenticated,
      listener: (context, state) =>
          context.read<BillingBloc>().add(ClearCartEvent()),
      child: BlocBuilder<AuthBloc, AuthState>(
        builder: (context, state) {
          if (state is Authenticated) {
            if (kIsWeb && state.user.role == AppRole.admin) {
              return WebAdminDashboardPage(user: state.user);
            }
            return PosShell(user: state.user);
          }
          if (state is AuthLoading || state is AuthInitial) {
            return const Scaffold(
                body: Center(child: CircularProgressIndicator()));
          }
          if (state is AuthFailure) {
            return Scaffold(body: Center(child: Text(state.message)));
          }
          return const LoginPage();
        },
      ),
    );
  }
}
