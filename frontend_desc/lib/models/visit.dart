class Visit {
  Visit({
    required this.id,
    required this.customerId,
    required this.visitDate,
    this.notes,
    this.salesEmployeeId,
    this.salesEmployeeName,
    this.recordedByName,
  });

  final String id;
  final String customerId;
  final DateTime visitDate;
  final String? notes;
  final String? salesEmployeeId;
  final String? salesEmployeeName;
  final String? recordedByName;

  factory Visit.fromJson(Map<String, dynamic> json) => Visit(
        id: json['id'] as String,
        customerId: json['customer_id'] as String,
        visitDate: DateTime.parse(json['visit_date'] as String),
        notes: json['notes'] as String?,
        salesEmployeeId: json['sales_employee_id'] as String?,
        salesEmployeeName: json['sales_employee_name'] as String?,
        recordedByName: json['recorded_by_name'] as String?,
      );
}
