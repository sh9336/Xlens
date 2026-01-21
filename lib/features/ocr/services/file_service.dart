import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:developer' as developer;
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../../../../core/utils/file_utils.dart';

class FileService {
  static const platform = MethodChannel('com.example.ocrscanner/downloads');

  Future<bool> _requestPermission() async {
    if (Platform.isAndroid) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      // Android 10+ (SDK 29+) doesn't need WRITE_EXTERNAL_STORAGE for Downloads via MediaStore
      if (androidInfo.version.sdkInt >= 29) {
        return true;
      } else {
        // Android 9 and below need storage permission
        final status = await Permission.storage.request();
        return status.isGranted;
      }
    }
    return true; // iOS or others
  }

  Future<String> saveTextFile(String text) async {
    try {
      developer.log('Saving text file via MethodChannel...');

      final hasPermission = await _requestPermission();
      if (!hasPermission) {
        throw Exception('Storage permission denied');
      }

      final fileName = FileUtils.generateFileName('txt');
      // Use utf8.encode to correctly handle various characters
      final bytes = Uint8List.fromList(utf8.encode(text));

      final result = await platform.invokeMethod('saveToDownloads', {
        'bytes': bytes,
        'fileName': fileName,
      });

      developer.log('Text file saved successfully: $result');
      return result as String;
    } catch (e) {
      developer.log('Error saving text file: $e', error: e);
      throw Exception('Failed to save text file: $e');
    }
  }

  Future<String> savePdfFile(String text) async {
    try {
      developer.log('Saving PDF file via MethodChannel...');

      final hasPermission = await _requestPermission();
      if (!hasPermission) {
        throw Exception('Storage permission denied');
      }

      final pdf = pw.Document();
      // Use standard font to avoid "Unicode support" warning/error
      final font = pw.Font.courier();

      // Use MultiPage to automatically handle pagination
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context context) {
            return [
              pw.Header(
                level: 0,
                child: pw.Text(
                  'Extracted Text',
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                    font: font,
                  ),
                ),
              ),
              pw.Paragraph(
                text: text,
                style: pw.TextStyle(fontSize: 11, font: font, lineSpacing: 1.5),
              ),
            ];
          },
        ),
      );

      final fileName = FileUtils.generateFileName('pdf');
      final bytes = await pdf.save();

      final result = await platform.invokeMethod('saveToDownloads', {
        'bytes': bytes,
        'fileName': fileName,
      });

      developer.log('PDF file saved successfully: $result');
      return result as String;
    } catch (e) {
      developer.log('Error saving PDF file: $e', error: e);
      throw Exception('Failed to save PDF file: $e');
    }
  }
}
