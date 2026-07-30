import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/auth_bloc.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _signIn() {
    if (!_formKey.currentState!.validate()) return;
    context.read<AuthBloc>().add(AuthSignInRequested(
          username: _usernameController.text,
          password: _passwordController.text,
        ));
  }

  @override
  Widget build(BuildContext context) {
    final loading =
        context.select<AuthBloc, bool>((bloc) => bloc.state is AuthLoading);
    final error = context.select<AuthBloc, String?>((bloc) {
      final state = bloc.state;
      return state is AuthUnauthenticated ? state.message : null;
    });
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(Icons.storefront, size: 64),
                    const SizedBox(height: 20),
                    const Text('Anugrah Ukui',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 28, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    const Text('Sign in to continue',
                        textAlign: TextAlign.center),
                    const SizedBox(height: 32),
                    TextFormField(
                      controller: _usernameController,
                      autocorrect: false,
                      decoration: const InputDecoration(labelText: 'Username'),
                      validator: (value) =>
                          value != null && value.trim().isNotEmpty
                              ? null
                              : 'Enter your username',
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        suffixIcon: IconButton(
                          icon: Icon(_obscurePassword
                              ? Icons.visibility
                              : Icons.visibility_off),
                          onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword),
                        ),
                      ),
                      validator: (value) => value != null && value.length >= 6
                          ? null
                          : 'Password must be at least 6 characters',
                      onFieldSubmitted: (_) => _signIn(),
                    ),
                    if (error != null) ...[
                      const SizedBox(height: 16),
                      Text(error, style: const TextStyle(color: Colors.red)),
                    ],
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: loading ? null : _signIn,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        child: loading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2))
                            : const Text('Sign in'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
