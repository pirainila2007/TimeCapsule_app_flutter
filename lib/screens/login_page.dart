import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/auth_service.dart';
import '../utils/app_constants.dart';

class LoginPage extends StatefulWidget {
  /// Shown as "Continue without account" when provided.
  final VoidCallback? onGuest;

  const LoginPage({super.key, this.onGuest});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final formKey = GlobalKey<FormState>();
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  bool signUpMode = false;
  bool busy = false;
  bool hidePassword = true;
  String? error;
  String? info;

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (!formKey.currentState!.validate()) return;

    setState(() {
      busy = true;
      error = null;
      info = null;
    });

    try {
      final auth = AuthService();

      if (signUpMode) {
        final response = await auth.signUp(
          emailController.text,
          passwordController.text,
          fullName: nameController.text,
        );

        // Email confirmation is on: no session until the user confirms.
        if (response.session == null) {
          if (!mounted) return;

          setState(() {
            signUpMode = false;
            info = 'Account created! Check your email to confirm it, '
                'then sign in.';
          });
          return;
        }
      } else {
        await auth.signIn(
          emailController.text,
          passwordController.text,
        );
      }

      if (!mounted) return;

      // When opened on top of the app, close this page after login.
      // (When shown by AuthGate, the gate swaps to the home page itself.)
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    } on AuthException catch (e) {
      if (mounted) setState(() => error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() {
          error = 'Something went wrong. Check your internet and try again.';
        });
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: Navigator.of(context).canPop()
          ? AppBar(title: const Text('Sign in'))
          : null,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Form(
              key: formKey,
              child: ListView(
                padding: const EdgeInsets.all(24),
                shrinkWrap: true,
                children: [
                  const Icon(
                    Icons.hourglass_top_rounded,
                    color: AppColors.purple,
                    size: 64,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    signUpMode ? 'Create your account' : 'Welcome back',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Sign in to keep your capsules safe and in sync '
                    'across your devices.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white60, height: 1.5),
                  ),
                  const SizedBox(height: 28),
                  if (signUpMode) ...[
                    TextFormField(
                      controller: nameController,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        hintText: 'Your name',
                        prefixIcon: Icon(Icons.person_outline_rounded),
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],
                  TextFormField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.email],
                    decoration: const InputDecoration(
                      hintText: 'Email',
                      prefixIcon: Icon(Icons.mail_outline_rounded),
                    ),
                    validator: (v) {
                      final value = v?.trim() ?? '';
                      if (value.isEmpty) return 'Enter your email';
                      if (!value.contains('@') || !value.contains('.')) {
                        return 'Enter a valid email';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: passwordController,
                    obscureText: hidePassword,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => busy ? null : submit(),
                    autofillHints: const [AutofillHints.password],
                    decoration: InputDecoration(
                      hintText: 'Password',
                      prefixIcon: const Icon(Icons.lock_outline_rounded),
                      suffixIcon: IconButton(
                        onPressed: () {
                          setState(() => hidePassword = !hidePassword);
                        },
                        icon: Icon(
                          hidePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                    ),
                    validator: (v) {
                      final value = v ?? '';
                      if (value.isEmpty) return 'Enter your password';
                      if (signUpMode && value.length < 6) {
                        return 'Use at least 6 characters';
                      }
                      return null;
                    },
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 14),
                    Text(
                      error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                  ],
                  if (info != null) ...[
                    const SizedBox(height: 14),
                    Text(
                      info!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.greenAccent),
                    ),
                  ],
                  const SizedBox(height: 22),
                  FilledButton(
                    onPressed: busy ? null : submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.purple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: busy
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(signUpMode ? 'Create account' : 'Sign in'),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: busy
                        ? null
                        : () {
                            setState(() {
                              signUpMode = !signUpMode;
                              error = null;
                              info = null;
                            });
                          },
                    child: Text(
                      signUpMode
                          ? 'Already have an account? Sign in'
                          : 'New here? Create an account',
                    ),
                  ),
                  if (widget.onGuest != null)
                    TextButton(
                      onPressed: busy ? null : widget.onGuest,
                      child: const Text(
                        'Continue without account',
                        style: TextStyle(color: Colors.white54),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}