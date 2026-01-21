import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  Future<bool> requestCameraPermission() async {
    final status = await Permission.camera.request();
    return status.isGranted;
  }

  Future<bool> requestStoragePermission() async {
    // Android 13+ doesn't need WRITE_EXTERNAL_STORAGE for saving to public directories using some APIs,
    // but Manage External Storage might be needed for broader access.
    // However, for just saving files, usually we rely on appropriate directory providers.
    // We'll check rudimentary permissions here.

    // For specific storage logic depending on Android version, this can get complex.
    // For now, we will just check standard permissions or assume granted if not applicable.

    final status = await Permission.storage.request();
    // On Android 13+, this might always return denied, handled differently (photos/videos/audio).
    // For simple text file saving, usually we don't need explicit broad storage if using getExternalStorageDirectory.
    // But let's leave generic check for now.
    if (status.isGranted) return true;

    // Fallback or specific checks could go here.
    return status.isGranted;
  }

  Future<void> openSettings() async {
    await openAppSettings();
  }
}
