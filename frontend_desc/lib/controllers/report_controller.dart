import 'package:flutter/foundation.dart';

import '../core/api_client.dart';
import '../models/report.dart';
import '../services/report_service.dart';

class ReportController extends ChangeNotifier {
  ReportController(this._service);

  final ReportService _service;

  ManagerDashboard? dashboard;
  bool loading = false;
  String? error;

  Future<void> load() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      dashboard = await _service.dashboard();
    } on ApiException catch (e) {
      error = e.message;
    } catch (_) {
      error = 'فشل تحميل التقارير';
    }
    loading = false;
    notifyListeners();
  }
}
