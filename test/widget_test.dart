import 'package:flutter_test/flutter_test.dart';
import 'package:ocrscanner/main.dart';

void main() {
  testWidgets('OCR App smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const OCRApp());

    // Verify that the app title is present
    expect(find.text('OCR Scanner Tool'), findsOneWidget);
  });
}
