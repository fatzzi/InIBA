import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/utils/validators.dart';
import '../auth_controller.dart';
import '../widgets/error_text.dart';

/// Wireframes 1.2 + 1.3 (SCRUM-24, SCRUM-68)
class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});
  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final email = _email.text.trim();
    final ok = await ref
        .read(authProvider.notifier)
        .register(email, _password.text);
    if (ok && mounted) {
      context.push('/verify', extra: email);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Sign Up')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('University email'),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _email,
                          keyboardType: TextInputType.emailAddress,
                          autocorrect: false,
                          decoration: const InputDecoration(
                            hintText: 'name@khi.iba.edu.pk',
                          ),
                          validator: Validators.email,
                        ),
                        const SizedBox(height: 16),
                        const Text('Password'),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _password,
                          obscureText: true,
                          decoration: const InputDecoration(
                            hintText: 'At least 8 characters',
                          ),
                          validator: Validators.password,
                        ),
                        const SizedBox(height: 16),
                        const Text('Confirm password'),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _confirm,
                          obscureText: true,
                          decoration: const InputDecoration(
                            hintText: 'Repeat password',
                          ),
                          validator: (v) =>
                              Validators.confirmPassword(v, _password.text),
                        ),
                        ErrorText(auth.error),
                      ],
                    ),
                  ),
                ),
                FilledButton(
                  onPressed: auth.isLoading ? null : _submit,
                  child: auth.isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Create account'),
                ),
                TextButton(
                  onPressed: () {
                    ref.read(authProvider.notifier).clearError();
                    context.pushReplacement('/login');
                  },
                  child: const Text('Already have an account? Log In'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
