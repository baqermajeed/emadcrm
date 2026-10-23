import '../core/api_client.dart';
import '../core/pagination.dart';
import '../models/booking.dart';
import '../utils/enums.dart';

class BookingService {
  BookingService(this._api);

  final ApiClient _api;

  Future<List<Booking>> list({BookingStatus? status, String? search}) async {
    final query = <String, String>{};
    if (status != null) query['status'] = status.api;
    if (search != null && search.isNotEmpty) query['search'] = search;
    final data = await _api.get('/api/bookings', query: query) as Map<String, dynamic>;
    return (data['items'] as List<dynamic>)
        .map((e) => Booking.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<PagedResult<Booking>> listPaged({
    BookingStatus? status,
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
    if (status != null) query['status'] = status.api;
    if (search != null && search.isNotEmpty) query['search'] = search;
    if (fromDate != null) query['from_date'] = fromDate.toUtc().toIso8601String();
    if (toDate != null) query['to_date'] = toDate.toUtc().toIso8601String();
    if (callCenterId != null && callCenterId.isNotEmpty) {
      query['call_center_id'] = callCenterId;
    }
    if (salesEmployeeId != null && salesEmployeeId.isNotEmpty) {
      query['sales_employee_id'] = salesEmployeeId;
    }
    final data = await _api.get('/api/bookings', query: query) as Map<String, dynamic>;
    final rawItems = (data['items'] as List<dynamic>? ?? const <dynamic>[])
        .cast<Map<String, dynamic>>();
    final items = rawItems.map(Booking.fromJson).toList();
    final total = (data['total'] as num?)?.toInt();
    final resolvedPageSize = (data['page_size'] as num?)?.toInt() ?? pageSize;
    final hasMore = (total != null)
        ? (page * resolvedPageSize) < total
        : items.length >= resolvedPageSize;
    return PagedResult<Booking>(
      items: items,
      page: (data['page'] as num?)?.toInt() ?? page,
      limit: resolvedPageSize,
      hasMore: hasMore,
      total: total,
    );
  }

  Future<Booking> create({
    required String name,
    required String phone,
    required String governorate,
    required BookingSource source,
    required DateTime visitDate,
    String? notes,
  }) async {
    final data = await _api.post('/api/bookings', body: {
      'name': name,
      'phone': phone,
      'governorate': governorate,
      'source': source.api,
      'visit_date': visitDate.toUtc().toIso8601String(),
      'notes': notes,
    }) as Map<String, dynamic>;
    return Booking.fromJson(data);
  }

  Future<Booking> approve({
    required String bookingId,
    required String salesEmployeeId,
    VisitType? visitType,
    String? existingCustomerId,
    String? profession,
    String? address,
    HowKnewCenter? howKnew,
    String? referralBuyerName,
    String? notes,
  }) async {
    final data = await _api.post('/api/bookings/$bookingId/approve', body: {
      'sales_employee_id': salesEmployeeId,
      'visit_type': visitType?.api,
      'existing_customer_id': existingCustomerId,
      'profession': profession,
      'address': address,
      'how_knew': howKnew?.api,
      'referral_buyer_name': referralBuyerName,
      'notes': notes,
    }) as Map<String, dynamic>;
    return Booking.fromJson(data);
  }
}
