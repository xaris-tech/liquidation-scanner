import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  static SupabaseClient? _client;

  static Future<void> initialize() async {
    _client = Supabase.instance.client;
  }

  static SupabaseClient get client {
    if (_client == null) {
      throw Exception('AuthService not initialized');
    }
    return _client!;
  }

  static Future<AuthResponse> signInWithEmail(
    String email,
    String password,
  ) async {
    return await _client!.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  static Future<AuthResponse> signUp(String email, String password) async {
    return await _client!.auth.signUp(email: email, password: password);
  }

  static Future<void> signOut() async {
    await _client!.auth.signOut();
  }

  static User? get currentUser => _client!.auth.currentUser;

  static Future<void> resetPassword(String email) async {
    await _client!.auth.resetPasswordForEmail(email);
  }

  static bool get isAuthenticated => _client!.auth.currentUser != null;
}

class AuthState {
  final User? user;
  final bool isLoading;
  final String? error;

  AuthState({this.user, this.isLoading = false, this.error});

  bool get isAuthenticated => user != null;
}

final authServiceProvider = Provider<AuthService>((ref) => AuthService());
