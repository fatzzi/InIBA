/// Models for `GET /profile/{id}` (API doc 3.2). Email is never part of a profile.
library;

class PostThumb {
  const PostThumb({required this.postId, this.thumbnail, this.excerpt});

  final int postId;
  final String? thumbnail;
  final String? excerpt;

  /// Photo posts go in the Photos grid; text-only posts go in the Text list.
  bool get hasPhoto => thumbnail != null && thumbnail!.isNotEmpty;

  factory PostThumb.fromJson(Map<String, dynamic> json) => PostThumb(
        postId: json['postId'] as int,
        thumbnail: json['thumbnail'] as String?,
        excerpt: json['excerpt'] as String?,
      );
}

/// One page of a paged list: `{isMore, items[]}` (API doc 1.2).
class PagedList<T> {
  const PagedList({required this.items, required this.isMore});

  final List<T> items;
  final bool isMore;

  factory PagedList.fromJson(Map<String, dynamic> json, T Function(Map<String, dynamic>) item) => PagedList(
        isMore: json['isMore'] as bool? ?? false,
        items: [
          for (final e in (json['items'] as List? ?? const []))
            item(e as Map<String, dynamic>),
        ],
      );
}

class Profile {
  const Profile({
    required this.studentId,
    required this.name,
    this.batch,
    this.department,
    this.profilePhoto,
    this.bio,
    this.moodSticker,
    this.societies = const [],
    this.streak = 0,
    this.tags = const [],
    this.posts = const PagedList(items: [], isMore: false),
  });

  final int studentId;
  final String name;
  final String? batch;
  final String? department;
  final String? profilePhoto;
  final String? bio;
  final String? moodSticker;
  final List<String> societies;
  final int streak;
  final List<String> tags;
  final PagedList<PostThumb> posts;

  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
        studentId: json['studentId'] as int,
        name: (json['name'] as String?) ?? 'IBA student',
        batch: json['batch'] as String?,
        department: json['department'] as String?,
        profilePhoto: json['profilePhoto'] as String?,
        bio: json['bio'] as String?,
        moodSticker: json['moodSticker'] as String?,
        societies: _strings(json['societies']),
        streak: json['streak'] as int? ?? 0,
        tags: _strings(json['tags']),
        posts: json['posts'] is Map<String, dynamic>
            ? PagedList.fromJson(json['posts'] as Map<String, dynamic>, PostThumb.fromJson)
            : const PagedList(items: [], isMore: false),
      );

  static List<String> _strings(Object? value) =>
      value is List ? [for (final v in value) '$v'] : const [];
}
