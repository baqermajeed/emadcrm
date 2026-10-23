import 'package:emad_crm/core/api_client.dart';
import 'package:emad_crm/core/cache_service.dart';
import 'package:emad_crm/main.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  testWidgets('App boots', (tester) async {
    Hive.init('./.dart_tool/test_hive');
    final box = await Hive.openBox<String>('widget_test_cache');
    await tester.pumpWidget(
      EmadCrmApp(
        api: ApiClient(),
        cache: CacheService(box),
      ),
    );
    await tester.pump();
    expect(find.byType(EmadCrmApp), findsOneWidget);
    await box.close();
  });
}
