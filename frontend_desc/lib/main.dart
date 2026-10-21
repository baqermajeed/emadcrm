import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'controllers/auth_controller.dart';
import 'controllers/booking_controller.dart';
import 'controllers/customer_controller.dart';
import 'controllers/report_controller.dart';
import 'core/api_client.dart';
import 'core/theme.dart';
import 'screens/home_gate.dart';
import 'services/auth_service.dart';
import 'services/booking_service.dart';
import 'services/customer_service.dart';
import 'services/deal_service.dart';
import 'services/report_service.dart';
import 'services/reservation_service.dart';
import 'services/visit_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(EmadCrmApp(api: ApiClient()));
}

class EmadCrmApp extends StatelessWidget {
  const EmadCrmApp({super.key, required this.api});

  final ApiClient api;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<ApiClient>.value(value: api),
        ChangeNotifierProvider(
          create: (_) => AuthController(AuthService(api))..bootstrap(),
        ),
        ChangeNotifierProvider(
          create: (_) => BookingController(BookingService(api)),
        ),
        ChangeNotifierProvider(
          create: (_) => CustomerController(
            customerService: CustomerService(api),
            visitService: VisitService(api),
            dealService: DealService(api),
            reservationService: ReservationService(api),
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => ReportController(ReportService(api)),
        ),
      ],
      child: MaterialApp(
        title: 'Emad CRM',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        builder: (context, child) => Directionality(
          textDirection: TextDirection.rtl,
          child: child ?? const SizedBox.shrink(),
        ),
        home: const HomeGate(),
      ),
    );
  }
}
