import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import 'profile_model.dart';
import 'profile_providers.dart';

/// View Profile (SCRUM-33, wireframes 3-1 and 3-2).
///
/// `studentId == null` (or the logged-in id) shows your own profile with an Edit button; any other id shows
/// that student's profile read-only. Highlights, spotted-at and report are separate stories.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key, this.studentId});

  final int? studentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(currentStudentIdProvider);
    final id = studentId ?? me;
    final isOwn = id == me;
    final provider = profileControllerProvider(id);
    final state = ref.watch(provider);

    return Scaffold(
      appBar: AppBar(
        title: Text(isOwn ? 'Profile' : (state.valueOrNull?.profile.name ?? 'Profile')),
      ),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _ErrorView(
          message: error is ApiException ? error.message : 'Could not load this profile.',
          onRetry: () => ref.invalidate(provider),
        ),
        data: (data) => RefreshIndicator(
          onRefresh: () => ref.refresh(provider.future),
          child: _ProfileBody(
            data: data,
            isOwn: isOwn,
            onLoadMore: () => ref.read(provider.notifier).loadMore(),
          ),
        ),
      ),
    );
  }
}

class _ProfileBody extends StatelessWidget {
  const _ProfileBody({required this.data, required this.isOwn, required this.onLoadMore});

  final ProfileState data;
  final bool isOwn;
  final VoidCallback onLoadMore;

  @override
  Widget build(BuildContext context) {
    final posts = data.posts;
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          sliver: SliverToBoxAdapter(child: _Header(profile: data.profile, isOwn: isOwn)),
        ),
        if (posts.isEmpty && !data.isMore)
          const SliverPadding(
            padding: EdgeInsets.all(32),
            sliver: SliverToBoxAdapter(child: Center(child: Text('No posts yet'))),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverGrid.builder(
              key: const Key('post-grid'),
              itemCount: posts.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 6,
                mainAxisSpacing: 6,
              ),
              itemBuilder: (context, index) {
                if (index >= posts.length - 6 && data.isMore && !data.loadingMore && data.loadMoreError == null) {
                  // Near the end of what is loaded: fetch the next page after this frame.
                  WidgetsBinding.instance.addPostFrameCallback((_) => onLoadMore());
                }
                return _PostTile(post: posts[index]);
              },
            ),
          ),
        SliverToBoxAdapter(child: _GridFooter(data: data, onLoadMore: onLoadMore)),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.profile, required this.isOwn});

  final Profile profile;
  final bool isOwn;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final badges = [
      if (profile.batch case final b? when b.isNotEmpty) b,
      if (profile.department case final d? when d.isNotEmpty) d,
      ...profile.societies,
    ];
    final mood = profile.moodSticker;
    final bio = profile.bio;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _Avatar(url: profile.profilePhoto, name: profile.name),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(profile.name, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [for (final b in badges) Pill(label: b)],
                  ),
                ],
              ),
            ),
          ],
        ),
        if (mood != null && mood.isNotEmpty) ...[
          const SizedBox(height: 16),
          Pill(key: const Key('mood-pill'), label: 'Mood: $mood', icon: Icons.emoji_emotions_outlined),
        ],
        if (bio != null && bio.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(bio, style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ],
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            Pill(
              key: const Key('streak-pill'),
              label: '${profile.streak} day streak',
              icon: Icons.local_fire_department_outlined,
              subtle: true,
            ),
            for (final t in profile.tags) Pill(label: '#$t', subtle: true),
          ],
        ),
        if (isOwn) ...[
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const _ComingSoonScreen(title: 'Edit profile')),
              ),
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('Edit profile'),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.url, required this.name});

  final String? url;
  final String name;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final initial = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
    final fallback = Text(initial, style: TextStyle(fontSize: 32, color: scheme.onPrimaryContainer));
    final photo = url;
    return CircleAvatar(
      radius: 44,
      backgroundColor: scheme.primaryContainer,
      child: photo == null || photo.isEmpty
          ? fallback
          : ClipOval(
              child: Image.network(
                photo,
                width: 88,
                height: 88,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => fallback,
              ),
            ),
    );
  }
}

/// Rounded badge used for batch, department, societies, mood, streak and tags.
class Pill extends StatelessWidget {
  const Pill({super.key, required this.label, this.icon, this.subtle = false});

  final String label;
  final IconData? icon;
  final bool subtle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: subtle ? scheme.surfaceContainerHighest : null,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: subtle ? scheme.outlineVariant : scheme.outline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: scheme.primary),
            const SizedBox(width: 4),
          ],
          Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }
}

class _PostTile extends StatelessWidget {
  const _PostTile({required this.post});

  final PostThumb post;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final excerpt = Padding(
      padding: const EdgeInsets.all(8),
      child: Text(
        post.excerpt ?? '',
        maxLines: 4,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
    final thumb = post.thumbnail;
    return Material(
      color: scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: Key('post-${post.postId}'),
        onTap: () => ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(content: Text('Full post view is coming soon.'))),
        child: thumb == null || thumb.isEmpty
            ? excerpt
            : Image.network(thumb, fit: BoxFit.cover, errorBuilder: (_, _, _) => excerpt),
      ),
    );
  }
}

class _GridFooter extends StatelessWidget {
  const _GridFooter({required this.data, required this.onLoadMore});

  final ProfileState data;
  final VoidCallback onLoadMore;

  @override
  Widget build(BuildContext context) {
    if (data.loadingMore) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final error = data.loadMoreError;
    if (error != null) {
      return Padding(
        padding: const EdgeInsets.all(8),
        child: Center(
          child: TextButton.icon(
            onPressed: onLoadMore,
            icon: const Icon(Icons.refresh),
            label: Text('$error Tap to retry.'),
          ),
        ),
      );
    }
    return const SizedBox(height: 24);
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 48),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

class _ComingSoonScreen extends StatelessWidget {
  const _ComingSoonScreen({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: const Center(child: Text('Coming soon.')),
    );
  }
}
