import 'package:flutter_test/flutter_test.dart';
import 'package:open_dizo/app.dart';

void main() {
  testWidgets('App renders dashboard smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const DizoWatchApp());
    expect(find.text('Open Dizo'), findsOneWidget);
  });
}
