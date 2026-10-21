import '../core/api_client.dart';
import '../models/reservation.dart';
import '../utils/enums.dart';

class ReservationService {
  ReservationService(this._api);

  final ApiClient _api;

  Future<List<HouseReservation>> list({String? customerId}) async {
    final query = <String, String>{};
    if (customerId != null) query['customer_id'] = customerId;
    final data = await _api.get('/api/reservations', query: query) as Map<String, dynamic>;
    return (data['items'] as List<dynamic>)
        .map((e) => HouseReservation.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<HouseReservation> create({
    required String customerId,
    required String name,
    required double houseArea,
    required String residentialBlock,
    required String houseNumber,
    required double totalPrice,
    required PaymentType paymentType,
    required double downPayment,
    required DateTime completionDeadline,
    String? notes,
    String? salesEmployeeId,
    DateTime? reservationDate,
  }) async {
    final data = await _api.post('/api/reservations', body: {
      'customer_id': customerId,
      'name': name,
      'house_area': houseArea,
      'residential_block': residentialBlock,
      'house_number': houseNumber,
      'total_price': totalPrice,
      'payment_type': paymentType.api,
      'down_payment': downPayment,
      'notes': notes,
      'sales_employee_id': salesEmployeeId,
      'reservation_date': reservationDate?.toUtc().toIso8601String(),
      'completion_deadline': completionDeadline.toUtc().toIso8601String(),
    }) as Map<String, dynamic>;
    return HouseReservation.fromJson(data);
  }
}
