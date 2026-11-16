import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import 'profile_model.dart';
import 'profile_repository.dart';

// --- Dev wiring until login exists (SCRUM-24/25/26). Each one is meant to be replaced. ---

/// Backend base URL, e.g. `--dart-define=API_BASE_URL=http://10.0.2.2:8000` on the Android emulator.
/// Empty means "no backend": the app uses [FakeProfileRepository].
final apiBaseUrlProvider = Provider<String>((_) => const String.fromEnvironment('API_BASE_URL'));

/// Bearer token. Dev only (`--dart-define=DEV_TOKEN=...`); SCRUM-26 moves this to secure storage.
final authTokenProvider = Provider<String?>((_) {
  const token = String.fromEnvironment('DEV_TOKEN');
  return token.isEmpty ? null : token;
});

/// The logged-in student's id. Dev only (`--dart-define=DEV_STUDENT_ID=2`); login will provide it.
final currentStudentIdProvider =
    Provider<int>((_) => const int.fromEnvironment('DEV_STUDENT_ID', defaultValue: 1));

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  final baseUrl = ref.watch(apiBaseUrlProvider);
  if (baseUrl.isEmpty) return FakeProfileRepository();
  return HttpProfileRepository(ApiClient(baseUrl: baseUrl, token: ref.watch(authTokenProvider)));
});

// --- Profile state ---

class ProfileState {
  const ProfileState({
    required this.profile,
    required this.posts,
    required this.isMore,
    this.loadingMore = false,
    this.loadMoreError,
  });

  final Profile profile;
  final List<PostThumb> posts;
  final bool isMore;
  final bool loadingMore;
  final String? loadMoreError;

  ProfileState copyWith({
    List<PostThumb>? posts,
    bool? isMore,
    bool? loadingMore,
    String? loadMoreError,
    bool clearError = false,
  }) =>
      ProfileState(
        profile: profile,
        posts: posts ?? this.posts,
        isMore: isMore ?? this.isMore,
        loadingMore: loadingMore ?? this.loadingMore,
        loadMoreError: clearError ? null : (loadMoreError ?? this.loadMoreError),
      );
}

/// Profile header plus the post grid for one student, with infinite paging.
class ProfileController extends AutoDisposeFamilyAsyncNotifier<ProfileState, int> {
  bool _disposed = false;

  @override
  Future<ProfileState> build(int studentId) async {
    _disposed = false;
    ref.onDispose(() => _disposed = true);
    final profile = await ref.watch(profileRepositoryProvider).fetchProfile(studentId);
    return ProfileState(profile: profile, posts: profile.posts.items, isMore: profile.posts.isMore);
  }

  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || !current.isMore || current.loadingMore) return;
    state = AsyncData(current.copyWith(loadingMore: true, clearError: true));
    try {
      final page = await ref.read(profileRepositoryProvider).fetchPosts(arg, offset: current.posts.length);
      if (_disposed) return;
      state = AsyncData(current.copyWith(
        posts: [...current.posts, ...page.items],
        isMore: page.isMore,
        loadingMore: false,
        clearError: true,
      ));
    } on Exception catch (e) {
      if (_disposed) return;
      state = AsyncData(current.copyWith(
        loadingMore: false,
        loadMoreError: e is ApiException ? e.message : 'Could not load more posts.',
      ));
    }
  }
}

final profileControllerProvider =
    AsyncNotifierProvider.autoDispose.family<ProfileController, ProfileState, int>(ProfileController.new);
