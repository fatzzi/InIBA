// SCRUM-25: the app calls the right endpoints and turns backend errors into
// clear messages. Uses a fake HTTP adapter, so no server is needed.
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iniba/features/auth/data/auth_repository.dart';

class FakeAdapter implements HttpClientAdapter {
  FakeAdapter(this.status, this.body);
  final int status;
  final Map<String, Object?> body;
  RequestOptions? last;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    last = options;
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

(AuthRepository, FakeAdapter) repoReturning(int status, Map<String, Object?> body) {
  final adapter = FakeAdapter(status, body);
  final dio = Dio(BaseOptions(baseUrl: 'http://test'))..httpClientAdapter = adapter;
  return (AuthRepository(dio), adapter);
}

Future<AuthException> errorOf(Future<Object?> call) async {
  try {
    await call;
  } on AuthException catch (e) {
    return e;
  }
  fail('expected an AuthException');
}

void main() {
  group('verifyOtp', () {
    test('posts to /auth/verify and reads the token', () async {
      final (repo, adapter) = repoReturning(200, {
        'token': 'jwt-1',
        'expiresIn': 86400,
        'student': {'studentId': 1, 'name': 'Zunaira', 'batch': null, 'department': null},
      });

      final result = await repo.verifyOtp(' Zunaira@KHI.iba.edu.pk ', '123456');

      expect(adapter.last!.path, '/auth/verify');
      expect(adapter.last!.data, {'email': 'zunaira@khi.iba.edu.pk', 'code': '123456'});
      expect(result.token, 'jwt-1');
      expect(result.needsProfileSetup, isTrue);
    });

    test('a filled-in profile skips Profile Setup', () async {
      final (repo, _) = repoReturning(200, {
        'token': 'jwt-1',
        'student': {'studentId': 1, 'batch': '2027', 'department': 'CS'},
      });

      expect((await repo.verifyOtp('a@khi.iba.edu.pk', '123456')).needsProfileSetup, isFalse);
    });

    test('400 shows the backend message', () async {
      final (repo, _) = repoReturning(400, {'code': 400, 'message': 'Verification code has expired'});

      final e = await errorOf(repo.verifyOtp('a@khi.iba.edu.pk', '123456'));

      expect(e.statusCode, 400);
      expect(e.message, 'Verification code has expired');
    });

    test('429 tells the student to resend', () async {
      final (repo, _) = repoReturning(429, {'code': 429, 'message': 'Too many failed attempts'});

      final e = await errorOf(repo.verifyOtp('a@khi.iba.edu.pk', '123456'));

      expect(e.statusCode, 429);
      expect(e.message, contains('Resend code'));
    });

    test('404 means already verified', () async {
      final (repo, _) = repoReturning(404, {'code': 404, 'message': 'No pending account for this email'});

      final e = await errorOf(repo.verifyOtp('a@khi.iba.edu.pk', '123456'));

      expect(e.message, contains('already verified'));
    });
  });

  group('resendOtp', () {
    test('posts to /auth/resend-otp (the backend path)', () async {
      final (repo, adapter) = repoReturning(200, {'message': 'OTP sent', 'expiresInMinutes': 10});

      await repo.resendOtp('a@khi.iba.edu.pk');

      expect(adapter.last!.path, '/auth/resend-otp');
      expect(adapter.last!.data, {'email': 'a@khi.iba.edu.pk'});
    });

    test('429 reads the wait time from the backend message', () async {
      final (repo, _) = repoReturning(429, {
        'code': 429,
        'message': 'Please wait 42 seconds before requesting another code',
      });

      final e = await errorOf(repo.resendOtp('a@khi.iba.edu.pk'));

      expect(e.statusCode, 429);
      expect(e.retryAfterSeconds, 42);
      expect(e.message, 'Please wait 42 seconds before requesting another code.');
    });

    test('409 means already verified', () async {
      final (repo, _) = repoReturning(409, {'code': 409, 'message': 'Account already verified'});

      expect((await errorOf(repo.resendOtp('a@khi.iba.edu.pk'))).message, contains('already verified'));
    });

    test('503 means the email could not be sent', () async {
      final (repo, _) = repoReturning(503, {'code': 503, 'message': 'Could not send verification email'});

      expect((await errorOf(repo.resendOtp('a@khi.iba.edu.pk'))).message, contains("couldn't send"));
    });
  });
}
