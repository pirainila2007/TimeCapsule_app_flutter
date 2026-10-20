import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  SupabaseClient get _client => Supabase.instance.client;

  Future<AuthResponse> signUp(
    String email,
    String password, {
    String? fullName,
  }) {
    final name = fullName?.trim() ?? '';

    return _client.auth.signUp(
      email: email.trim(),
      password: password,
      data: name.isEmpty ? null : {'full_name': name},
    );
  }

  Future<AuthResponse> signIn(String email, String password) {
    return _client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  }

  /// Confirms a sign-up with the code that was emailed to the user.
  Future<AuthResponse> verifyEmailCode(String email, String code) {
    return _client.auth.verifyOTP(
      type: OtpType.signup,
      email: email.trim(),
      token: code.trim(),
    );
  }

  /// Sends a fresh sign-up code to the user's email.
  Future<void> resendEmailCode(String email) async {
    await _client.auth.resend(type: OtpType.signup, email: email.trim());
  }

  Future<void> signOut() => _client.auth.signOut();

  User? get currentUser => _client.auth.currentUser;
}