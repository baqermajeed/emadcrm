import '../utils/enums.dart';

class Booking {
  Booking({
    required this.id,
    required this.name,
    required this.phone,
    required this.governorate,
    required this.source,
    required this.visitDate,
    required this.status,
    required this.callCenterId,
    this.notes,
    this.callCenterName,
    this.callCenterAvatarUrl,
    this.customerId,
    this.visitType,
    this.createdAt,
  });

  final String id;
  final String name;
  final String phone;
  final String governorate;
  final BookingSource source;
  final DateTime visitDate;
  final BookingStatus status;
  final String callCenterId;
  final String? notes;
  final String? callCenterName;
  final String? callCenterAvatarUrl;
  final String? customerId;
  final VisitType? visitType;
  final DateTime? createdAt;

  /// Pending becomes no-show 24 hours after the appointment.
  BookingStatus get effectiveStatus {
    if (status != BookingStatus.pending) return status;
    final due = visitDate.toUtc().add(const Duration(hours: 24));
    if (DateTime.now().toUtc().isAfter(due)) return BookingStatus.noShow;
    return status;
  }

  /// أول زيارة إن وُجد النوع، وإلا للحجوزات القديمة: بلا ملف زبون بعد.
  bool get isFirstVisit {
    if (visitType != null) return visitType == VisitType.first;
    return customerId == null;
  }

  factory Booking.fromJson(Map<String, dynamic> json) => Booking(
        id: json['id'] as String,
        name: json['name'] as String,
        phone: json['phone'] as String,
        governorate: json['governorate'] as String,
        source: BookingSourceX.fromApi(json['source'] as String),
        visitDate: DateTime.parse(json['visit_date'] as String),
        status: BookingStatusX.fromApi(json['status'] as String),
        callCenterId: json['call_center_id'] as String,
        notes: json['notes'] as String?,
        callCenterName: json['call_center_name'] as String?,
        callCenterAvatarUrl: json['call_center_avatar_url'] as String?,
        customerId: json['customer_id'] as String?,
        visitType: VisitTypeX.fromApi(json['visit_type'] as String?),
        createdAt: json['created_at'] != null
            ? DateTime.parse(json['created_at'] as String)
            : null,
      );
}
