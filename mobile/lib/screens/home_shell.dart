import 'package:flutter/material.dart';

import 'create_post_screen.dart';
import 'feed_screen.dart';
import '../features/profile/profile_screen.dart';
import 'search_screen.dart';

/// Bottom-nav shell for the four core features: Feed, Search, Create, Profile.
///
/// Matches the wireframes: text tabs (the current one in bold) and a round "+" in the middle for posting.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  static const _screens = [
    FeedScreen(),
    SearchScreen(),
    CreatePostScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    void go(int i) => setState(() => _index = i);

    return Scaffold(
      body: _screens[_index],
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surface,
          border: Border(top: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6))),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 64,
            child: Row(
              children: [
                _TextTab(label: 'Feed', selected: _index == 0, onTap: () => go(0)),
                _TextTab(label: 'Search', selected: _index == 1, onTap: () => go(1)),
                Expanded(
                  child: Center(
                    child: Semantics(
                      button: true,
                      selected: _index == 2,
                      label: 'Post',
                      child: InkResponse(
                        key: const Key('nav-post'),
                        onTap: () => go(2),
                        radius: 26,
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _index == 2 ? scheme.onSurface : scheme.surface,
                            border: Border.all(color: scheme.onSurface, width: 1.5),
                          ),
                          child: Icon(Icons.add, size: 24, color: _index == 2 ? scheme.surface : scheme.onSurface),
                        ),
                      ),
                    ),
                  ),
                ),
                _TextTab(label: 'Profile', selected: _index == 3, onTap: () => go(3)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TextTab extends StatelessWidget {
  const _TextTab({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        child: InkWell(
          onTap: onTap,
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                color: selected ? scheme.onSurface : scheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
