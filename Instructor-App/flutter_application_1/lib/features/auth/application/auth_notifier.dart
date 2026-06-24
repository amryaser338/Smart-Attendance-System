import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../doctor/application/doctor_notifier.dart';
import '../data/auth_service.dart';
import 'auth_state.dart';

final authServiceProvider = Provider((ref) => AuthService());

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref);
});

class AuthNotifier extends StateNotifier<AuthState> {
  final Ref ref;

  AuthNotifier(this.ref) : super(const AuthState(isLoading: true)) {
    _checkSavedLogin();
  }

  Future<void> _checkSavedLogin() async {
    try {
      final service = ref.read(authServiceProvider);
      final email = await service.getSavedEmail();

      if (email != null && email.isNotEmpty) {
        final doctorId = email.split('@')[0];
        ref.read(doctorProvider.notifier).setDoctorId(doctorId);
        state = state.copyWith(
          isLoading: false,
          isLoggedIn: true,
          email: email,
          error: null,
        );
      } else {
        state = state.copyWith(isLoading: false, isLoggedIn: false, error: null);
      }
    } catch (_) {
      state = state.copyWith(isLoading: false, isLoggedIn: false, error: null);
    }
  }

  Future<bool> login(String email, String password) async {
    final trimmed = email.trim().toLowerCase();

    if (!trimmed.endsWith('@miuegypt.edu.eg')) {
      state = state.copyWith(
        error: 'Use your MIU email (e.g. ahmed@miuegypt.edu.eg)',
      );
      return false;
    }

    final local = trimmed.split('@')[0];
    if (local.isEmpty) {
      state = state.copyWith(error: 'Email address is invalid');
      return false;
    }

    if (password.trim().isEmpty) {
      state = state.copyWith(error: 'Password cannot be empty');
      return false;
    }

    state = state.copyWith(isLoading: true, error: null);

    try {
      await ref.read(authServiceProvider).saveCredentials(trimmed, password.trim());
      ref.read(doctorProvider.notifier).setDoctorId(local);

      state = state.copyWith(
        isLoading: false,
        isLoggedIn: true,
        email: trimmed,
        error: null,
      );
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<void> logout() async {
    await ref.read(authServiceProvider).clearCredentials();
    ref.read(doctorProvider.notifier).setDoctorId('');
    state = const AuthState(isLoading: false, isLoggedIn: false);
  }
}
