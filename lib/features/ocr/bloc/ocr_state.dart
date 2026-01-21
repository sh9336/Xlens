import 'dart:io';
import 'package:equatable/equatable.dart';
import '../models/ocr_result.dart';

enum OcrStatus { initial, imageReady, cropReady, processing, success, failure }

class OcrState extends Equatable {
  final OcrStatus status;
  final File? image;
  final File? croppedImage;
  final OcrResult? result;
  final String? errorMessage;

  const OcrState({
    this.status = OcrStatus.initial,
    this.image,
    this.croppedImage,
    this.result,
    this.errorMessage,
  });

  OcrState copyWith({
    OcrStatus? status,
    File? image,
    File? croppedImage,
    OcrResult? result,
    String? errorMessage,
  }) {
    return OcrState(
      status: status ?? this.status,
      image: image ?? this.image,
      croppedImage: croppedImage ?? this.croppedImage,
      result: result ?? this.result,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, image, croppedImage, result, errorMessage];
}
