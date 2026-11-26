import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';
import 'edit_profile_screen.dart';
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
        // Your own profile is a bottom-nav tab, so it has no back button (wireframe 3.1).
        automaticallyImplyLeading: !isOwn,
        title: Text(isOwn ? 'Profile' : (state.valueOrNull?.profile.name ?? 'Profile')),
        bottom: (state.valueOrNull?.saving ?? false)
            ? const PreferredSize(
                preferredSize: Size.fromHeight(2),
                child: LinearProgressIndicator(key: Key('saving-indicator'), minHeight: 2),
              )
            : null,
        actions: [
          if (isOwn)
            TextButton(
              onPressed: () => context.push('/settings'),
              child: const Text('Settings'),
            ),
        ],
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

/// Header, then two tabs: Photos (3-column grid) and Text (a scrolling list).
class _ProfileBody extends StatefulWidget {
  const _ProfileBody({required this.data, required this.isOwn, required this.onLoadMore});

  final ProfileState data;
  final bool isOwn;
  final VoidCallback onLoadMore;

  @override
  State<_ProfileBody> createState() => _ProfileBodyState();
}

class _ProfileBodyState extends State<_ProfileBody> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this)..addListener(_onTab);

  void _onTab() {
    if (!_tabs.indexIsChanging) setState(() {});
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  /// Fetch the next page once the user is near the end of the posts this tab shows.
  void _maybeLoadMore(int index, int shown) {
    final data = widget.data;
    if (index >= shown - 6 && data.isMore && !data.loadingMore && data.loadMoreError == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => widget.onLoadMore());
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final photosTab = _tabs.index == 0;
    final shown = [
      for (final p in data.posts)
        if (p.hasPhoto == photosTab) p,
    ];
    if (shown.isEmpty && data.isMore && !data.loadingMore && data.loadMoreError == null) {
      // This tab has nothing loaded yet but more posts exist: keep fetching.
      WidgetsBinding.instance.addPostFrameCallback((_) => widget.onLoadMore());
    }
    final scheme = Theme.of(context).colorScheme;

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
          sliver: SliverToBoxAdapter(child: _Header(data: data, isOwn: widget.isOwn)),
        ),
        SliverPersistentHeader(
          pinned: true,
          delegate: _TabBarHeader(
            TabBar(
              key: const Key('post-tabs'),
              controller: _tabs,
              labelColor: scheme.onSurface,
              unselectedLabelColor: scheme.onSurfaceVariant,
              labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              unselectedLabelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w400),
              indicatorColor: scheme.onSurface,
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: scheme.outlineVariant.withValues(alpha: 0.6),
              tabs: const [Tab(text: 'Photos'), Tab(text: 'Text')],
            ),
          ),
        ),
        if (shown.isEmpty && !data.isMore)
          SliverPadding(
            padding: const EdgeInsets.all(32),
            sliver: SliverToBoxAdapter(
              child: Center(
                child: Text(data.posts.isEmpty ? 'No posts yet' : (photosTab ? 'No photos yet' : 'No text posts yet')),
              ),
            ),
          )
        else if (photosTab)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
            sliver: SliverGrid.builder(
              key: const Key('post-grid'),
              itemCount: shown.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 6,
                mainAxisSpacing: 6,
              ),
              itemBuilder: (context, index) {
                _maybeLoadMore(index, shown.length);
                return _PostTile(post: shown[index]);
              },
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
            sliver: SliverList.separated(
              key: const Key('text-list'),
              itemCount: shown.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                _maybeLoadMore(index, shown.length);
                return _TextPostCard(post: shown[index]);
              },
            ),
          ),
        SliverToBoxAdapter(child: _GridFooter(data: data, onLoadMore: widget.onLoadMore)),
      ],
    );
  }
}

class _TabBarHeader extends SliverPersistentHeaderDelegate {
  const _TabBarHeader(this.tabBar);

  final TabBar tabBar;

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) =>
      ColoredBox(color: Theme.of(context).colorScheme.surface, child: tabBar);

  @override
  bool shouldRebuild(_TabBarHeader old) => old.tabBar != tabBar;
}

class _Header extends StatelessWidget {
  const _Header({required this.data, required this.isOwn});

  final ProfileState data;
  final bool isOwn;

  @override
  Widget build(BuildContext context) {
    final profile = data.profile;
    final theme = Theme.of(context);
    // Wireframe 3.1: "2027 · Business · Debating" as one line under the name.
    final details = [
      if (profile.batch case final b? when b.isNotEmpty) b,
      if (profile.department case final d? when d.isNotEmpty) d,
      ...profile.societies,
    ].join(' · ');
    final mood = profile.moodSticker;
    final bio = profile.bio;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ProfileAvatar(radius: 42, name: profile.name, bytes: data.localPhoto, url: profile.profilePhoto),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(profile.name,
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700, fontSize: 17)),
                  if (details.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      details,
                      key: const Key('profile-details'),
                      style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        if (mood != null && mood.isNotEmpty) ...[
          const SizedBox(height: 14),
          Pill(key: const Key('mood-pill'), label: 'Mood: ${moodLabel(mood)}'),
        ],
        if (bio != null && bio.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(bio, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ],
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 8,
          children: [
            Pill(key: const Key('streak-pill'), label: '${profile.streak} day streak', dashed: true),
            for (final t in profile.tags) Pill(label: '#$t', dashed: true),
          ],
        ),
        if (isOwn) ...[
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: data.saving
                  ? null
                  : () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => EditProfileScreen(studentId: profile.studentId),
                          fullscreenDialog: true,
                        ),
                      ),
              child: const Text('Edit profile'),
            ),
          ),
        ],
      ],
    );
  }
}

/// Rounded badge. Solid outline for the mood; dashed outline for streak and tags (wireframe 3.1).
class Pill extends StatelessWidget {
  const Pill({super.key, required this.label, this.dashed = false});

  final String label;
  final bool dashed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Text(label, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13));
    if (!dashed) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: scheme.outline),
        ),
        child: text,
      );
    }
    return CustomPaint(
      painter: _DashedBorderPainter(color: scheme.outlineVariant, radius: 8),
      child: Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), child: text),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final rect = RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)).deflate(0.6);
    for (final metric in (Path()..addRRect(rect)).computeMetrics()) {
      for (double d = 0; d < metric.length; d += 7) {
        canvas.drawPath(metric.extractPath(d, d + 4), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter old) => old.color != color || old.radius != radius;
}

class _PostTile extends StatelessWidget {
  const _PostTile({required this.post});

  final PostThumb post;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final placeholder = Icon(Icons.image_outlined, color: scheme.onSurfaceVariant);
    return Material(
      color: scheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: Key('post-${post.postId}'),
        onTap: () => _showSoon(context, 'Full post view is coming soon.'),
        child: Image.network(
          post.thumbnail!,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => Center(child: placeholder),
        ),
      ),
    );
  }
}

/// A text post in the Text tab. The profile API sends the first 60 characters, so long posts end in "…".
class _TextPostCard extends StatelessWidget {
  const _TextPostCard({required this.post});

  final PostThumb post;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: Key('post-${post.postId}'),
        onTap: () => _showSoon(context, 'Full post view is coming soon.'),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Text(textPostLabel(post.excerpt ?? ''), style: Theme.of(context).textTheme.bodyLarge),
        ),
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

void _showSoon(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

/// The profile API cuts post text at this many characters (backend `EXCERPT_LEN`).
const kExcerptLen = 60;

/// Adds "…" when the excerpt is as long as the API's cut-off, so a cut post doesn't look finished.
String textPostLabel(String excerpt) => excerpt.length >= kExcerptLen ? '${excerpt.trimRight()}…' : excerpt;
