import 'dart:convert';

import '../../core/api_client.dart';
import 'profile_model.dart';

const kPostPageSize = 20;

abstract class ProfileRepository {
  /// Profile header plus the first page of the post grid.
  Future<Profile> fetchProfile(int studentId, {int limit = kPostPageSize});

  /// A later page of the post grid.
  Future<PagedList<PostThumb>> fetchPosts(int studentId, {required int offset, int limit = kPostPageSize});

  /// Owner-only edit. Returns the updated profile (without posts).
  Future<Profile> updateProfile(int studentId, ProfileEdit edit);
}

/// Societies the app offers when adding one. There is no `GET /societies` endpoint yet, so this mirrors
/// the names `backend/scripts/seed.py` creates; the backend rejects any other name with 400.
const kKnownSocieties = [
  'Debating Society',
  'Drama Society',
  'IEEE',
  'Music Society',
  'Entrepreneurship Club',
];

/// Talks to `GET /profile/{id}` on the backend.
class HttpProfileRepository implements ProfileRepository {
  HttpProfileRepository(this._api);

  final ApiClient _api;

  @override
  Future<Profile> fetchProfile(int studentId, {int limit = kPostPageSize}) async {
    final json = await _api.getJson('/profile/$studentId', query: {'offset': 0, 'limit': limit});
    return Profile.fromJson(json);
  }

  @override
  Future<PagedList<PostThumb>> fetchPosts(int studentId, {required int offset, int limit = kPostPageSize}) async {
    final json = await _api.getJson('/profile/$studentId', query: {'offset': offset, 'limit': limit});
    return Profile.fromJson(json).posts;
  }

  @override
  Future<Profile> updateProfile(int studentId, ProfileEdit edit) async {
    final photo = edit.photoJpeg;
    final Map<String, dynamic> json;
    if (photo == null) {
      json = await _api.sendJson('PATCH', '/profile/$studentId', edit.toJson());
    } else {
      json = await _api.sendMultipart(
        'PATCH',
        '/profile/$studentId',
        fields: {
          'bio': edit.bio,
          'moodSticker': edit.moodSticker ?? '',
          'societies': jsonEncode(edit.societies),
        },
        files: {'profilePhoto': ('profile.jpg', photo)},
      );
    }
    return Profile.fromJson(json);
  }
}

/// In-memory sample data, used when no `API_BASE_URL` is given and in tests.
class FakeProfileRepository implements ProfileRepository {
  FakeProfileRepository({
    this.latency = const Duration(milliseconds: 250),
    Map<int, Profile>? profiles,
    Map<int, int>? postCounts,
    this.failWith,
  })  : _profiles = Map.of(profiles ?? sampleProfiles),
        _postCounts = postCounts ?? const {1: 45, 2: 9, 3: 0};

  final Duration latency;
  final Map<int, Profile> _profiles;
  final Map<int, int> _postCounts;

  /// When set, every call throws this (to exercise error states).
  ApiException? failWith;

  int fetchProfileCalls = 0;
  int fetchPostsCalls = 0;
  final List<ProfileEdit> edits = [];

  static const sampleProfiles = {
    1: Profile(
      studentId: 1,
      name: 'Fatima K.',
      batch: '2027',
      department: 'Business',
      bio: 'spreadsheet enthusiast, tea over coffee.',
      moodSticker: 'need coffee',
      societies: ['Debating Society'],
      streak: 7,
      tags: ['nightowl', 'chai'],
    ),
    2: Profile(
      studentId: 2,
      name: 'Sara A.',
      batch: '2027',
      department: 'Business',
      bio: 'library resident.',
      moodSticker: 'midterms',
      streak: 12,
      tags: ['earlybird'],
    ),
    3: Profile(studentId: 3, name: 'Hamza K.', batch: '2026', department: 'Computer Science'),
  };

  static const _captions = [
    'Library grind before midterms',
    'Chai at the cafeteria',
    'Debate practice ran late',
    'Sunset from AMAN Tower',
    'CED lab, again',
  ];

  Future<void> _wait() async {
    if (latency > Duration.zero) await Future<void>.delayed(latency);
    final error = failWith;
    if (error != null) throw error;
  }

  PagedList<PostThumb> _page(int studentId, int offset, int limit) {
    final total = _postCounts[studentId] ?? 0;
    final end = (offset + limit).clamp(0, total);
    return PagedList(
      isMore: end < total,
      items: [
        for (var i = offset; i < end; i++)
          PostThumb(
            postId: studentId * 1000 + total - i,
            thumbnail: i % 3 == 0 ? 'https://example.invalid/posts/${studentId * 1000 + total - i}.jpg' : null,
            excerpt: _captions[i % _captions.length],
          ),
      ],
    );
  }

  @override
  Future<Profile> fetchProfile(int studentId, {int limit = kPostPageSize}) async {
    fetchProfileCalls++;
    await _wait();
    final p = _profiles[studentId];
    if (p == null) throw ApiException(404, 'Student not found');
    return Profile(
      studentId: p.studentId,
      name: p.name,
      batch: p.batch,
      department: p.department,
      profilePhoto: p.profilePhoto,
      bio: p.bio,
      moodSticker: p.moodSticker,
      societies: p.societies,
      streak: p.streak,
      tags: p.tags,
      posts: _page(studentId, 0, limit),
    );
  }

  @override
  Future<PagedList<PostThumb>> fetchPosts(int studentId, {required int offset, int limit = kPostPageSize}) async {
    fetchPostsCalls++;
    await _wait();
    return _page(studentId, offset, limit);
  }

  @override
  Future<Profile> updateProfile(int studentId, ProfileEdit edit) async {
    edits.add(edit);
    await _wait();
    final p = _profiles[studentId];
    if (p == null) throw ApiException(404, 'Student not found');
    final updated = p.copyWith(
      bio: edit.bio,
      moodSticker: edit.moodSticker,
      clearMood: edit.moodSticker == null,
      societies: [...edit.societies]..sort(),
      profilePhoto: edit.photoJpeg == null ? null : 'fake://photo/${edits.length}.jpg',
    );
    _profiles[studentId] = updated;
    return updated;
  }
}
