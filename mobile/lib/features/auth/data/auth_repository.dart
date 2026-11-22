import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';

class AuthException implements Exception {
  AuthException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;
  @override
  String toString() => message;
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

  /// POST /auth/verify -> JWT (1.4 / 1.5).
  Future<String> verifyOtp(String email, String code) async {
    try {
      final res = await _dio.post(
        '/auth/verify',
        data: {'email': email.trim().toLowerCase(), 'code': code},
      );
      return _token(res);
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 429) {
        throw AuthException(
          'Too many attempts. Please wait 10 minutes.',
          statusCode: 429,
        );
      }
      if (status == 400 || status == 401 || status == 410) {
        throw AuthException(
          'Wrong or expired code. Try again or request a new one.',
          statusCode: status,
        );
      }
      throw AuthException(
        'Network error. Please try again.',
        statusCode: status,
      );
    }
  }

  /// Resend OTP (1.4). Adjust the path to match the backend.
  Future<void> resendOtp(String email) async {
    try {
      await _dio.post(
        '/auth/resend',
        data: {'email': email.trim().toLowerCase()},
      );
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 429) {
        throw AuthException(
          'Too many attempts. Please wait 10 minutes.',
          statusCode: 429,
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
