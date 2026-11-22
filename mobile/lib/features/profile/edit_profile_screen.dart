import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'photo_crop.dart';
import 'profile_model.dart';
import 'profile_providers.dart';
import 'profile_repository.dart';

const kBioMax = 150;

/// Mood stickers offered by the picker (wireframe 3-5). Stored as the label; the emoji is display only.
const kMoods = <(String, String)>[
  ('need coffee', '☕'),
  ('midterms', '😵'),
  ('free day', '🎉'),
  ('studying', '📚'),
  ('hungry', '🍕'),
  ('late', '🏃'),
];

/// "☕ need coffee" for known moods, the plain label otherwise.
String moodLabel(String mood) {
  for (final (label, emoji) in kMoods) {
    if (label == mood) return '$emoji $label';
  }
  return mood;
}

/// Edit profile (SCRUM-34, wireframe 3-3): photo, bio, mood sticker and societies.
///
/// Save closes the screen at once and the profile shows the new values straight away (optimistic UI).
/// If the server refuses, the profile rolls back and a message explains why.
class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key, required this.studentId});

  final int studentId;

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  late final ProfileState _start;
  late final TextEditingController _bio;
  String? _mood;
  late List<String> _societies;
  Uint8List? _newPhoto;

  @override
  void initState() {
    super.initState();
    _start = ref.read(profileControllerProvider(widget.studentId)).requireValue;
    _bio = TextEditingController(text: _start.profile.bio ?? '')..addListener(() => setState(() {}));
    _mood = _start.profile.moodSticker;
    _societies = [..._start.profile.societies];
  }

  @override
  void dispose() {
    _bio.dispose();
    super.dispose();
  }

  bool get _dirty =>
      _newPhoto != null ||
      _bio.text != (_start.profile.bio ?? '') ||
      _mood != _start.profile.moodSticker ||
      !_sameList(_societies, _start.profile.societies);

  static bool _sameList(List<String> a, List<String> b) =>
      a.length == b.length && {...a}.containsAll(b);

  Future<void> _changePhoto() async {
    final picked = await ref.read(photoPickerProvider)();
    if (picked == null || !mounted) return;
    final cropped = await ref.read(photoCropperProvider)(context, picked);
    if (cropped != null && mounted) setState(() => _newPhoto = cropped);
  }

  Future<void> _pickMood() async {
    final chosen = await showModalBottomSheet<_MoodChoice>(
      context: context,
      showDragHandle: true,
      builder: (_) => _MoodSheet(current: _mood),
    );
    if (chosen != null) setState(() => _mood = chosen.mood);
  }

  Future<void> _addSociety() async {
    final options = kKnownSocieties.where((s) => !_societies.contains(s)).toList();
    if (options.isEmpty) return;
    final chosen = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(title: Text('Add a society')),
            for (final s in options) ListTile(title: Text(s), onTap: () => Navigator.of(context).pop(s)),
          ],
        ),
      ),
    );
    if (chosen != null) setState(() => _societies = [..._societies, chosen]);
  }

  Future<void> _save() async {
    if (!_dirty) {
      Navigator.of(context).pop();
      return;
    }
    final edit = ProfileEdit(
      bio: _bio.text.trim(),
      moodSticker: _mood,
      societies: _societies,
      photoJpeg: _newPhoto,
    );
    final messenger = ScaffoldMessenger.of(context);
    final notifier = ref.read(profileControllerProvider(widget.studentId).notifier);
    Navigator.of(context).pop();
    final error = await notifier.save(edit);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(error == null ? 'Profile saved.' : "Couldn't save: $error Your changes were undone."),
      ));
  }

  Future<void> _cancel() async {
    if (!_dirty) {
      Navigator.of(context).pop();
      return;
    }
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard changes?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Keep editing')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Discard')),
        ],
      ),
    );
    if (discard == true && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final labelStyle = theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final bioTooLong = _bio.text.trim().length > kBioMax;
    final mood = _mood;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _cancel();
      },
      child: Scaffold(
        appBar: AppBar(
          leadingWidth: 88,
          leading: TextButton(onPressed: _cancel, child: const Text('Cancel')),
          title: const Text('Edit profile'),
          centerTitle: true,
          actions: [
            TextButton(onPressed: bioTooLong ? null : _save, child: const Text('Save')),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            Center(
              child: ProfileAvatar(
                radius: 60,
                name: _start.profile.name,
                bytes: _newPhoto ?? _start.localPhoto,
                url: _start.profile.profilePhoto,
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: OutlinedButton(onPressed: _changePhoto, child: const Text('Change photo')),
            ),
            const SizedBox(height: 24),
            Text('Bio', style: labelStyle),
            const SizedBox(height: 8),
            TextField(
              key: const Key('bio-field'),
              controller: _bio,
              maxLines: 3,
              minLines: 1,
              maxLength: kBioMax,
              maxLengthEnforcement: MaxLengthEnforcement.enforced,
              decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'Say something short'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text('Mood sticker', style: labelStyle),
                const SizedBox(width: 12),
                ActionChip(
                  key: const Key('mood-chip'),
                  onPressed: _pickMood,
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(mood == null ? 'Pick a mood' : moodLabel(mood)),
                      const Icon(Icons.arrow_drop_down, size: 20),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text('Societies', style: labelStyle),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final s in _societies)
                  InputChip(
                    label: Text(s),
                    onDeleted: () => setState(() => _societies = [..._societies]..remove(s)),
                    deleteButtonTooltipMessage: 'Remove $s',
                  ),
                if (kKnownSocieties.any((s) => !_societies.contains(s)))
                  ActionChip(
                    key: const Key('add-society'),
                    avatar: const Icon(Icons.add, size: 18),
                    label: const Text('add'),
                    onPressed: _addSociety,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MoodChoice {
  const _MoodChoice(this.mood);
  final String? mood;
}

/// "Today's mood" bottom sheet (wireframe 3-5).
class _MoodSheet extends StatefulWidget {
  const _MoodSheet({required this.current});

  final String? current;

  @override
  State<_MoodSheet> createState() => _MoodSheetState();
}

class _MoodSheetState extends State<_MoodSheet> {
  late String? _selected = widget.current;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Today's mood", style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final (label, emoji) in kMoods)
                  ChoiceChip(
                    label: Text('$emoji $label'),
                    selected: _selected == label,
                    onSelected: (on) => setState(() => _selected = on ? label : null),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text("Pick anything, it's low stakes.", style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 16),
            Row(
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(const _MoodChoice(null)),
                  child: const Text('Clear mood'),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(_MoodChoice(_selected)),
                  child: const Text('Set mood'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Circular avatar: freshly cropped bytes first, then the photo URL, then the name's first letter.
class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({super.key, required this.radius, required this.name, this.bytes, this.url});

  final double radius;
  final String name;
  final Uint8List? bytes;
  final String? url;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final initial = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
    final fallback = Text(initial, style: TextStyle(fontSize: radius * 0.75, color: scheme.onPrimaryContainer));
    final side = radius * 2;
    final local = bytes;
    final remote = url;
    Widget child = fallback;
    if (local != null) {
      child = ClipOval(
        child: Image.memory(local, key: const Key('avatar-local'), width: side, height: side, fit: BoxFit.cover),
      );
    } else if (remote != null && remote.startsWith('http')) {
      child = ClipOval(
        child: Image.network(remote,
            width: side, height: side, fit: BoxFit.cover, errorBuilder: (_, _, _) => fallback),
      );
    }
    return CircleAvatar(radius: radius, backgroundColor: scheme.primaryContainer, child: child);
  }
}
