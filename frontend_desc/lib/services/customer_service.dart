import '../core/api_client.dart';
import '../models/customer.dart';
import '../utils/enums.dart';

class CustomerService {
  CustomerService(this._api);

  final ApiClient _api;

  Future<List<Customer>> list({String? search}) async {
    final query = <String, String>{};
    if (search != null && search.isNotEmpty) query['search'] = search;
    final data = await _api.get('/api/customers', query: query) as Map<String, dynamic>;
    return (data['items'] as List<dynamic>)
        .map((e) => Customer.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Customer> get(String id) async {
    final data = await _api.get('/api/customers/$id') as Map<String, dynamic>;
    return Customer.fromJson(data);
  }

  Future<Customer> create({
    required String name,
    required String phone,
    String? email,
    CustomerGender? gender,
    String? profession,
    String? address,
    HowKnewCenter? howKnew,
    String? referralBuyerName,
    String? salesEmployeeId,
    String? notes,
    CustomerStatus? status,
  }) async {
    final body = <String, dynamic>{
      'name': name,
      'phone': phone,
      if (email != null && email.isNotEmpty) 'email': email,
      if (gender != null) 'gender': gender.api,
      if (profession != null) 'profession': profession,
      if (address != null) 'address': address,
      if (howKnew != null) 'how_knew': howKnew.api,
      if (referralBuyerName != null) 'referral_buyer_name': referralBuyerName,
      if (salesEmployeeId != null) 'sales_employee_id': salesEmployeeId,
      if (notes != null) 'notes': notes,
      if (status != null) 'status': status.api,
    };
    final data = await _api.post('/api/customers', body: body) as Map<String, dynamic>;
    return Customer.fromJson(data);
  }

  Future<Customer> update(
    String id, {
    String? name,
    String? profession,
    String? address,
    String? phone,
    String? email,
    CustomerGender? gender,
    HowKnewCenter? howKnew,
    String? referralBuyerName,
    String? salesEmployeeId,
    String? notes,
    CustomerStatus? status,
  }) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (profession != null) body['profession'] = profession;
    if (address != null) body['address'] = address;
    if (phone != null) body['phone'] = phone;
    if (email != null) body['email'] = email;
    if (gender != null) body['gender'] = gender.api;
    if (howKnew != null) body['how_knew'] = howKnew.api;
    if (referralBuyerName != null) body['referral_buyer_name'] = referralBuyerName;
    if (salesEmployeeId != null) body['sales_employee_id'] = salesEmployeeId;
    if (notes != null) body['notes'] = notes;
    if (status != null) body['status'] = status.api;

    final data = await _api.patch('/api/customers/$id', body: body) as Map<String, dynamic>;
    return Customer.fromJson(data);
  }

  Future<CustomerDocument> uploadDocument(
    String customerId,
    String path,
    String filename, {
    String? notes,
  }) async {
    final fields = <String, String>{};
    if (notes != null && notes.trim().isNotEmpty) {
      fields['notes'] = notes.trim();
    }
    final data = await _api.multipart(
      '/api/customers/$customerId/documents',
      field: 'file',
      filePath: path,
      filename: filename,
      fields: fields.isEmpty ? null : fields,
    ) as Map<String, dynamic>;
    return CustomerDocument.fromJson(data);
  }
}
