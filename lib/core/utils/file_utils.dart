import 'dart:io';
import 'package:intl/intl.dart';

class FileUtils {
  static String generateFileName(String extension) {
    final now = DateTime.now();
    final formatter = DateFormat('yyyyMMdd_HHmmss');
    return 'OCR_${formatter.format(now)}.$extension';
  }

  static String getFileSizeString(File file) {
    int bytes = file.lengthSync();
    if (bytes <= 0) return "0 B";
    const suffixes = ["B", "KB", "MB", "GB", "TB", "PB", "EB", "ZB", "YB"];
    var i = (bytes.bitLength - 1) ~/ 10; // Log base 1024 approximation
    // Fixing minimal case
    if (i < 0) i = 0;
    if (i >= suffixes.length) i = suffixes.length - 1;

    // Calculate size
    double size = bytes / (1 << (i * 10)); // 1024^i
    return "${size.toStringAsFixed(1)} ${suffixes[i]}";
  }
}
