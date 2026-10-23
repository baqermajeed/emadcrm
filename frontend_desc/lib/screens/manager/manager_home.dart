import 'package:flutter/material.dart';
import '../../core/app_fonts.dart';
import 'package:provider/provider.dart';

import '../../controllers/report_controller.dart';
import '../../core/reception_tokens.dart';
import '../../utils/enums.dart';
import '../../utils/formatters.dart';
import '../../widgets/app_scaffold.dart';
import 'users_management_screen.dart';

class ManagerHome extends StatefulWidget {
  const ManagerHome({super.key});

  @override
  State<ManagerHome> createState() => _ManagerHomeState();
}

class _ManagerHomeState extends State<ManagerHome> {
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ReportController>().load();
    });
  }

  PreferredSizeWidget get _navBar => PreferredSize(
        preferredSize: const Size.fromHeight(56),
        child: ColoredBox(
          color: ReceptionTokens.navy,
          child: Row(
            children: [
              _NavChip(
                selected: _tab == 0,
                icon: Icons.insights_rounded,
                label: 'التقارير',
                onTap: () => setState(() => _tab = 0),
              ),
              _NavChip(
                selected: _tab == 1,
                icon: Icons.manage_accounts_rounded,
                label: 'المستخدمون',
                onTap: () => setState(() => _tab = 1),
              ),
            ],
          ),
        ),
      );

  String _roleLabel(String role) => UserRoleX.fromApi(role).label;

  @override
  Widget build(BuildContext context) {
    if (_tab == 1) {
      return UsersManagementScreen(bottom: _navBar);
    }

    final ctrl = context.watch<ReportController>();
    final d = ctrl.dashboard;

    return AppScaffold(
      title: 'لوحة المدير',
      bottom: _navBar,
      body: RefreshIndicator(
        onRefresh: () => context.read<ReportController>().load(),
        child: ctrl.loading && d == null
            ? const Center(child: CircularProgressIndicator())
            : d == null
                ? ListView(
                    children: [
                      const SizedBox(height: 120),
                      EmptyState(message: ctrl.error ?? 'لا توجد بيانات'),
                    ],
                  )
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Text(
                        'التقارير الكلية',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: 12),
                      GridView.count(
                        crossAxisCount:
                            MediaQuery.of(context).size.width > 700 ? 4 : 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                        childAspectRatio: 1.45,
                        children: [
                          StatCard(label: 'الحجوزات', value: '${d.totalBookings}'),
                          StatCard(
                            label: 'بانتظار الحضور',
                            value: '${d.pendingBookings}',
                          ),
                          StatCard(label: 'الزبائن', value: '${d.totalCustomers}'),
                          StatCard(label: 'الزيارات', value: '${d.totalVisits}'),
                          StatCard(label: 'الصفقات', value: '${d.totalDeals}'),
                          StatCard(
                            label: 'مبلغ الصفقات',
                            value: formatMoney(d.totalDealsAmount),
                            color: const Color(0xFFC4A35A),
                          ),
                          StatCard(
                            label: 'الحجوزات المنزلية',
                            value: '${d.totalReservations}',
                          ),
                          StatCard(
                            label: 'مقدمات الحجز',
                            value: formatMoney(d.totalReservationsAmount),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'تقارير الموظفين',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: 12),
                      ...d.staffReports.map(
                        (s) => Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          child: ExpansionTile(
                            title: Text(s.employeeName),
                            subtitle: Text(_roleLabel(s.role)),
                            childrenPadding:
                                const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            children: [
                              _row('الحجوزات', '${s.bookingsCount}'),
                              _row('الزبائن', '${s.customersCount}'),
                              _row('الزيارات', '${s.visitsCount}'),
                              _row('الصفقات', '${s.dealsCount}'),
                              _row(
                                'مبلغ الصفقات',
                                formatMoney(s.dealsTotalAmount),
                              ),
                              _row('حجوزات الدور', '${s.reservationsCount}'),
                              _row(
                                'مقدمات الحجز',
                                formatMoney(s.reservationsAmount),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _NavChip extends StatelessWidget {
  const _NavChip({
    required this.selected,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 56,
          alignment: Alignment.center,
          color: selected
              ? Colors.white.withValues(alpha: 0.12)
              : Colors.transparent,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: AppFonts.style(
                  color: Colors.white,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
