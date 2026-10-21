import '../core/api_client.dart';
import '../models/visit.dart';

class VisitService {
  VisitService(this._api);

  final ApiClient _api;

  Future<List<Visit>> byCustomer(String customerId) async {
    final data = await _api.get('/api/visits/customer/$customerId') as List<dynamic>;
    return data.map((e) => Visit.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Visit> create({
    required String customerId,
    DateTime? visitDate,
    String? notes,
    String? salesEmployeeId,
  }) async {
    final data = await _api.post('/api/visits', body: {
      'customer_id': customerId,
      'visit_date': visitDate?.toUtc().toIso8601String(),
      'notes': notes,
      'sales_employee_id': salesEmployeeId,
    }) as Map<String, dynamic>;
    return Visit.fromJson(data);
  }

  Future<Visit> update({
    required String visitId,
    String? notes,
  }) async {
    final data = await _api.patch('/api/visits/$visitId', body: {
      'notes': notes,
    }) as Map<String, dynamic>;
    return Visit.fromJson(data);
  }
}
