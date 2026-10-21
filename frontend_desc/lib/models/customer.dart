import '../utils/enums.dart';

class CustomerDocument {
  CustomerDocument({
    required this.id,
    required this.filename,
    required this.originalName,
    required this.contentType,
    required this.url,
    required this.uploadedAt,
    this.notes,
  });

  final String id;
  final String filename;
  final String originalName;
  final String contentType;
  final String url;
  final DateTime uploadedAt;
  final String? notes;

  factory CustomerDocument.fromJson(Map<String, dynamic> json) => CustomerDocument(
        id: json['id'] as String,
        filename: json['filename'] as String,
        originalName: json['original_name'] as String,
        contentType: json['content_type'] as String,
        url: json['url'] as String,
        uploadedAt: DateTime.parse(json['uploaded_at'] as String),
        notes: json['notes'] as String?,
      );

  bool get isImage => contentType.startsWith('image/');
}

class Customer {
  Customer({
    required this.id,
    required this.name,
    required this.phone,
    this.email,
    this.gender = CustomerGender.male,
    this.profession,
    this.address,
    this.callCenterId,
    this.callCenterName,
    this.callCenterAvatarUrl,
    this.howKnew,
    this.referralBuyerName,
    this.salesEmployeeId,
    this.salesEmployeeName,
    this.salesEmployeeAvatarUrl,
    this.notes,
    this.status,
    this.bookingId,
    this.documents = const [],
    this.createdAt,
  });

  final String id;
  final String name;
  final String phone;
  final String? email;
  final CustomerGender gender;
  final String? profession;
  final String? address;
  final String? callCenterId;
  final String? callCenterName;
  final String? callCenterAvatarUrl;
  final HowKnewCenter? howKnew;
  final String? referralBuyerName;
  final String? salesEmployeeId;
  final String? salesEmployeeName;
  final String? salesEmployeeAvatarUrl;
  final String? notes;
  final CustomerStatus? status;
  final String? bookingId;
  final List<CustomerDocument> documents;
  final DateTime? createdAt;

  factory Customer.fromJson(Map<String, dynamic> json) => Customer(
        id: json['id'] as String,
        name: json['name'] as String,
        phone: json['phone'] as String,
        email: json['email'] as String?,
        gender: CustomerGenderX.fromApi(json['gender'] as String?),
        profession: json['profession'] as String?,
        address: json['address'] as String?,
        callCenterId: json['call_center_id'] as String?,
        callCenterName: json['call_center_name'] as String?,
        callCenterAvatarUrl: json['call_center_avatar_url'] as String?,
        howKnew: HowKnewX.fromApi(json['how_knew'] as String?),
        referralBuyerName: json['referral_buyer_name'] as String?,
        salesEmployeeId: json['sales_employee_id'] as String?,
        salesEmployeeName: json['sales_employee_name'] as String?,
        salesEmployeeAvatarUrl: json['sales_employee_avatar_url'] as String?,
        notes: json['notes'] as String?,
        status: json['status'] == null
            ? null
            : CustomerStatusX.fromApi(json['status'] as String?),
        bookingId: json['booking_id'] as String?,
        documents: (json['documents'] as List<dynamic>? ?? [])
            .map((e) => CustomerDocument.fromJson(e as Map<String, dynamic>))
            .toList(),
        createdAt: json['created_at'] != null
            ? DateTime.parse(json['created_at'] as String)
            : null,
      );
}
