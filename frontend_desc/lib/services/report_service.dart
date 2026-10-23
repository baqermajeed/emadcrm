import '../core/api_client.dart';
import '../models/report.dart';

class ReportService {
  ReportService(this._api);

  final ApiClient _api;

  Future<ManagerDashboard> dashboard() async {
    final data = await _api.get('/api/reports/dashboard') as Map<String, dynamic>;
    return ManagerDashboard.fromJson(data);
  }

  Future<LiveSummary> liveSummary() async {
    final data = await _api.get('/api/reports/live-summary') as Map<String, dynamic>;
    return LiveSummary.fromJson(data);
  }
}
