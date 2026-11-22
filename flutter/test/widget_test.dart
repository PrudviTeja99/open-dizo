import 'package:flutter_test/flutter_test.dart';
import 'package:dizo_watch_sync/app.dart';

void main() {
  testWidgets('App renders dashboard smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const DizoWatchApp());
    expect(find.text('DIZO Watch D'), findsOneWidget);
  });
}
