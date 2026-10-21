import 'package:emad_crm/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('App boots', (tester) async {
    await tester.pumpWidget(const EmadCrmApp());
    await tester.pump();
    expect(find.byType(EmadCrmApp), findsOneWidget);
  });
}
