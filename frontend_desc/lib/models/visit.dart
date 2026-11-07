import '../utils/enums.dart';

class Visit {
  Visit({
    required this.id,
    required this.customerId,
    required this.visitDate,
    this.notes,
    this.visitType,
    this.salesEmployeeId,
    this.salesEmployeeName,
    this.recordedByName,
    this.customerName,
    this.customerPhone,
    this.customerAddress,
    this.callCenterId,
    this.callCenterName,
    this.callCenterAvatarUrl,
  });

  final String id;
  final String customerId;
  final DateTime visitDate;
  final String? notes;
  final VisitType? visitType;
  final String? salesEmployeeId;
  final String? salesEmployeeName;
  final String? recordedByName;
  final String? customerName;
  final String? customerPhone;
  final String? customerAddress;
  final String? callCenterId;
  final String? callCenterName;
  final String? callCenterAvatarUrl;

  bool get isFirstVisit => visitType == VisitType.first;

  String get displayName => (customerName ?? '').trim().isEmpty ? '—' : customerName!.trim();

  String get displayPhone => (customerPhone ?? '').trim().isEmpty ? '—' : customerPhone!.trim();

  String get displayAddress =>
      (customerAddress ?? '').trim().isEmpty ? '—' : customerAddress!.trim();

  factory Visit.fromJson(Map<String, dynamic> json) => Visit(
        id: json['id'] as String,
        customerId: json['customer_id'] as String,
        visitDate: DateTime.parse(json['visit_date'] as String),
        notes: json['notes'] as String?,
        visitType: VisitTypeX.fromApi(json['visit_type'] as String?),
        salesEmployeeId: json['sales_employee_id'] as String?,
        salesEmployeeName: json['sales_employee_name'] as String?,
        recordedByName: json['recorded_by_name'] as String?,
        customerName: json['customer_name'] as String?,
        customerPhone: json['customer_phone'] as String?,
        customerAddress: json['customer_address'] as String?,
        callCenterId: json['call_center_id'] as String?,
        callCenterName: json['call_center_name'] as String?,
        callCenterAvatarUrl: json['call_center_avatar_url'] as String?,
      );
}
