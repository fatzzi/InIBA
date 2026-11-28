import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../profile/profile_providers.dart' show apiBaseUrlProvider, authTokenProvider;

/// Today's IBA Moment for the logged-in student (`GET /moments/current`, API doc 4.2).
class MomentStatus {
  MomentStatus({
    required this.active,
    required this.secondsRemaining,
    required this.alreadyPosted,
    required this.feedLocked,
    DateTime? fetchedAt,
  }) : fetchedAt = fetchedAt ?? DateTime.now();

  factory MomentStatus.fromJson(Map<String, dynamic> json) => MomentStatus(
    active: json['active'] as bool? ?? false,
    secondsRemaining: (json['secondsRemaining'] as num?)?.toInt() ?? 0,
    alreadyPosted: json['alreadyPosted'] as bool? ?? false,
    feedLocked: json['feedLocked'] as bool? ?? false,
  );

  /// The window is open right now.
  final bool active;

  /// Seconds left in the window when this was fetched (0 when closed).
  final int secondsRemaining;

  /// Today's Moment is already posted; there is no second one.
  final bool alreadyPosted;

  final bool feedLocked;

  /// When the app received this, so the countdown can subtract the time since.
  final DateTime fetchedAt;

  /// The student can start capturing now.
  bool get canCapture => active && !alreadyPosted;

  /// Seconds left at [now], counting from when the status arrived.
  int secondsLeftAt(DateTime now) {
    final left = secondsRemaining - now.difference(fetchedAt).inSeconds;
    return left < 0 ? 0 : left;
  }
}

abstract class MomentRepository {
  Future<MomentStatus> fetchStatus();
}

class HttpMomentRepository implements MomentRepository {
  HttpMomentRepository(this._api);

  final ApiClient _api;

  @override
  Future<MomentStatus> fetchStatus() async => MomentStatus.fromJson(await _api.getJson('/moments/current'));
}

/// Used when no backend is configured: the window is always open with the full 2 minutes,
/// so the capture flow can be tried on a phone without a server.
class FakeMomentRepository implements MomentRepository {
  FakeMomentRepository({this.status, this.failWith, this.latency = Duration.zero});

  MomentStatus? status;
  ApiException? failWith;
  final Duration latency;
  int calls = 0;

  @override
  Future<MomentStatus> fetchStatus() async {
    calls++;
    if (latency > Duration.zero) await Future<void>.delayed(latency);
    if (failWith != null) throw failWith!;
    return status ??
        MomentStatus(active: true, secondsRemaining: kMomentWindowSeconds, alreadyPosted: false, feedLocked: true);
  }
}

/// Length of the IBA Moment window (backend `moment_duration_seconds`).
const kMomentWindowSeconds = 120;

final momentRepositoryProvider = Provider<MomentRepository>((ref) {
  final baseUrl = ref.watch(apiBaseUrlProvider);
  if (baseUrl.isEmpty) return FakeMomentRepository();
  return HttpMomentRepository(ApiClient(baseUrl: baseUrl, token: ref.watch(authTokenProvider)));
});

final momentStatusProvider = FutureProvider.autoDispose<MomentStatus>(
  (ref) => ref.watch(momentRepositoryProvider).fetchStatus(),
);
