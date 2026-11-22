import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../auth_controller.dart';
import '../widgets/error_text.dart';

/// Wireframe 1.7 - first login profile setup.
class ProfileSetupScreen extends ConsumerStatefulWidget {
  const ProfileSetupScreen({super.key});
  @override
  ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _batch = TextEditingController();
  final _dept = TextEditingController();
  final _societies = TextEditingController();
  String? _photoPath;
  String? _photoError;

  @override
  void dispose() {
    _name.dispose();
    _batch.dispose();
    _dept.dispose();
    _societies.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) {
      return;
    }
    final bytes = await File(picked.path).readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final img = (await codec.getNextFrame()).image;
    if (img.width < 400 || img.height < 400) {
      setState(() => _photoError = 'Image must be at least 400×400 px.');
      return;
    }
    if (img.width != img.height) {
      setState(() => _photoError = 'Photo must be square (1:1).');
      return;
    }
    setState(() {
      _photoPath = picked.path;
      _photoError = null;
    });
  }

  Future<void> _submit() async {
    if (_photoPath == null) {
      setState(() => _photoError = 'Please add a photo.');
    }
    if (!_formKey.currentState!.validate() || _photoPath == null) {
      return;
    }
    await ref
        .read(authProvider.notifier)
        .completeProfile(
          fullName: _name.text.trim(),
          batch: _batch.text.trim(),
          department: _dept.text.trim(),
          societies: _societies.text.trim(),
          photoPath: _photoPath!,
        );
    // On success the router redirects to /feed.
  }

  String? _required(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Required.' : null;

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Set up your profile'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        GestureDetector(
                          onTap: _pickPhoto,
                          child: CircleAvatar(
                            radius: 48,
                            backgroundColor: Colors.grey.shade200,
                            backgroundImage: _photoPath != null
                                ? FileImage(File(_photoPath!))
                                : null,
                            child: _photoPath == null
                                ? const Icon(
                                    Icons.person_outline,
                                    size: 40,
                                    color: Colors.grey,
                                  )
                                : null,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: _pickPhoto,
                          child: const Text('Add photo (square, min 400×400)'),
                        ),
                        ErrorText(_photoError),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _name,
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(
                            hintText: 'Full name',
                          ),
                          validator: _required,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _batch,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            hintText: 'Batch (e.g. 2026)',
                          ),
                          validator: _required,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _dept,
                          decoration: const InputDecoration(
                            hintText: 'Department',
                          ),
                          validator: _required,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _societies,
                          decoration: const InputDecoration(
                            hintText: 'Societies (optional)',
                          ),
                        ),
                        ErrorText(auth.error),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: auth.isLoading ? null : _submit,
                  child: auth.isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Continue to feed'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
