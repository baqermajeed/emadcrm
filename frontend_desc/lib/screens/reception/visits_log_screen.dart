import 'dart:io' show Platform, Process;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../controllers/auth_controller.dart';
import '../../controllers/booking_controller.dart';
import '../../controllers/customer_controller.dart';
import '../../core/api_client.dart';
import '../../core/reception_tokens.dart';
import '../../models/booking.dart';
import '../../models/user.dart';
import '../../services/user_service.dart';
import '../../utils/enums.dart';
import '../../utils/formatters.dart';
import '../../widgets/reception/reception_assets.dart';
import '../../widgets/reception/reception_search_bar.dart';
import '../../widgets/staff_avatar.dart';

/// سجل الزيارات — matched to Arabic Visit Log dashboard mock.
class VisitsLogScreen extends StatefulWidget {
  const VisitsLogScreen({
    super.key,
    this.onOpenCustomer,
  });

  final ValueChanged<String>? onOpenCustomer;

  @override
  State<VisitsLogScreen> createState() => _VisitsLogScreenState();
}

class _VisitsLogScreenState extends State<VisitsLogScreen> {
  final _search = TextEditingController();

  List<AppUser> _sales = [];
  List<AppUser> _callCenter = [];
  String? _salesId; // null = all
  String? _callCenterId; // null = all
  DateTime? _fromDate;
  DateTime? _toDate;
  String _appliedSearch = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  Future<void> _bootstrap() async {
    final api = context.read<ApiClient>();
    final bookings = context.read<BookingController>();
    final customers = context.read<CustomerController>();
    if (bookings.items.isEmpty) await bookings.load();
    if (customers.items.isEmpty) await customers.load();
    try {
      final users = UserService(api);
      _sales = await users.list(role: UserRole.sales);
      _callCenter = await users.list(role: UserRole.callCenter);
    } catch (_) {}
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool _isTodayVisit(Booking b) {
    final now = DateTime.now();
    final d = b.visitDate.toLocal();
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }

  /// Pending and visit date is still today or in the future.
  bool _isUpcomingPending(Booking b) {
    if (b.status != BookingStatus.pending) return false;
    final now = DateTime.now();
    final d = b.visitDate.toLocal();
    final today = DateTime(now.year, now.month, now.day);
    final visitDay = DateTime(d.year, d.month, d.day);
    return !visitDay.isBefore(today);
  }

  /// Cancelled, no-show, or pending whose date has passed.
  bool _isMissedOrCancelled(Booking b) {
    if (b.status == BookingStatus.cancelled || b.status == BookingStatus.noShow) {
      return true;
    }
    if (b.status != BookingStatus.pending) return false;
    return !_isUpcomingPending(b);
  }

  String? _salesIdForBooking(Booking b, CustomerController customers) {
    final cid = b.customerId;
    if (cid == null) return null;
    for (final c in customers.items) {
      if (c.id == cid) return c.salesEmployeeId;
    }
    return null;
  }

  /// زيارة = حجز تم تأكيد حضوره فقط (ليس الحجوزات المعلقة).
  List<Booking> _confirmedVisits(List<Booking> bookings) =>
      bookings.where((b) => b.status == BookingStatus.approved).toList();

  List<Booking> _filtered(
    List<Booking> visits,
    CustomerController customers,
  ) {
    var list = [...visits];
    if (_appliedSearch.isNotEmpty) {
      final q = _appliedSearch.toLowerCase();
      list = list
          .where(
            (b) =>
                b.name.toLowerCase().contains(q) || b.phone.contains(q),
          )
          .toList();
    }
    if (_callCenterId != null) {
      list = list.where((b) => b.callCenterId == _callCenterId).toList();
    }
    if (_salesId != null) {
      list = list.where((b) => _salesIdForBooking(b, customers) == _salesId).toList();
    }
    if (_fromDate != null) {
      final from = DateTime(_fromDate!.year, _fromDate!.month, _fromDate!.day);
      list = list.where((b) {
        final d = b.visitDate.toLocal();
        return !DateTime(d.year, d.month, d.day).isBefore(from);
      }).toList();
    }
    if (_toDate != null) {
      final to = DateTime(_toDate!.year, _toDate!.month, _toDate!.day, 23, 59, 59);
      list = list.where((b) => !b.visitDate.toLocal().isAfter(to)).toList();
    }
    list.sort((a, b) => b.visitDate.compareTo(a.visitDate));
    return list;
  }

  Future<void> _pickDate({required bool from}) async {
    final initial = from ? (_fromDate ?? DateTime.now()) : (_toDate ?? DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked == null) return;
    setState(() {
      if (from) {
        _fromDate = picked;
      } else {
        _toDate = picked;
      }
    });
  }

  void _resetFilters() {
    setState(() {
      _salesId = null;
      _callCenterId = null;
      _fromDate = null;
      _toDate = null;
      _search.clear();
      _appliedSearch = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final bookings = context.watch<BookingController>();
    final customers = context.watch<CustomerController>();
    final allBookings = bookings.items;
    final visits = _confirmedVisits(allBookings);
    final filtered = _filtered(visits, customers);

    final total = visits.length;
    final todayCount = visits.where(_isTodayVisit).length;
    final attended = visits.length;
    final awaitingConfirm = allBookings.where(_isUpcomingPending).length;
    final missed = allBookings.where(_isMissedOrCancelled).length;

    return ColoredBox(
      color: const Color(0xFFF4F7FE),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _VisitsHeader(
            userName: displayUserName(auth.user),
            avatarUrl: auth.user?.avatarUrl,
            search: _search,
            suggestions: ReceptionSearchBar.uniqueOf([
              for (final b in visits) ...[b.name, b.phone],
            ]),
            onSearch: () => setState(() => _appliedSearch = _search.text.trim()),
            onQueryChanged: (q) => setState(() {
              _appliedSearch = q.trim();
            }),
            onLogout: () => context.read<AuthController>().logout(),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _StatsRow(
                    total: total,
                    today: todayCount,
                    attended: attended,
                    awaitingConfirm: awaitingConfirm,
                    missed: missed,
                    loading: bookings.loading && allBookings.isEmpty,
                  ),
                  const SizedBox(height: 8),
                  _FiltersBar(
                    sales: _sales,
                    callCenter: _callCenter,
                    salesId: _salesId,
                    callCenterId: _callCenterId,
                    fromDate: _fromDate,
                    toDate: _toDate,
                    resultCount: filtered.length,
                    onSales: (v) => setState(() => _salesId = v),
                    onCallCenter: (v) => setState(() => _callCenterId = v),
                    onPickFrom: () => _pickDate(from: true),
                    onPickTo: () => _pickDate(from: false),
                    onReset: _resetFilters,
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: _VisitsTable(
                      rows: filtered,
                      loading: bookings.loading && allBookings.isEmpty,
                      onOpen: (b) {
                        final id = b.customerId;
                        if (id != null) widget.onOpenCustomer?.call(id);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────── Header ─────────────────────────

class _VisitsHeader extends StatelessWidget {
  const _VisitsHeader({
    required this.userName,
    this.avatarUrl,
    required this.search,
    required this.suggestions,
    required this.onSearch,
    required this.onQueryChanged,
    required this.onLogout,
  });

  final String userName;
  final String? avatarUrl;
  final TextEditingController search;
  final List<String> suggestions;
  final VoidCallback onSearch;
  final ValueChanged<String> onQueryChanged;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: ui.TextDirection.ltr,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(30, 20, 24, 8),
        child: Row(
          children: [
            _card(
              height: 58,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == 'logout') onLogout();
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'logout', child: Text('تسجيل الخروج')),
                ],
                child: Row(
                  children: [
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          userName,
                          style: const TextStyle(
                            color: ReceptionTokens.navy,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          'موظف استقبال',
                          style: TextStyle(
                            color: ReceptionTokens.navy.withValues(alpha: 0.7),
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 6),
                    RAssets.svg('dc_chevron', w: 12, h: 12),
                    const SizedBox(width: 8),
                    StaffAvatar(avatarUrl: avatarUrl, radius: 22),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ReceptionSearchBar(
                controller: search,
                suggestions: suggestions,
                hint: 'ابحث باسم الزبون أو رقم الهاتف...',
                onQueryChanged: onQueryChanged,
                onSearch: onSearch,
              ),
            ),
            const SizedBox(width: 18),
            Row(
              children: [
                Text(
                  'الاستقبال',
                  style: TextStyle(
                    color: ReceptionTokens.navy.withValues(alpha: 0.8),
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                Text(
                  ' / ',
                  style: TextStyle(
                    color: ReceptionTokens.navy.withValues(alpha: 0.8),
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                Text(
                  'سجل الزيارات',
                  style: TextStyle(
                    color: ReceptionTokens.navy.withValues(alpha: 0.8),
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(width: 8),
                RAssets.svg('dc_breadcrumb', w: 16, h: 16, color: ReceptionTokens.navy),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _card({required double height, required Widget child, EdgeInsets? padding}) {
    return Container(
      height: height,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: ReceptionTokens.softShadow,
      ),
      child: child,
    );
  }
}

// ───────────────────────── Stats ─────────────────────────

class _StatsRow extends StatelessWidget {
  const _StatsRow({
    required this.total,
    required this.today,
    required this.attended,
    required this.awaitingConfirm,
    required this.missed,
    required this.loading,
  });

  final int total;
  final int today;
  final int attended;
  final int awaitingConfirm;
  final int missed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Row(
        children: [
          Expanded(
            child: _StatCard(
              label: 'إجمالي الزيارات',
              value: loading ? '—' : '$total',
              iconAsset: RAssets.statVisits,
              accent: const Color(0xFF1E6FD9),
              iconBg: const Color(0xFFDBEAFE),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _StatCard(
              label: 'زيارات اليوم',
              value: loading ? '—' : '$today',
              iconAsset: RAssets.calendarStat,
              accent: const Color(0xFF0891B2),
              iconBg: const Color(0xFFCFFAFE),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _StatCard(
              label: 'الحضور المؤكد',
              value: loading ? '—' : '$attended',
              iconAsset: RAssets.statStatus,
              accent: const Color(0xFF059669),
              iconBg: const Color(0xFFD1FAE5),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _StatCard(
              label: 'حجوزات بانتظار التأكيد',
              value: loading ? '—' : '$awaitingConfirm',
              iconAsset: RAssets.statLastVisit,
              accent: const Color(0xFFEA580C),
              iconBg: const Color(0xFFFFEDD5),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _StatCard(
              label: 'ملغاة / تجاوز الموعد',
              value: loading ? '—' : '$missed',
              iconAsset: RAssets.statDeals,
              accent: const Color(0xFFDC2626),
              iconBg: const Color(0xFFFEE2E2),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.iconAsset,
    required this.accent,
    required this.iconBg,
  });

  final String label;
  final String value;
  final String iconAsset;
  final Color accent;
  final Color iconBg;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.22), width: 0.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF069BAF).withValues(alpha: 0.23),
            blurRadius: 10,
            offset: Offset.zero,
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.cairo(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: accent.withValues(alpha: 0.85),
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: GoogleFonts.cairo(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: accent,
                    height: 1,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: RAssets.profileIcon(iconAsset, size: 24),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────── Filters ─────────────────────────

class _FiltersBar extends StatelessWidget {
  const _FiltersBar({
    required this.sales,
    required this.callCenter,
    required this.salesId,
    required this.callCenterId,
    required this.fromDate,
    required this.toDate,
    required this.resultCount,
    required this.onSales,
    required this.onCallCenter,
    required this.onPickFrom,
    required this.onPickTo,
    required this.onReset,
  });

  final List<AppUser> sales;
  final List<AppUser> callCenter;
  final String? salesId;
  final String? callCenterId;
  final DateTime? fromDate;
  final DateTime? toDate;
  final int resultCount;
  final ValueChanged<String?> onSales;
  final ValueChanged<String?> onCallCenter;
  final VoidCallback onPickFrom;
  final VoidCallback onPickTo;
  final VoidCallback onReset;

  static const _navy = Color(0xFF002E45);
  static const _fieldBg = Color(0xFFF0F6FA);
  static const _border = Color(0xFFD5E4EE);

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF069BAF).withValues(alpha: 0.18),
              blurRadius: 10,
              offset: Offset.zero,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.filter_alt_rounded, color: ReceptionTokens.confirmBlue, size: 18),
                const SizedBox(width: 6),
                Text(
                  'تصفية الزيارات',
                  style: GoogleFonts.cairo(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: _navy,
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: onReset,
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: Text(
                    'إعادة تعيين',
                    style: GoogleFonts.cairo(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: ReceptionTokens.confirmBlue,
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  flex: 2,
                  child: _filterField(
                    label: 'موظف المبيعات',
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String?>(
                        value: salesId,
                        isExpanded: true,
                        hint: Text('كل الموظفين', style: _hint()),
                        icon: const Icon(Icons.keyboard_arrow_down_rounded, color: _navy),
                        items: [
                          DropdownMenuItem(value: null, child: Text('كل الموظفين', style: _item())),
                          ...sales.map(
                            (u) => DropdownMenuItem(value: u.id, child: Text(u.fullName, style: _item())),
                          ),
                        ],
                        onChanged: onSales,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: _filterField(
                    label: 'موظف الكول سنتر',
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String?>(
                        value: callCenterId,
                        isExpanded: true,
                        hint: Text('كل الموظفين', style: _hint()),
                        icon: const Icon(Icons.keyboard_arrow_down_rounded, color: _navy),
                        items: [
                          DropdownMenuItem(value: null, child: Text('كل الموظفين', style: _item())),
                          ...callCenter.map(
                            (u) => DropdownMenuItem(value: u.id, child: Text(u.fullName, style: _item())),
                          ),
                        ],
                        onChanged: onCallCenter,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _filterField(
                    label: 'من تاريخ',
                    child: InkWell(
                      onTap: onPickFrom,
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              fromDate == null
                                  ? 'من تاريخ'
                                  : DateFormat('dd/MM/yyyy').format(fromDate!),
                              style: fromDate == null ? _hint() : _item(),
                            ),
                          ),
                          const Icon(Icons.calendar_today_outlined, size: 16, color: _navy),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _filterField(
                    label: 'إلى تاريخ',
                    child: InkWell(
                      onTap: onPickTo,
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              toDate == null
                                  ? 'إلى تاريخ'
                                  : DateFormat('dd/MM/yyyy').format(toDate!),
                              style: toDate == null ? _hint() : _item(),
                            ),
                          ),
                          const Icon(Icons.calendar_today_outlined, size: 16, color: _navy),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  height: 38,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F4FF),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'نتيجة التصفية',
                        style: GoogleFonts.cairo(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: ReceptionTokens.confirmBlue,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                        decoration: BoxDecoration(
                          color: ReceptionTokens.confirmBlue,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '$resultCount',
                          style: GoogleFonts.cairo(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'زيارة',
                        style: GoogleFonts.cairo(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: ReceptionTokens.confirmBlue,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterField({
    required String label,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.w800, color: _navy),
        ),
        const SizedBox(height: 2),
        Container(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: _fieldBg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _border),
          ),
          alignment: Alignment.center,
          child: child,
        ),
      ],
    );
  }

  TextStyle _hint() => GoogleFonts.cairo(fontWeight: FontWeight.w600, fontSize: 13, color: const Color(0xFF7A93A5));
  TextStyle _item() => GoogleFonts.cairo(fontWeight: FontWeight.w700, fontSize: 13, color: _navy);
}

// ───────────────────────── Table ─────────────────────────

class _VisitsTable extends StatelessWidget {
  const _VisitsTable({
    required this.rows,
    required this.loading,
    required this.onOpen,
  });

  final List<Booking> rows;
  final bool loading;
  final ValueChanged<Booking> onOpen;

  static const _tableMinWidth = 1380.0;
  static const _colGap = 14.0;
  static const _villaH = 48.0;

  Future<void> _openWhatsApp(BuildContext context, String phone) async {
    final digits = phone.replaceAll(RegExp(r'[^\d+]'), '');
    var normalized = digits.replaceAll('+', '');
    if (normalized.startsWith('0')) {
      normalized = '964${normalized.substring(1)}';
    }
    final url = 'https://wa.me/$normalized';
    final uri = Uri.parse(url);

    var opened = false;
    try {
      if (await canLaunchUrl(uri)) {
        opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } on PlatformException {
      opened = false;
    } catch (_) {
      opened = false;
    }

    // Windows: plugin channel can fail after hot reload — open via shell.
    if (!opened && !kIsWeb && Platform.isWindows) {
      try {
        await Process.start('cmd', ['/c', 'start', '', url], runInShell: true);
        opened = true;
      } catch (_) {
        opened = false;
      }
    }

    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر فتح واتساب')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF069BAF).withValues(alpha: 0.2),
              blurRadius: 10,
              offset: Offset.zero,
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _toolbar(),
            Expanded(
              child: loading
                  ? const Center(child: CircularProgressIndicator())
                  : rows.isEmpty
                      ? Center(
                          child: Text(
                            'لا توجد زيارات',
                            style: GoogleFonts.cairo(
                              fontWeight: FontWeight.w700,
                              color: ReceptionTokens.muted,
                            ),
                          ),
                        )
                      : LayoutBuilder(
                          builder: (context, constraints) {
                            final w = constraints.maxWidth < _tableMinWidth
                                ? _tableMinWidth
                                : constraints.maxWidth;
                            return Scrollbar(
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: SizedBox(
                                  width: w,
                                  height: constraints.maxHeight,
                                  child: Column(
                                    children: [
                                      _headerRow(),
                                      Expanded(
                                        child: ListView.builder(
                                          itemCount: rows.length,
                                          itemBuilder: (context, i) {
                                            return _dataRow(
                                              context,
                                              rows[i],
                                              i + 1,
                                              i.isOdd,
                                            );
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _toolbar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
      child: Row(
        children: [
          _toolBtn(
            icon: Icons.file_download_outlined,
            label: 'تصدير',
            onTap: () {},
          ),
          const SizedBox(width: 8),
          Container(
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F6FA),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFD5E4EE)),
            ),
            child: Row(
              children: [
                const Icon(Icons.swap_vert_rounded, size: 18, color: Color(0xFF1E6FD9)),
                const SizedBox(width: 6),
                Text(
                  'الأحدث أولاً',
                  style: GoogleFonts.cairo(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    color: _tableText,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          Text(
            'سجل الزيارات',
            style: GoogleFonts.cairo(
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: _tableText,
            ),
          ),
          const SizedBox(width: 8),
          RAssets.profileIcon(RAssets.statLastVisit, size: 24),
        ],
      ),
    );
  }

  Widget _toolBtn({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: const Color(0xFFEFF6FF),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Icon(icon, size: 18, color: const Color(0xFF1E6FD9)),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.cairo(
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                  color: const Color(0xFF1E6FD9),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static const _tableText = Color(0xFF123B70);

  Widget _headerRow() {
    final style = GoogleFonts.cairo(
      fontWeight: FontWeight.w800,
      fontSize: 11,
      color: _tableText,
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      color: const Color(0xFFE7F5F7),
      child: _cols([
        _fixed(40, Text('#', style: style, textAlign: TextAlign.center)),
        _fixed(114, const SizedBox.shrink()),
        _fixed(78, Text('الوقت', style: style, textAlign: TextAlign.center)),
        _fixed(100, Text('تاريخ الزيارة', style: style, textAlign: TextAlign.center)),
        _flex(2, Text('اسم الزبون', style: style)),
        _fixed(110, Text('رقم الهاتف', style: style, textAlign: TextAlign.center)),
        _flex(1, Text('المحافظة', style: style)),
        _fixed(104, Text('نوع الزيارة', style: style, textAlign: TextAlign.center)),
        _fixed(112, Text('الحالة', style: style, textAlign: TextAlign.center)),
        _flex(2, Text('موظف الكول سنتر', style: style)),
        _fixed(72, Text('ملاحظات', style: style)),
        _fixed(136, Text('الإجراءات', style: style, textAlign: TextAlign.center)),
      ]),
    );
  }

  Widget _dataRow(BuildContext context, Booking b, int index, bool alt) {
    final style = GoogleFonts.cairo(
      fontWeight: FontWeight.w700,
      fontSize: 12,
      color: _tableText,
    );
    final muted = GoogleFonts.cairo(
      fontWeight: FontWeight.w600,
      fontSize: 11,
      color: _tableText.withValues(alpha: 0.72),
    );
    final date = DateFormat('dd/MM/yyyy').format(b.visitDate.toLocal());
    final time = DateFormat('hh:mm a', 'ar').format(b.visitDate.toLocal());
    final firstVisit = b.isFirstVisit;

    return Material(
      color: alt ? const Color(0xFFF7FBFC) : Colors.white,
      child: InkWell(
        onTap: () => onOpen(b),
        child: Container(
          height: _villaH,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0xFFEEF2F6))),
          ),
          child: _cols([
            _fixed(
              40,
              Text(
                index.toString().padLeft(2, '0'),
                textAlign: TextAlign.center,
                style: style,
              ),
            ),
            _fixed(
              114,
              Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.asset(
                    RAssets.visitsLogVilla,
                    width: 110,
                    height: _villaH,
                    fit: BoxFit.cover,
                    filterQuality: FilterQuality.high,
                  ),
                ),
              ),
            ),
            _fixed(78, Text(time, textAlign: TextAlign.center, style: muted)),
            _fixed(100, Text(date, textAlign: TextAlign.center, style: style)),
            _flex(
              2,
              Row(
                children: [
                  const StaffAvatar(
                    radius: 15,
                    backgroundColor: Color(0xFFE8F0FE),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      b.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: style,
                    ),
                  ),
                ],
              ),
            ),
            _fixed(
              110,
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    RAssets.callPhoneIcon,
                    width: 14,
                    height: 14,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      b.phone,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: style,
                    ),
                  ),
                ],
              ),
            ),
            _flex(
              1,
              Text(
                b.governorate,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: style,
              ),
            ),
            _fixed(104, Center(child: _typeChip(firstVisit))),
            _fixed(112, Center(child: _statusChip(b))),
            _flex(
              2,
              Row(
                children: [
                  StaffAvatar(
                    avatarUrl: b.callCenterAvatarUrl,
                    radius: 15,
                    backgroundColor: const Color(0xFFE8F0FE),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      b.callCenterName ?? '—',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: style,
                    ),
                  ),
                ],
              ),
            ),
            _fixed(
              72,
              Text(
                (b.notes ?? '').trim().isEmpty ? '—' : b.notes!.trim(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: muted,
              ),
            ),
            _fixed(
              136,
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _GlassActionBtn(
                    onTap: () => onOpen(b),
                    bg: const Color(0xFFEFF6FF),
                    fg: const Color(0xFF1E6FD9),
                    child: const Icon(Icons.edit_outlined, size: 15, color: Color(0xFF1E6FD9)),
                  ),
                  const SizedBox(width: 4),
                  _GlassActionBtn(
                    onTap: () => _openWhatsApp(context, b.phone),
                    bg: const Color(0xFFE8F8EF),
                    fg: const Color(0xFF059669),
                    child: RAssets.source('whatsapp', size: 16),
                  ),
                  const SizedBox(width: 4),
                  _GlassActionBtn(
                    onTap: () => onOpen(b),
                    bg: const Color(0xFFEFF6FF),
                    fg: const Color(0xFF1E6FD9),
                    child: const Icon(Icons.visibility_outlined, size: 15, color: Color(0xFF1E6FD9)),
                  ),
                ],
              ),
            ),
          ]),
        ),
      ),
    );
  }

  /// Equal gap between every column.
  Widget _cols(List<Widget> children) {
    return Row(
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(width: _colGap),
          children[i],
        ],
      ],
    );
  }

  Widget _fixed(double width, Widget child) => SizedBox(
        width: width,
        child: child,
      );

  Widget _flex(int flex, Widget child) => Expanded(flex: flex, child: child);

  Widget _typeChip(bool firstVisit) {
    final bg = firstVisit ? const Color(0xFFDBEAFE) : const Color(0xFFF3E8FF);
    final fg = firstVisit ? const Color(0xFF1D4ED8) : const Color(0xFF7C3AED);
    final label = firstVisit ? 'زيارة أولى' : 'زيارة متابعة';
    return _GlassShimmerChip(
      bg: bg,
      fg: fg,
      label: label,
    );
  }

  Widget _statusChip(Booking b) {
    late Color bg;
    late Color fg;
    late IconData icon;
    late String label;

    if (b.status == BookingStatus.approved) {
      bg = const Color(0xFFD1FAE5);
      fg = const Color(0xFF047857);
      icon = Icons.check_circle_rounded;
      label = 'مكتملة';
    } else if (b.status == BookingStatus.cancelled) {
      bg = const Color(0xFFFEE2E2);
      fg = const Color(0xFFB91C1C);
      icon = Icons.cancel_rounded;
      label = 'ملغاة';
    } else if (b.status == BookingStatus.noShow) {
      bg = const Color(0xFFFEE2E2);
      fg = const Color(0xFFB91C1C);
      icon = Icons.close_rounded;
      label = 'لم يحضر';
    } else {
      final now = DateTime.now();
      final d = b.visitDate.toLocal();
      final today = DateTime(now.year, now.month, now.day);
      final visitDay = DateTime(d.year, d.month, d.day);
      if (visitDay.isBefore(today)) {
        bg = const Color(0xFFFEE2E2);
        fg = const Color(0xFFB91C1C);
        icon = Icons.close_rounded;
        label = 'لم يحضر';
      } else if (_sameDay(visitDay, today)) {
        bg = const Color(0xFFFFEDD5);
        fg = const Color(0xFFC2410C);
        icon = Icons.access_time_filled_rounded;
        label = 'قيد الزيارة';
      } else {
        bg = const Color(0xFFFFEDD5);
        fg = const Color(0xFFC2410C);
        icon = Icons.access_time_filled_rounded;
        label = 'قيد الزيارة';
      }
    }

    return _GlassShimmerChip(
      bg: bg,
      fg: fg,
      label: label,
      icon: icon,
    );
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _GlassActionBtn extends StatefulWidget {
  const _GlassActionBtn({
    required this.onTap,
    required this.bg,
    required this.fg,
    required this.child,
  });

  final VoidCallback onTap;
  final Color bg;
  final Color fg;
  final Widget child;

  @override
  State<_GlassActionBtn> createState() => _GlassActionBtnState();
}

class _GlassActionBtnState extends State<_GlassActionBtn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const size = 30.0;
    const radius = 10.0;
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        final shine = (_ctrl.value * 1.35) - 0.2;
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(radius),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(radius),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: CustomPaint(
                  foregroundPainter: _ChipShimmerPainter(progress: shine),
                  child: Container(
                    width: size,
                    height: size,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(radius),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          widget.bg.withValues(alpha: 0.55),
                          Colors.white.withValues(alpha: 0.50),
                          widget.bg.withValues(alpha: 0.72),
                        ],
                      ),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.75),
                        width: 1.1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: widget.fg.withValues(alpha: 0.14),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: child,
                  ),
                ),
              ),
            ),
          ),
        );
      },
      child: widget.child,
    );
  }
}

class _GlassShimmerChip extends StatefulWidget {
  const _GlassShimmerChip({
    required this.bg,
    required this.fg,
    required this.label,
    this.icon,
  });

  final Color bg;
  final Color fg;
  final String label;
  final IconData? icon;

  @override
  State<_GlassShimmerChip> createState() => _GlassShimmerChipState();
}

class _GlassShimmerChipState extends State<_GlassShimmerChip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const radius = 10.0;
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        final shine = (_ctrl.value * 1.35) - 0.2;
        return ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: CustomPaint(
              foregroundPainter: _ChipShimmerPainter(progress: shine),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(radius),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      widget.bg.withValues(alpha: 0.55),
                      Colors.white.withValues(alpha: 0.45),
                      widget.bg.withValues(alpha: 0.70),
                    ],
                  ),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.75),
                    width: 1.1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: widget.fg.withValues(alpha: 0.12),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: child,
              ),
            ),
          ),
        );
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.icon != null) ...[
            Icon(widget.icon, size: 13, color: widget.fg),
            const SizedBox(width: 4),
          ],
          Text(
            widget.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: GoogleFonts.cairo(
              fontWeight: FontWeight.w800,
              fontSize: 10,
              color: widget.fg,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChipShimmerPainter extends CustomPainter {
  _ChipShimmerPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress < 0 || progress > 1.15) return;
    final bandW = size.width * 0.42;
    final x = (size.width + bandW) * progress - bandW;
    final rect = Rect.fromLTWH(x, -4, bandW, size.height + 8);
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          Colors.white.withValues(alpha: 0),
          Colors.white.withValues(alpha: 0.65),
          Colors.white.withValues(alpha: 0.2),
          Colors.white.withValues(alpha: 0),
        ],
        stops: const [0.0, 0.45, 0.55, 1.0],
      ).createShader(rect)
      ..blendMode = BlendMode.softLight;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.translate(x + bandW / 2, size.height / 2);
    canvas.rotate(-0.35);
    canvas.translate(-(x + bandW / 2), -size.height / 2);
    canvas.drawRect(rect, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ChipShimmerPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
