// SCRUM-25: As a student, I want to enter the 6-digit OTP sent to my email and
// resend it if it doesn't arrive, so that I can verify my account.
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iniba/core/storage/secure_storage.dart';
import 'package:iniba/features/auth/data/auth_repository.dart';
import 'package:iniba/features/auth/presentation/auth_controller.dart';
import 'package:iniba/features/auth/presentation/screens/verify_otp_screen.dart';

const email = 'zunaira@khi.iba.edu.pk';

class FakeTokenStorage extends TokenStorage {
  String? token;
  @override
  Future<String?> read() async => token;
  @override
  Future<void> save(String t) async => token = t;
  @override
  Future<void> clear() async => token = null;
}

class FakeAuthRepository extends AuthRepository {
  FakeAuthRepository() : super(Dio());

  final verifyCalls = <String>[];
  int resendCalls = 0;
  AuthException? verifyError;
  AuthException? resendError;
  bool profileDone = false;

  @override
  Future<VerifyResult> verifyOtp(String email, String code) async {
    verifyCalls.add(code);
    if (verifyError != null) throw verifyError!;
    return VerifyResult(token: 'jwt', needsProfileSetup: !profileDone);
  }

  @override
  Future<void> resendOtp(String email) async {
    resendCalls++;
    if (resendError != null) throw resendError!;
  }
}

Future<(ProviderContainer, FakeAuthRepository, FakeTokenStorage)> pumpScreen(
  WidgetTester tester,
) async {
  final repo = FakeAuthRepository();
  final tokens = FakeTokenStorage();
  final container = ProviderContainer(
    overrides: [
      authRepositoryProvider.overrideWithValue(repo),
      tokenStorageProvider.overrideWithValue(tokens),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: VerifyOtpScreen(email: email)),
    ),
  );
  await tester.pump();
  return (container, repo, tokens);
}

Future<void> typeCode(WidgetTester tester, String code) async {
  for (var i = 0; i < code.length; i++) {
    await tester.enterText(find.byKey(Key('otp-$i')), code[i]);
    await tester.pump();
  }
}

String box(WidgetTester tester, int i) =>
    tester.widget<TextField>(find.byKey(Key('otp-$i'))).controller!.text;

void main() {
  testWidgets('shows the email and six empty boxes', (tester) async {
    await pumpScreen(tester);

    expect(find.text(email), findsOneWidget);
    for (var i = 0; i < 6; i++) {
      expect(box(tester, i), isEmpty);
    }
  });

  testWidgets('typing all 6 digits verifies and saves the token', (tester) async {
    final (container, repo, tokens) = await pumpScreen(tester);

    await typeCode(tester, '482913');

    expect(repo.verifyCalls, ['482913']);
    expect(tokens.token, 'jwt');
    final state = container.read(authProvider);
    expect(state.status, AuthStatus.authenticated);
    expect(state.needsProfileSetup, isTrue); // first login -> Profile Setup
  });

  testWidgets('a student with a finished profile goes to the feed', (tester) async {
    final (container, repo, _) = await pumpScreen(tester);
    repo.profileDone = true;

    await typeCode(tester, '482913');

    expect(container.read(authProvider).needsProfileSetup, isFalse);
  });

  testWidgets('pasting the whole code fills every box', (tester) async {
    final (_, repo, _) = await pumpScreen(tester);

    await tester.enterText(find.byKey(const Key('otp-0')), '123456');
    await tester.pump();

    for (var i = 0; i < 6; i++) {
      expect(box(tester, i), '${i + 1}');
    }
    expect(repo.verifyCalls, ['123456']);
  });

  testWidgets('letters are ignored', (tester) async {
    await pumpScreen(tester);

    await tester.enterText(find.byKey(const Key('otp-0')), 'a');
    await tester.pump();

    expect(box(tester, 0), isEmpty);
  });

  testWidgets('wrong code shows the error and clears the boxes', (tester) async {
    final (container, repo, tokens) = await pumpScreen(tester);
    repo.verifyError = AuthException('Invalid verification code', statusCode: 400);

    await typeCode(tester, '000000');

    expect(find.text('Invalid verification code'), findsOneWidget);
    for (var i = 0; i < 6; i++) {
      expect(box(tester, i), isEmpty);
    }
    expect(tokens.token, isNull);
    expect(container.read(authProvider).status, AuthStatus.unauthenticated);
  });

  testWidgets('too many wrong tries locks Verify until a new code', (tester) async {
    final (_, repo, _) = await pumpScreen(tester);
    repo.verifyError = AuthException(
      'Too many wrong attempts. Tap "Resend code" to get a new one.',
      statusCode: 429,
    );

    await typeCode(tester, '000000');

    expect(find.textContaining('Too many wrong attempts'), findsOneWidget);
    final verify = tester.widget<FilledButton>(find.byKey(const Key('verify-button')));
    expect(verify.onPressed, isNull);
    final first = tester.widget<TextField>(find.byKey(const Key('otp-0')));
    expect(first.enabled, isFalse);

    // After the cooldown, a new code unlocks the boxes again.
    repo.verifyError = null;
    await tester.pump(const Duration(seconds: 61));
    await tester.tap(find.byKey(const Key('resend-button')));
    await tester.pump();

    expect(repo.resendCalls, 1);
    expect(tester.widget<TextField>(find.byKey(const Key('otp-0'))).enabled, isTrue);
  });

  testWidgets('Resend is hidden for 60 seconds, then sends a new code', (tester) async {
    final (_, repo, _) = await pumpScreen(tester);

    expect(find.byKey(const Key('resend-button')), findsNothing);
    expect(find.text("Didn't get it? Resend code in 1:00"), findsOneWidget);

    await tester.pump(const Duration(seconds: 30));
    expect(find.text("Didn't get it? Resend code in 0:30"), findsOneWidget);

    await tester.pump(const Duration(seconds: 31));
    expect(find.byKey(const Key('resend-button')), findsOneWidget);

    await tester.tap(find.byKey(const Key('resend-button')));
    await tester.pump(); // resend finishes
    await tester.pump(); // snackbar animation starts

    expect(repo.resendCalls, 1);
    expect(find.text('A new code was sent to $email'), findsOneWidget);
    // The cooldown starts again.
    expect(find.byKey(const Key('resend-button')), findsNothing);
    expect(find.text("Didn't get it? Resend code in 1:00"), findsOneWidget);
  });

  testWidgets('if the server says wait, the countdown uses its number', (tester) async {
    final (_, repo, _) = await pumpScreen(tester);
    repo.resendError = AuthException(
      'Please wait 25 seconds before requesting another code.',
      statusCode: 429,
      retryAfterSeconds: 25,
    );

    await tester.pump(const Duration(seconds: 61));
    await tester.tap(find.byKey(const Key('resend-button')));
    await tester.pump();

    expect(find.text('Please wait 25 seconds before requesting another code.'), findsOneWidget);
    expect(find.text("Didn't get it? Resend code in 0:25"), findsOneWidget);
  });

  testWidgets('a failed resend shows the error and keeps Resend available', (tester) async {
    final (_, repo, _) = await pumpScreen(tester);
    repo.resendError = AuthException(
      "We couldn't send the email. Try again in a moment.",
      statusCode: 503,
    );

    await tester.pump(const Duration(seconds: 61));
    await tester.tap(find.byKey(const Key('resend-button')));
    await tester.pump();

    expect(find.text("We couldn't send the email. Try again in a moment."), findsOneWidget);
    expect(find.byKey(const Key('resend-button')), findsOneWidget);
  });
}
