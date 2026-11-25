// SCRUM-70: As a student, I want to log out of my account,
// so that nobody else can use it on my device.
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iniba/core/storage/secure_storage.dart';
import 'package:iniba/features/auth/data/auth_repository.dart';
import 'package:iniba/features/auth/presentation/auth_controller.dart';
import 'package:iniba/features/settings/settings_screen.dart';

/// In-memory token store that starts out logged in.
class FakeTokenStorage extends TokenStorage {
  String? token = 'jwt-123';
  @override
  Future<String?> read() async => token;
  @override
  Future<void> save(String t) async => token = t;
  @override
  Future<void> clear() async => token = null;
}

class FakeAuthRepository extends AuthRepository {
  FakeAuthRepository({this.fail = false}) : super(Dio());
  final bool fail;
  int logoutCalls = 0;
  @override
  Future<void> logout() async {
    logoutCalls++;
    if (fail) throw Exception('offline');
  }
}

Future<(ProviderContainer, FakeTokenStorage, FakeAuthRepository)> pumpSettings(
  WidgetTester tester, {
  bool serverFails = false,
}) async {
  final tokens = FakeTokenStorage();
  final repo = FakeAuthRepository(fail: serverFails);
  final container = ProviderContainer(
    overrides: [
      tokenStorageProvider.overrideWithValue(tokens),
      authRepositoryProvider.overrideWithValue(repo),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: SettingsScreen()),
    ),
  );
  await tester.pumpAndSettle();
  expect(container.read(authProvider).status, AuthStatus.authenticated);
  return (container, tokens, repo);
}

void main() {
  testWidgets('confirming Log Out clears the JWT and signs the user out', (tester) async {
    final (container, tokens, repo) = await pumpSettings(tester);

    await tester.tap(find.byKey(const Key('logout-tile')));
    await tester.pumpAndSettle();
    expect(find.text('Log out?'), findsOneWidget);

    await tester.tap(find.byKey(const Key('confirm-logout')));
    await tester.pumpAndSettle();

    expect(repo.logoutCalls, 1);
    expect(tokens.token, isNull);
    expect(container.read(authProvider).status, AuthStatus.unauthenticated);
  });

  testWidgets('Cancel keeps the user logged in', (tester) async {
    final (container, tokens, repo) = await pumpSettings(tester);

    await tester.tap(find.byKey(const Key('logout-tile')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(repo.logoutCalls, 0);
    expect(tokens.token, 'jwt-123');
    expect(container.read(authProvider).status, AuthStatus.authenticated);
  });

  testWidgets('logging out still works when the server cannot be reached', (tester) async {
    final (container, tokens, _) = await pumpSettings(tester, serverFails: true);

    await tester.tap(find.byKey(const Key('logout-tile')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-logout')));
    await tester.pumpAndSettle();

    expect(tokens.token, isNull);
    expect(container.read(authProvider).status, AuthStatus.unauthenticated);
  });

  test('sessionExpired (server 401) clears the token without calling the server', () async {
    final tokens = FakeTokenStorage();
    final repo = FakeAuthRepository();
    final container = ProviderContainer(
      overrides: [
        tokenStorageProvider.overrideWithValue(tokens),
        authRepositoryProvider.overrideWithValue(repo),
      ],
    );
    addTearDown(container.dispose);
    container.read(authProvider);
    await Future<void>.delayed(Duration.zero); // let _restoreSession finish

    await container.read(authProvider.notifier).sessionExpired();

    expect(repo.logoutCalls, 0);
    expect(tokens.token, isNull);
    expect(container.read(authProvider).status, AuthStatus.unauthenticated);
    expect(container.read(authProvider).error, isNotNull);
  });
}
