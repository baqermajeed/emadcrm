import '../core/api_client.dart';
import '../models/booking.dart';
import '../utils/enums.dart';

class BookingService {
  BookingService(this._api);

  final ApiClient _api;

  Future<List<Booking>> list({BookingStatus? status}) async {
    final query = <String, String>{};
    if (status != null) query['status'] = status.api;
    final data = await _api.get('/api/bookings', query: query) as Map<String, dynamic>;
    return (data['items'] as List<dynamic>)
        .map((e) => Booking.fromJson(e as Map<String, dynamic>))
        .toList();
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
    String? profession,
    String? address,
    HowKnewCenter? howKnew,
    String? referralBuyerName,
    String? notes,
  }) async {
    final data = await _api.post('/api/bookings/$bookingId/approve', body: {
      'sales_employee_id': salesEmployeeId,
      'profession': profession,
      'address': address,
      'how_knew': howKnew?.api,
      'referral_buyer_name': referralBuyerName,
      'notes': notes,
    }) as Map<String, dynamic>;
    return Booking.fromJson(data);
  }
}
