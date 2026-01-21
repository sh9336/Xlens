import 'dart:io';
import 'dart:developer' as developer;

/// Manages temporary OCR files to prevent storage bloat
class TempFileManager {
  static const String _ocrPrefix = 'ocr_cropped_';
  static const int _maxAgeMinutes = 60; // Keep files for 1 hour

  /// Cleans up old temporary OCR files
  /// Returns the number of files deleted
  static Future<int> cleanupOldFiles() async {
    try {
      final tempDir = Directory.systemTemp;
      final files = tempDir.listSync();
      
      int deletedCount = 0;
      final now = DateTime.now();

      for (final entity in files) {
        if (entity is File && entity.path.contains(_ocrPrefix)) {
          try {
            final stat = await entity.stat();
            final fileAge = now.difference(stat.modified);

            if (fileAge.inMinutes > _maxAgeMinutes) {
              await entity.delete();
              developer.log('Deleted old temp file: ${entity.path}');
              deletedCount++;
            }
          } catch (e) {
            developer.log('Error checking temp file age: $e');
          }
        }
      }

      if (deletedCount > 0) {
        developer.log('Cleaned up $deletedCount old temporary files');
      }
      
      return deletedCount;
    } catch (e) {
      developer.log('Error during temp file cleanup: $e');
      return 0;
    }
  }

  /// Immediately deletes a specific temp file
  static Future<bool> deleteFile(File file) async {
    try {
      if (await file.exists()) {
        await file.delete();
        developer.log('Deleted temp file: ${file.path}');
        return true;
      }
      return false;
    } catch (e) {
      developer.log('Error deleting temp file: $e');
      return false;
    }
  }

  /// Cleans up all OCR temporary files
  static Future<int> cleanupAll() async {
    try {
      final tempDir = Directory.systemTemp;
      final files = tempDir.listSync();
      
      int deletedCount = 0;

      for (final entity in files) {
        if (entity is File && entity.path.contains(_ocrPrefix)) {
          try {
            await entity.delete();
            developer.log('Deleted temp file: ${entity.path}');
            deletedCount++;
          } catch (e) {
            developer.log('Error deleting temp file: $e');
          }
        }
      }

      developer.log('Cleaned up all $deletedCount temporary files');
      return deletedCount;
    } catch (e) {
      developer.log('Error during complete temp cleanup: $e');
      return 0;
    }
  }
}
