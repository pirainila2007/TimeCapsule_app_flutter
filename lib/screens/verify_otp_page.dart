import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/auth_service.dart';
import '../utils/app_constants.dart';

/// Asks for the code Supabase emailed after sign-up.
class VerifyOtpPage extends StatefulWidget {
  final String email;

  const VerifyOtpPage({super.key, required this.email});

  @override
  State<VerifyOtpPage> createState() => _VerifyOtpPageState();
}

class _VerifyOtpPageState extends State<VerifyOtpPage> {
  static const resendSeconds = 60;

  final codeController = TextEditingController();
  final auth = AuthService();

  Timer? timer;
  int resendIn = resendSeconds;
  bool busy = false;
  String? error;
  String? info;

  @override
  void initState() {
    super.initState();
    startCountdown();
  }

  @override
  void dispose() {
    timer?.cancel();
    codeController.dispose();
    super.dispose();
  }

  void startCountdown() {
    timer?.cancel();
    setState(() => resendIn = resendSeconds);

    timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;

      if (resendIn <= 1) {
        t.cancel();
      }

      setState(() => resendIn = resendIn - 1);
    });
  }

  Future<void> verify() async {
    final code = codeController.text.trim();

    if (code.length < 6) {
      setState(() => error = 'Enter the code from your email.');
      return;
    }

    setState(() {
      busy = true;
      error = null;
      info = null;
    });

    try {
      await auth.verifyEmailCode(widget.email, code);

      if (!mounted) return;

      // Verified and signed in: close the OTP/login pages. AuthGate shows
      // the home page because there is now a session.
      Navigator.of(context).popUntil((route) => route.isFirst);
    } on AuthException catch (e) {
      if (mounted) {
        setState(() {
          error = e.message.toLowerCase().contains('expired') ||
                  e.message.toLowerCase().contains('invalid')
              ? 'That code is wrong or expired. Check it or request a new one.'
              : e.message;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => error = 'Something went wrong. Check your internet.');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> resend() async {
    setState(() {
      error = null;
      info = null;
    });

    try {
      await auth.resendEmailCode(widget.email);

      if (!mounted) return;

      setState(() => info = 'A new code was sent to ${widget.email}.');
      startCountdown();
    } on AuthException catch (e) {
      if (mounted) {
        setState(() {
          error = e.message.toLowerCase().contains('rate limit')
              ? 'Too many emails sent. Please wait a while and try again.'
              : e.message;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => error = 'Could not resend. Check your internet.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final canResend = resendIn <= 0;

    return Scaffold(
      appBar: AppBar(title: const Text('Verify your email')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: ListView(
              padding: const EdgeInsets.all(24),
              shrinkWrap: true,
              children: [
                const Icon(
                  Icons.mark_email_read_rounded,
                  color: AppColors.purple,
                  size: 64,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Check your email',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'We sent a verification code to\n${widget.email}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white60, height: 1.5),
                ),
                const SizedBox(height: 28),
                TextField(
                  controller: codeController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  maxLength: 10,
                  autofocus: true,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onSubmitted: (_) => busy ? null : verify(),
                  style: const TextStyle(
                    fontSize: 28,
                    letterSpacing: 8,
                    fontWeight: FontWeight.bold,
                  ),
                  decoration: const InputDecoration(
                    hintText: '00000000',
                    counterText: '',
                  ),
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
                  onPressed: busy ? null : verify,
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
                      : const Text('Verify'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: canResend && !busy ? resend : null,
                  child: Text(
                    canResend ? 'Resend code' : 'Resend code in ${resendIn}s',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}