import '../utils/enums.dart';

class Deal {
  Deal({
    required this.id,
    required this.customerId,
    required this.name,
    required this.phone,
    required this.totalPrice,
    required this.paymentType,
    required this.downPayment,
    required this.salesEmployeeId,
    required this.saleDate,
    this.houseType = HouseType.house,
    this.status = DealStatus.completed,
    this.houseArea,
    this.residentialBlock,
    this.houseNumber,
    this.profession,
    this.email,
    this.notes,
    this.salesEmployeeName,
    this.salesEmployeeAvatarUrl,
  });

  final String id;
  final String customerId;
  final String name;
  final String phone;
  final HouseType houseType;
  final double? houseArea;
  final String? residentialBlock;
  final String? houseNumber;
  final double totalPrice;
  final PaymentType paymentType;
  final double downPayment;
  final DealStatus status;
  final String salesEmployeeId;
  final DateTime saleDate;
  final String? profession;
  final String? email;
  final String? notes;
  final String? salesEmployeeName;
  final String? salesEmployeeAvatarUrl;

  factory Deal.fromJson(Map<String, dynamic> json) => Deal(
        id: json['id'] as String,
        customerId: json['customer_id'] as String,
        name: json['name'] as String,
        phone: json['phone'] as String,
        houseType: HouseTypeX.fromApi(json['house_type'] as String?),
        houseArea: (json['house_area'] as num?)?.toDouble(),
        residentialBlock: json['residential_block'] as String?,
        houseNumber: json['house_number'] as String?,
        totalPrice: (json['total_price'] as num).toDouble(),
        paymentType: PaymentTypeX.fromApi(json['payment_type'] as String),
        downPayment: (json['down_payment'] as num).toDouble(),
        status: DealStatusX.fromApi(json['status'] as String?),
        salesEmployeeId: json['sales_employee_id'] as String,
        saleDate: DateTime.parse(json['sale_date'] as String),
        profession: json['profession'] as String?,
        email: json['email'] as String?,
        notes: json['notes'] as String?,
        salesEmployeeName: json['sales_employee_name'] as String?,
        salesEmployeeAvatarUrl: json['sales_employee_avatar_url'] as String?,
      );
}
