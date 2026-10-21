class StaffReport {
  StaffReport({
    required this.employeeId,
    required this.employeeName,
    required this.role,
    this.bookingsCount = 0,
    this.customersCount = 0,
    this.visitsCount = 0,
    this.dealsCount = 0,
    this.dealsTotalAmount = 0,
    this.reservationsCount = 0,
    this.reservationsAmount = 0,
  });

  final String employeeId;
  final String employeeName;
  final String role;
  final int bookingsCount;
  final int customersCount;
  final int visitsCount;
  final int dealsCount;
  final double dealsTotalAmount;
  final int reservationsCount;
  final double reservationsAmount;

  factory StaffReport.fromJson(Map<String, dynamic> json) => StaffReport(
        employeeId: json['employee_id'] as String,
        employeeName: json['employee_name'] as String,
        role: json['role'] as String,
        bookingsCount: json['bookings_count'] as int? ?? 0,
        customersCount: json['customers_count'] as int? ?? 0,
        visitsCount: json['visits_count'] as int? ?? 0,
        dealsCount: json['deals_count'] as int? ?? 0,
        dealsTotalAmount: (json['deals_total_amount'] as num?)?.toDouble() ?? 0,
        reservationsCount: json['reservations_count'] as int? ?? 0,
        reservationsAmount: (json['reservations_amount'] as num?)?.toDouble() ?? 0,
      );
}

class ManagerDashboard {
  ManagerDashboard({
    required this.totalBookings,
    required this.pendingBookings,
    required this.approvedBookings,
    required this.totalCustomers,
    required this.totalVisits,
    required this.totalDeals,
    required this.totalDealsAmount,
    required this.totalReservations,
    required this.totalReservationsAmount,
    required this.activeReservations,
    required this.staffReports,
  });

  final int totalBookings;
  final int pendingBookings;
  final int approvedBookings;
  final int totalCustomers;
  final int totalVisits;
  final int totalDeals;
  final double totalDealsAmount;
  final int totalReservations;
  final double totalReservationsAmount;
  final int activeReservations;
  final List<StaffReport> staffReports;

  factory ManagerDashboard.fromJson(Map<String, dynamic> json) => ManagerDashboard(
        totalBookings: json['total_bookings'] as int,
        pendingBookings: json['pending_bookings'] as int,
        approvedBookings: json['approved_bookings'] as int,
        totalCustomers: json['total_customers'] as int,
        totalVisits: json['total_visits'] as int,
        totalDeals: json['total_deals'] as int,
        totalDealsAmount: (json['total_deals_amount'] as num).toDouble(),
        totalReservations: json['total_reservations'] as int,
        totalReservationsAmount: (json['total_reservations_amount'] as num).toDouble(),
        activeReservations: json['active_reservations'] as int,
        staffReports: (json['staff_reports'] as List<dynamic>)
            .map((e) => StaffReport.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
