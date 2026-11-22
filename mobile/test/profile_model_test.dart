import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:iniba/core/api_client.dart';
import 'package:iniba/features/profile/profile_model.dart';
import 'package:iniba/features/profile/profile_repository.dart';

// The example response from docs/api-doc.pdf 3.2.
const contractExample = {
  'studentId': 12,
  'name': 'Student Name',
  'batch': '2027',
  'department': 'Computer Science',
  'profilePhoto': 'https://cdn.iniba.pk/p/12.jpg',
  'bio': 'need coffee',
  'moodSticker': 'sleepy',
  'societies': ['IBA Tech Society'],
  'streak': 6,
  'tags': ['need coffee'],
  'posts': {
    'isMore': false,
    'items': [
      {'postId': 301, 'thumbnail': 'https://cdn.iniba.pk/301t.jpg', 'excerpt': 'Library grind'},
    ],
  },
};

void main() {
  test('Profile parses the API doc example', () {
    final p = Profile.fromJson(contractExample);
    expect(p.studentId, 12);
    expect(p.name, 'Student Name');
    expect(p.societies, ['IBA Tech Society']);
    expect(p.streak, 6);
    expect(p.tags, ['need coffee']);
    expect(p.posts.isMore, isFalse);
    expect(p.posts.items.single.postId, 301);
    expect(p.posts.items.single.excerpt, 'Library grind');
  });

  test('Profile tolerates nulls and a PATCH-style body without posts', () {
    final p = Profile.fromJson({'studentId': 3, 'name': null, 'societies': null, 'tags': null});
    expect(p.name, 'IBA student');
    expect(p.societies, isEmpty);
    expect(p.posts.items, isEmpty);
  });

  test('HttpProfileRepository sends the token and paging params', () async {
    late http.Request seen;
    final client = MockClient((req) async {
      seen = req;
      return http.Response(jsonEncode(contractExample), 200);
    });
    final repo = HttpProfileRepository(ApiClient(baseUrl: 'http://10.0.2.2:8000/', token: 'abc', httpClient: client));

    final page = await repo.fetchPosts(12, offset: 20);
    expect(seen.url.toString(), 'http://10.0.2.2:8000/profile/12?offset=20&limit=20');
    expect(seen.headers['Authorization'], 'Bearer abc');
    expect(page.items.single.postId, 301);
  });

  test('API errors surface the {code, message} body', () async {
    final client = MockClient((_) async => http.Response('{"code": 404, "message": "Student not found"}', 404));
    final repo = HttpProfileRepository(ApiClient(baseUrl: 'http://x', httpClient: client));
    expect(
      () => repo.fetchProfile(9),
      throwsA(isA<ApiException>().having((e) => e.code, 'code', 404).having((e) => e.message, 'message', 'Student not found')),
    );
  });

  test('non-JSON errors still become ApiException', () async {
    final client = MockClient((_) async => http.Response('<html>bad gateway</html>', 502));
    final repo = HttpProfileRepository(ApiClient(baseUrl: 'http://x', httpClient: client));
    expect(() => repo.fetchProfile(1), throwsA(isA<ApiException>().having((e) => e.code, 'code', 502)));
  });
}
