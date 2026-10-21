import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/auth_controller.dart';
import '../utils/enums.dart';
import 'auth/login_screen.dart';
import 'call_center/call_center_home.dart';
import 'manager/manager_home.dart';
import 'reception/reception_home.dart';
import 'sales/sales_home.dart';

class HomeGate extends StatelessWidget {
  const HomeGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();

    if (auth.bootstrapping) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!auth.isLoggedIn) {
      return const LoginScreen();
    }

    return switch (auth.user!.role) {
      UserRole.callCenter => const CallCenterHome(),
      UserRole.reception => const ReceptionHome(),
      UserRole.sales => const SalesHome(),
      UserRole.manager => const ManagerHome(),
    };
  }
}
