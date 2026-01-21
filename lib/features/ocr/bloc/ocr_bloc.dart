import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:developer' as developer;
import '../services/ocr_service.dart';
import '../services/temp_file_manager.dart';
import 'ocr_event.dart';
import 'ocr_state.dart';

class OcrBloc extends Bloc<OcrEvent, OcrState> {
  final OcrService _ocrService;

  OcrBloc(this._ocrService) : super(const OcrState()) {
    on<OcrImagePickedEvent>(_onImagePicked);
    on<OcrCroppedImageEvent>(_onCroppedImage);
    on<OcrProcessImageEvent>(_onProcessImage);
    on<OcrClearEvent>(_onClear);
  }

  void _onImagePicked(OcrImagePickedEvent event, Emitter<OcrState> emit) {
    developer.log('Image picked: ${event.image.path}');
    emit(
      state.copyWith(
        status: OcrStatus.imageReady,
        image: event.image,
        result: null,
        errorMessage: null,
      ),
    );
  }

  void _onCroppedImage(OcrCroppedImageEvent event, Emitter<OcrState> emit) {
    developer.log('Image cropped, ready for OCR');
    emit(
      state.copyWith(
        status: OcrStatus.cropReady,
        croppedImage: event.croppedImage,
      ),
    );
  }

  Future<void> _onProcessImage(
    OcrProcessImageEvent event,
    Emitter<OcrState> emit,
  ) async {
    // Use cropped image if available, otherwise use original
    final imageToProcess = state.croppedImage ?? state.image;

    if (imageToProcess == null) {
      developer.log('No image available for processing');
      emit(
        state.copyWith(
          status: OcrStatus.failure,
          errorMessage:
              'No image available. Please capture or select an image first.',
        ),
      );
      return;
    }

    emit(state.copyWith(status: OcrStatus.processing));

    try {
      developer.log('Starting OCR processing');
      final result = await _ocrService.processImage(imageToProcess);

      if (result.text.isEmpty) {
        developer.log('No text detected in image');
        emit(
          state.copyWith(
            status: OcrStatus.failure,
            errorMessage:
                'No text detected in the image. Try with a clearer image.',
          ),
        );
      } else {
        developer.log('OCR successful: ${result.text.length} characters');
        emit(state.copyWith(status: OcrStatus.success, result: result));
      }
    } catch (e) {
      developer.log('Error during OCR: $e', error: e);
      emit(
        state.copyWith(
          status: OcrStatus.failure,
          errorMessage: e.toString().replaceFirst('Exception: ', ''),
        ),
      );
    }
  }

  void _onClear(OcrClearEvent event, Emitter<OcrState> emit) {
    developer.log('Clearing OCR state');
    emit(const OcrState(status: OcrStatus.initial));
  }

  @override
  Future<void> close() async {
    developer.log('Disposing OcrBloc and OcrService');
    developer.log('Disposing OcrBloc');
    // _ocrService.dispose(); // Do not dispose service injected from outside

    // Clean up all temporary OCR files when bloc is disposed
    await TempFileManager.cleanupAll();

    return super.close();
  }
}
