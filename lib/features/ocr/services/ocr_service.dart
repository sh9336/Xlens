import 'dart:io';
import 'dart:developer' as developer;
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../models/ocr_result.dart';

class OcrService {
  final _textRecognizer = TextRecognizer();

  Future<OcrResult> processImage(File imageFile) async {
    try {
      // Validate file exists
      if (!await imageFile.exists()) {
        developer.log('Image file not found: ${imageFile.path}');
        throw Exception('Image file not found');
      }

      developer.log('Processing image: ${imageFile.path}');
      
      final inputImage = InputImage.fromFile(imageFile);
      final recognizedText = await _textRecognizer.processImage(inputImage);
      
      developer.log('OCR completed. Text length: ${recognizedText.text.length}');
      
      if (recognizedText.text.isEmpty) {
        developer.log('No text detected in image');
      }

      return OcrResult(text: recognizedText.text);
    } on Exception catch (e) {
      developer.log('OCR processing error: $e', error: e);
      throw Exception('Failed to process image: ${e.toString()}');
    } catch (e) {
      developer.log('Unexpected error during OCR: $e', error: e);
      throw Exception('Unexpected error: $e');
    }
  }

  Future<File> cropImage(File imageFile) async {
    try {
      developer.log('Crop processing completed for image');
      // The actual cropping is handled in crop_screen.dart
      // This method can be used for post-processing if needed
      return imageFile;
    } on Exception catch (e) {
      developer.log('Crop error: $e', error: e);
      throw Exception('Failed to crop image: ${e.toString()}');
    }
  }

  void dispose() {
    try {
      _textRecognizer.close();
      developer.log('OcrService disposed successfully');
    } catch (e) {
      developer.log('Error disposing OcrService: $e');
    }
  }
}
