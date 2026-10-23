import '../core/api_client.dart';
import '../core/pagination.dart';
import '../models/deal.dart';
import '../utils/enums.dart';

class DealService {
  DealService(this._api);

  final ApiClient _api;

  Future<List<Deal>> list({String? customerId, String? search}) async {
    final query = <String, String>{};
    if (customerId != null) query['customer_id'] = customerId;
    if (search != null && search.isNotEmpty) query['search'] = search;
    final data = await _api.get('/api/deals', query: query) as Map<String, dynamic>;
    return (data['items'] as List<dynamic>)
        .map((e) => Deal.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<PagedResult<Deal>> listPaged({
    String? customerId,
    String? search,
    String? salesEmployeeId,
    String? houseType,
    String? residentialBlock,
    DateTime? fromDate,
    DateTime? toDate,
    String sortDir = 'desc',
    int page = 1,
    int pageSize = 30,
  }) async {
    final query = <String, String>{
      'page': '$page',
      'page_size': '$pageSize',
      'sort_dir': sortDir,
    };
    if (customerId != null) query['customer_id'] = customerId;
    if (search != null && search.isNotEmpty) query['search'] = search;
    if (salesEmployeeId != null && salesEmployeeId.isNotEmpty) {
      query['sales_employee_id'] = salesEmployeeId;
    }
    if (houseType != null && houseType.isNotEmpty) query['house_type'] = houseType;
    if (residentialBlock != null && residentialBlock.isNotEmpty) {
      query['residential_block'] = residentialBlock;
    }
    if (fromDate != null) query['from_date'] = fromDate.toUtc().toIso8601String();
    if (toDate != null) query['to_date'] = toDate.toUtc().toIso8601String();
    final data = await _api.get('/api/deals', query: query) as Map<String, dynamic>;
    final rawItems = (data['items'] as List<dynamic>? ?? const <dynamic>[])
        .cast<Map<String, dynamic>>();
    final items = rawItems.map(Deal.fromJson).toList();
    final total = (data['total'] as num?)?.toInt();
    final resolvedPageSize = (data['page_size'] as num?)?.toInt() ?? pageSize;
    final hasMore = (total != null)
        ? (page * resolvedPageSize) < total
        : items.length >= resolvedPageSize;
    return PagedResult<Deal>(
      items: items,
      page: (data['page'] as num?)?.toInt() ?? page,
      limit: resolvedPageSize,
      hasMore: hasMore,
      total: total,
    );
  }

  Future<Deal> create(Map<String, dynamic> body) async {
    final data = await _api.post('/api/deals', body: body) as Map<String, dynamic>;
    return Deal.fromJson(data);
  }

  Future<Deal> update(String id, Map<String, dynamic> body) async {
    final data =
        await _api.patch('/api/deals/$id', body: body) as Map<String, dynamic>;
    return Deal.fromJson(data);
  }

  Map<String, dynamic> buildBody({
    required String customerId,
    required String name,
    required String phone,
    required HouseType houseType,
    required double totalPrice,
    required PaymentType paymentType,
    required double downPayment,
    double? houseArea,
    String? residentialBlock,
    String? houseNumber,
    String? profession,
    String? email,
    String? notes,
    String? salesEmployeeId,
    DateTime? saleDate,
  }) {
    return {
      'customer_id': customerId,
      'name': name,
      'profession': profession,
      'email': email,
      'phone': phone,
      'house_type': houseType.api,
      'house_area': houseArea,
      'residential_block': residentialBlock,
      'house_number': houseNumber,
      'total_price': totalPrice,
      'payment_type': paymentType.api,
      'down_payment': downPayment,
      'notes': notes,
      'sales_employee_id': salesEmployeeId,
      'sale_date': saleDate?.toUtc().toIso8601String(),
    };
  }
}
