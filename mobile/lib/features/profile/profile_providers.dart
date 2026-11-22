import 'dart:typed_data';

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
    this.localPhoto,
    this.saving = false,
  });

  final Profile profile;
  final List<PostThumb> posts;
  final bool isMore;
  final bool loadingMore;
  final String? loadMoreError;

  /// The photo the student just cropped. Shown instead of [Profile.profilePhoto] so a new photo appears
  /// instantly, before (and after) the upload.
  final Uint8List? localPhoto;

  /// An edit is being sent to the server; the profile already shows the new values.
  final bool saving;

  ProfileState copyWith({
    Profile? profile,
    List<PostThumb>? posts,
    bool? isMore,
    bool? loadingMore,
    String? loadMoreError,
    bool clearError = false,
    Uint8List? localPhoto,
    bool? saving,
  }) =>
      ProfileState(
        profile: profile ?? this.profile,
        posts: posts ?? this.posts,
        isMore: isMore ?? this.isMore,
        loadingMore: loadingMore ?? this.loadingMore,
        loadMoreError: clearError ? null : (loadMoreError ?? this.loadMoreError),
        localPhoto: localPhoto ?? this.localPhoto,
        saving: saving ?? this.saving,
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

  /// Optimistic save (SCRUM-34): show the edit straight away, send it, and roll back if the server
  /// refuses. Returns null on success, or the error message after rolling back.
  Future<String?> save(ProfileEdit edit) async {
    final before = state.valueOrNull;
    if (before == null) return 'Profile is not loaded yet.';
    final optimistic = before.profile.copyWith(
      bio: edit.bio,
      moodSticker: edit.moodSticker,
      clearMood: edit.moodSticker == null,
      societies: edit.societies,
    );
    state = AsyncData(before.copyWith(profile: optimistic, localPhoto: edit.photoJpeg, saving: true));
    try {
      final saved = await ref.read(profileRepositoryProvider).updateProfile(arg, edit);
      if (_disposed) return null;
      final current = state.valueOrNull ?? before;
      // Keep the loaded posts; PATCH responses have none.
      state = AsyncData(current.copyWith(profile: saved.copyWith(posts: current.profile.posts), saving: false));
      return null;
    } on Exception catch (e) {
      if (!_disposed) state = AsyncData(before);
      return e is ApiException ? e.message : 'Could not save your profile.';
    }
  }
}

final profileControllerProvider =
    AsyncNotifierProvider.autoDispose.family<ProfileController, ProfileState, int>(ProfileController.new);
