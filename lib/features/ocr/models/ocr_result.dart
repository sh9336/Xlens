import 'package:equatable/equatable.dart';

class OcrResult extends Equatable {
  final String text;
  final int characters;

  const OcrResult({required this.text}) : characters = text.length;

  @override
  List<Object?> get props => [text, characters];
}
