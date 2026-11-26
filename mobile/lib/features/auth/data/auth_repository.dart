import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';

class AuthException implements Exception {
  AuthException(this.message, {this.statusCode, this.retryAfterSeconds});
  final String message;
  final int? statusCode;

  /// Set when the backend says how long to wait before resending (429).
  final int? retryAfterSeconds;
  @override
  String toString() => message;
}

/// What POST /auth/verify returns (SCRUM-25).
class VerifyResult {
  const VerifyResult({required this.token, required this.needsProfileSetup});
  final String token;

  /// True when the student has not filled in batch/department yet -> Profile
  /// Setup (1.7). False -> straight to the Main Feed.
  final bool needsProfileSetup;
}

class AuthRepository {
  AuthRepository(this._dio);
  final Dio _dio;

  /// POST /auth/register (1.2). Backend emails a 6-digit OTP.
  Future<void> register(String email, String password) async {
    try {
      await _dio.post(
        '/auth/register',
        data: {'email': email.trim().toLowerCase(), 'password': password},
      );
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      if (code == 409) {
        throw AuthException(
          'This email is already registered.',
          statusCode: code,
        );
      }
      if (code == 400 || code == 422) {
        throw AuthException(
          'Invalid email or password format.',
          statusCode: code,
        );
      }
      throw AuthException('Network error. Please try again.', statusCode: code);
    }
  }

  /// POST /auth/verify -> JWT (1.4 / 1.5, SCRUM-25). Backend: SCRUM-21.
  Future<VerifyResult> verifyOtp(String email, String code) async {
    try {
      final res = await _dio.post(
        '/auth/verify',
        data: {'email': email.trim().toLowerCase(), 'code': code},
      );
      final data = res.data as Map;
      final student = data['student'];
      var needsSetup = true;
      if (student is Map) {
        final batch = student['batch'];
        final department = student['department'];
        needsSetup = batch == null ||
            '$batch'.isEmpty ||
            department == null ||
            '$department'.isEmpty;
      }
      return VerifyResult(token: _token(res), needsProfileSetup: needsSetup);
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == null) {
        throw AuthException('Network error. Please check your connection.');
      }
      if (status == 429) {
        // Backend locks the code after 5 wrong tries; only a new code helps.
        throw AuthException(
          'Too many wrong attempts. Tap "Resend code" to get a new one.',
          statusCode: 429,
        );
      }
      if (status == 404) {
        throw AuthException(
          'This account is already verified. Please log in.',
          statusCode: 404,
        );
      }
      if (status == 400) {
        // "Invalid verification code", "Verification code has expired", ...
        throw AuthException(
          _serverMessage(e) ?? 'Wrong or expired code. Try again.',
          statusCode: 400,
        );
      }
      throw AuthException(
        'Something went wrong. Please try again.',
        statusCode: status,
      );
    }
  }

  /// POST /auth/resend-otp (1.4, SCRUM-25). Backend: SCRUM-20.
  Future<void> resendOtp(String email) async {
    try {
      await _dio.post(
        '/auth/resend-otp',
        data: {'email': email.trim().toLowerCase()},
      );
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == null) {
        throw AuthException('Network error. Please check your connection.');
      }
      if (status == 429) {
        // Backend: "Please wait 42 seconds before requesting another code"
        final msg = _serverMessage(e);
        final match = RegExp(r'(\d+)\s*second').firstMatch(msg ?? '');
        final wait = match != null ? int.parse(match.group(1)!) : 60;
        throw AuthException(
          'Please wait $wait seconds before requesting another code.',
          statusCode: 429,
          retryAfterSeconds: wait,
        );
      }
      if (status == 409) {
        throw AuthException(
          'This account is already verified. Please log in.',
          statusCode: 409,
        );
      }
      if (status == 404) {
        throw AuthException(
          'No account found for this email. Please sign up again.',
          statusCode: 404,
        );
      }
      if (status == 503) {
        throw AuthException(
          "We couldn't send the email. Try again in a moment.",
          statusCode: 503,
        );
      }
      throw AuthException(
        'Could not resend code. Try again.',
        statusCode: status,
      );
    }
  }

  /// POST /auth/login -> JWT (1.6).
  Future<String> login(String email, String password) async {
    try {
      final res = await _dio.post(
        '/auth/login',
        data: {'email': email.trim().toLowerCase(), 'password': password},
      );
      return _token(res);
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      if (code == 401 || code == 400) {
        throw AuthException('Incorrect email or password.', statusCode: code);
      }
      if (code == 429) {
        throw AuthException(
          'Too many attempts. Please wait 10 minutes.',
          statusCode: code,
        );
      }
      throw AuthException('Network error. Please try again.', statusCode: code);
    }
  }

  /// POST /auth/logout (1.8, SCRUM-70). Revokes the JWT on the server so a copied token
  /// stops working. Best effort: if the phone is offline we still log out locally.
  Future<void> logout() async {
    try {
      await _dio.post(
        '/auth/logout',
        options: Options(
          sendTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 5),
        ),
      );
    } on DioException {
      // 401 means the token was already invalid; network errors are ignored on purpose.
    }
  }

  /// PUT /profile (1.7). Multipart so the photo can be sent. Adjust to backend.
  Future<void> saveProfile({
    required String fullName,
    required String batch,
    required String department,
    String? societies,
    required String photoPath,
  }) async {
    try {
      final form = FormData.fromMap({
        'fullName': fullName,
        'batch': batch,
        'department': department,
        if (societies != null && societies.isNotEmpty) 'societies': societies,
        'photo': await MultipartFile.fromFile(photoPath),
      });
      await _dio.put('/profile', data: form);
    } on DioException catch (e) {
      throw AuthException(
        'Could not save profile. Try again.',
        statusCode: e.response?.statusCode,
      );
    }
  }

  /// The backend's error body is {"code": int, "message": str} (API doc 1.3).
  String? _serverMessage(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['message'] is String) {
      return data['message'] as String;
    }
    return null;
  }

  String _token(Response res) {
    final data = res.data as Map;
    final token = (data['access_token'] ?? data['token']) as String?;
    if (token == null) {
      throw AuthException('Unexpected server response.');
    }
    return token;
  }
}

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.watch(dioProvider)),
);
