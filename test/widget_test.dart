import 'package:flutter_test/flutter_test.dart';
import 'package:novexps/app/app.dart';

void main() {
  testWidgets('NovaExpressApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const NovaExpressApp());
    expect(find.byType(NovaExpressApp), findsOneWidget);
  });
}
