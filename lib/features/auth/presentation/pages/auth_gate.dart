import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../billing/presentation/bloc/billing_bloc.dart';
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
