import 'package:flutter_test/flutter_test.dart';
import 'package:orbit/main.dart';

void main() {
  testWidgets('app starts on the splash screen', (WidgetTester tester) async {
    await tester.pumpWidget(const OrbitApp());
    await tester.pumpAndSettle();

    expect(find.text('Splash'), findsOneWidget);
  });
}
