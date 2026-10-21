import '../utils/enums.dart';

class HouseReservation {
  HouseReservation({
    required this.id,
    required this.customerId,
    required this.name,
    required this.houseArea,
    required this.residentialBlock,
    required this.houseNumber,
    required this.totalPrice,
    required this.paymentType,
    required this.downPayment,
    required this.salesEmployeeId,
    required this.reservationDate,
    required this.completionDeadline,
    required this.status,
    this.notes,
    this.salesEmployeeName,
  });

  final String id;
  final String customerId;
  final String name;
  final double houseArea;
  final String residentialBlock;
  final String houseNumber;
  final double totalPrice;
  final PaymentType paymentType;
  final double downPayment;
  final String salesEmployeeId;
  final DateTime reservationDate;
  final DateTime completionDeadline;
  final ReservationStatus status;
  final String? notes;
  final String? salesEmployeeName;

  factory HouseReservation.fromJson(Map<String, dynamic> json) => HouseReservation(
        id: json['id'] as String,
        customerId: json['customer_id'] as String,
        name: json['name'] as String,
        houseArea: (json['house_area'] as num).toDouble(),
        residentialBlock: json['residential_block'] as String,
        houseNumber: json['house_number'] as String,
        totalPrice: (json['total_price'] as num).toDouble(),
        paymentType: PaymentTypeX.fromApi(json['payment_type'] as String),
        downPayment: (json['down_payment'] as num).toDouble(),
        salesEmployeeId: json['sales_employee_id'] as String,
        reservationDate: DateTime.parse(json['reservation_date'] as String),
        completionDeadline: DateTime.parse(json['completion_deadline'] as String),
        status: ReservationStatusX.fromApi(json['status'] as String),
        notes: json['notes'] as String?,
        salesEmployeeName: json['sales_employee_name'] as String?,
      );
}
