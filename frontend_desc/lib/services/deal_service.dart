import '../core/api_client.dart';
import '../models/deal.dart';
import '../utils/enums.dart';

class DealService {
  DealService(this._api);

  final ApiClient _api;

  Future<List<Deal>> list({String? customerId}) async {
    final query = <String, String>{};
    if (customerId != null) query['customer_id'] = customerId;
    final data = await _api.get('/api/deals', query: query) as Map<String, dynamic>;
    return (data['items'] as List<dynamic>)
        .map((e) => Deal.fromJson(e as Map<String, dynamic>))
        .toList();
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
