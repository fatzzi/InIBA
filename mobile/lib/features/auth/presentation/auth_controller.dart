import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/secure_storage.dart';
import '../../profile/profile_providers.dart';
import '../data/auth_repository.dart';

enum AuthStatus { unknown, unauthenticated, authenticated }

class AuthState {
  const AuthState({
    this.status = AuthStatus.unknown,
    this.isLoading = false,
    this.error,
    this.needsProfileSetup = false,
  });
  final AuthStatus status;
  final bool isLoading;
  final String? error;
  final bool needsProfileSetup;

  AuthState copyWith({
    AuthStatus? status,
    bool? isLoading,
    String? error,
    bool clearError = false,
    bool? needsProfileSetup,
  }) => AuthState(
    status: status ?? this.status,
    isLoading: isLoading ?? this.isLoading,
    error: clearError ? null : (error ?? this.error),
    needsProfileSetup: needsProfileSetup ?? this.needsProfileSetup,
  );
}

class AuthController extends Notifier<AuthState> {
  AuthRepository get _repo => ref.read(authRepositoryProvider);
  TokenStorage get _tokens => ref.read(tokenStorageProvider);

  @override
  AuthState build() {
    _restoreSession();
    return const AuthState();
  }

  Future<void> _restoreSession() async {
    String? token;
    try {
      token = await _tokens.read();
    } catch (_) {
      token = null; // storage unavailable (e.g. in tests)
    }
    state = state.copyWith(
      status: token != null
          ? AuthStatus.authenticated
          : AuthStatus.unauthenticated,
    );
  }

  void clearError() => state = state.copyWith(clearError: true);

  Future<bool> register(String email, String password) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _repo.register(email, password);
      state = state.copyWith(isLoading: false);
      return true;
    } on AuthException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
      return false;
    }
  }

  /// Returns the HTTP status on failure (e.g. 429) or null on success.
  Future<int?> verifyOtp(String email, String code) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final token = await _repo.verifyOtp(email, code);
      await _tokens.save(token);
      // First login after verifying -> profile setup (1.7)
      state = state.copyWith(
        isLoading: false,
        status: AuthStatus.authenticated,
        needsProfileSetup: true,
      );
      return null;
    } on AuthException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
      return e.statusCode ?? 0;
    }
  }

  Future<void> resendOtp(String email) async {
    state = state.copyWith(clearError: true);
    try {
      await _repo.resendOtp(email);
    } on AuthException catch (e) {
      state = state.copyWith(error: e.message);
    }
  }

  Future<void> login(String email, String password) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final token = await _repo.login(email, password);
      await _tokens.save(token);
      state = state.copyWith(
        isLoading: false,
        status: AuthStatus.authenticated,
      );
    } on AuthException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
    }
  }

  Future<bool> completeProfile({
    required String fullName,
    required String batch,
    required String department,
    String? societies,
    required String photoPath,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _repo.saveProfile(
        fullName: fullName,
        batch: batch,
        department: department,
        societies: societies,
        photoPath: photoPath,
      );
      state = state.copyWith(isLoading: false, needsProfileSetup: false);
      return true;
    } on AuthException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
      return false;
    }
  }

  /// 1.8 / SCRUM-70: ends the session so nobody else can use the account on this device.
  /// 1. Tells the backend to revoke the JWT (best effort, never blocks logout).
  /// 2. Deletes the JWT from secure storage.
  /// 3. Drops cached data of the old user (profile, posts) from memory.
  /// 4. Sets status to unauthenticated -> the router sends the user to /welcome.
  Future<void> logout() async {
    if (state.isLoading) return;
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _repo.logout();
    } catch (_) {
      // Ignore: logging out must work offline too.
    }
    await _endSession();
  }

  /// Used when the server says the token is no longer valid (401), e.g. it was
  /// revoked by logging out on another device or it expired. No server call.
  Future<void> sessionExpired() async {
    if (state.status != AuthStatus.authenticated) return;
    await _endSession(error: 'Your session has ended. Please log in again.');
  }

  Future<void> _endSession({String? error}) async {
    try {
      await _tokens.clear();
    } catch (_) {
      // storage unavailable (e.g. in tests); state below still logs the user out
    }
    ref.invalidate(profileControllerProvider);
    state = AuthState(status: AuthStatus.unauthenticated, error: error);
  }
}

final authProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);
