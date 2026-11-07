import '../core/api_client.dart';
import '../core/pagination.dart';
import '../models/visit.dart';

class VisitService {
  VisitService(this._api);

  final ApiClient _api;

  Future<List<Visit>> byCustomer(String customerId) async {
    final data = await _api.get('/api/visits/customer/$customerId') as List<dynamic>;
    return data.map((e) => Visit.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<PagedResult<Visit>> listPaged({
    String? search,
    DateTime? fromDate,
    DateTime? toDate,
    String? callCenterId,
    String? salesEmployeeId,
    String sortDir = 'desc',
    int page = 1,
    int pageSize = 30,
  }) async {
    final query = <String, String>{
      'page': '$page',
      'page_size': '$pageSize',
      'sort_dir': sortDir,
    };
    if (search != null && search.isNotEmpty) query['search'] = search;
    if (fromDate != null) query['from_date'] = fromDate.toIso8601String();
    if (toDate != null) query['to_date'] = toDate.toIso8601String();
    if (callCenterId != null && callCenterId.isNotEmpty) {
      query['call_center_id'] = callCenterId;
    }
    if (salesEmployeeId != null && salesEmployeeId.isNotEmpty) {
      query['sales_employee_id'] = salesEmployeeId;
    }
    final data = await _api.get('/api/visits', query: query) as Map<String, dynamic>;
    final rawItems = (data['items'] as List<dynamic>? ?? const <dynamic>[])
        .cast<Map<String, dynamic>>();
    final items = rawItems.map(Visit.fromJson).toList();
    final total = (data['total'] as num?)?.toInt();
    final resolvedPageSize = (data['page_size'] as num?)?.toInt() ?? pageSize;
    final hasMore = (total != null)
        ? (page * resolvedPageSize) < total
        : items.length >= resolvedPageSize;
    return PagedResult<Visit>(
      items: items,
      page: (data['page'] as num?)?.toInt() ?? page,
      limit: resolvedPageSize,
      hasMore: hasMore,
      total: total,
    );
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
