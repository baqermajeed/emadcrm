import 'package:emad_crm/core/api_client.dart';
import 'package:emad_crm/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('App boots', (tester) async {
    await tester.pumpWidget(EmadCrmApp(api: ApiClient()));
    await tester.pump();
    expect(find.byType(EmadCrmApp), findsOneWidget);
  });
}
