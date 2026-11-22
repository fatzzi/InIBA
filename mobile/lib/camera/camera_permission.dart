import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

/// Result of asking for the camera (SCRUM-73).
enum CameraAccess {
  /// Allowed, the camera can be opened.
  granted,

  /// Refused this time; asking again will show the system prompt again.
  denied,

  /// Refused with "Don't ask again" (or blocked by the device). Only the
  /// phone's Settings app can turn it back on.
  blocked,

  /// This platform has no camera support in the app (desktop / web).
  unsupported,
}

/// True on Android and iOS, the only platforms the camera flow targets.
bool get cameraSupported =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS);

/// Shows the system permission prompt if needed and reports the outcome.
Future<CameraAccess> requestCameraAccess() async {
  if (!cameraSupported) return CameraAccess.unsupported;

  final status = await Permission.camera.request();
  if (status.isGranted || status.isLimited) return CameraAccess.granted;
  if (status.isPermanentlyDenied || status.isRestricted) return CameraAccess.blocked;
  return CameraAccess.denied;
}

/// Opens this app's page in the phone's Settings so the student can allow the camera.
Future<void> openCameraSettings() => openAppSettings();
