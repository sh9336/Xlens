import 'dart:io';
import 'package:equatable/equatable.dart';

abstract class OcrEvent extends Equatable {
  const OcrEvent();

  @override
  List<Object?> get props => [];
}

class OcrImagePickedEvent extends OcrEvent {
  final File image;

  const OcrImagePickedEvent(this.image);

  @override
  List<Object?> get props => [image];
}

class OcrCroppedImageEvent extends OcrEvent {
  final File croppedImage;

  const OcrCroppedImageEvent(this.croppedImage);

  @override
  List<Object?> get props => [croppedImage];
}

class OcrProcessImageEvent extends OcrEvent {
  @override
  List<Object?> get props => [];
}

class OcrClearEvent extends OcrEvent {}
