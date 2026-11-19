import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// What the student chose on the preview screen.
enum PreviewChoice { use, retake }

/// SCRUM-74: full-screen preview of the photo just taken, with Retake / Use photo.
/// Pops with a [PreviewChoice]; the back button counts as cancel (null).
class PhotoPreviewScreen extends StatelessWidget {
  const PhotoPreviewScreen({super.key, required this.photo});

  final XFile photo;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Preview'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(child: Center(child: PhotoView(photo: photo))),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
                      onPressed: () => Navigator.of(context).pop(PreviewChoice.retake),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retake'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => Navigator.of(context).pop(PreviewChoice.use),
                      icon: const Icon(Icons.check),
                      label: const Text('Use photo'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shows an [XFile]. Reads the bytes instead of using Image.file, so the same
/// code works on every platform (Image.file needs dart:io, which web lacks).
class PhotoView extends StatefulWidget {
  const PhotoView({super.key, required this.photo, this.fit = BoxFit.contain});

  final XFile photo;
  final BoxFit fit;

  @override
  State<PhotoView> createState() => _PhotoViewState();
}

class _PhotoViewState extends State<PhotoView> {
  // Read the file once, not on every rebuild.
  late Future<Uint8List> _bytes = widget.photo.readAsBytes();

  @override
  void didUpdateWidget(PhotoView old) {
    super.didUpdateWidget(old);
    if (old.photo.path != widget.photo.path) _bytes = widget.photo.readAsBytes();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List>(
      future: _bytes,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Text('Could not load the photo', style: TextStyle(color: Colors.grey));
        }
        if (!snapshot.hasData) return const CircularProgressIndicator();
        return Image.memory(snapshot.data!, fit: widget.fit);
      },
    );
  }
}
