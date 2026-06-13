import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  static const routeName = '/forgot-password';

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  final _tokenController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _message;

  @override
  void dispose() {
    _emailController.dispose();
    _tokenController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Reset password')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Request a reset token',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.tonal(
                      onPressed: auth.isLoading ? null : _requestToken,
                      child: const Text('Request token'),
                    ),
                    const Divider(height: 36),
                    TextField(
                      controller: _tokenController,
                      decoration: const InputDecoration(
                        labelText: 'Reset token',
                        prefixIcon: Icon(Icons.key_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'New password',
                        prefixIcon: Icon(Icons.lock_reset_outlined),
                      ),
                    ),
                    if (_message != null || auth.error != null) ...[
                      const SizedBox(height: 12),
                      Text(_message ?? auth.error!),
                    ],
                    const SizedBox(height: 18),
                    FilledButton(
                      onPressed: auth.isLoading ? null : _resetPassword,
                      child: const Text('Reset password'),
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

  Future<void> _requestToken() async {
    final token = await context.read<AuthProvider>().forgotPassword(
      _emailController.text,
    );
    if (!mounted) {
      return;
    }
    if (token != null) {
      _tokenController.text = token;
      setState(() {
        _message = 'Development reset token loaded. It expires in 15 minutes.';
      });
    } else if (context.read<AuthProvider>().error == null) {
      setState(() {
        _message = 'Check your email for the reset token.';
      });
    }
  }

  Future<void> _resetPassword() async {
    if (_passwordController.text.length < 8) {
      setState(() => _message = 'Use at least 8 characters.');
      return;
    }
    final success = await context.read<AuthProvider>().resetPassword(
      resetToken: _tokenController.text,
      newPassword: _passwordController.text,
    );
    if (success && mounted) {
      Navigator.popUntil(context, (route) => route.isFirst);
    }
  }
}
