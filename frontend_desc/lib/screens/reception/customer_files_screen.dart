import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../controllers/booking_controller.dart';
import '../../controllers/customer_controller.dart';
import '../../core/api_client.dart';
import '../../core/reception_tokens.dart';
import '../../models/customer.dart';
import '../../services/deal_service.dart';
import '../../services/reservation_service.dart';
import '../../utils/enums.dart';
import '../../utils/formatters.dart';
import '../../widgets/reception/reception_assets.dart';
import '../../widgets/reception/reception_search_bar.dart';
import '../../widgets/staff_avatar.dart';
import '../shared/edit_customer_screen.dart';

/// Customer files grid — matched to Figma «ملفات الزبائن» mock.
class CustomerFilesScreen extends StatefulWidget {
  const CustomerFilesScreen({
    super.key,
    required this.onOpenCustomer,
  });

  final ValueChanged<String> onOpenCustomer;

  @override
  State<CustomerFilesScreen> createState() => _CustomerFilesScreenState();
}

class _CustomerFilesScreenState extends State<CustomerFilesScreen> {
  final _headerSearch = TextEditingController();
  final _filterSearch = TextEditingController();

  CustomerStatus? _statusFilter;
  DateTime? _fromDate;
  DateTime? _toDate;
  String _complex = 'all';
  String _houseType = 'all';
  String _sort = 'newest';
  bool _grid = true;

  // Applied filters (after «تطبيق الفلتر»)
  String _appliedQuery = '';
  CustomerStatus? _appliedStatus;
  DateTime? _appliedFrom;
  DateTime? _appliedTo;

  int _dealsCount = 0;
  int _reservationsCount = 0;
  bool _statsLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  Future<void> _bootstrap() async {
    final customers = context.read<CustomerController>();
    final api = context.read<ApiClient>();
    if (customers.items.isEmpty) await customers.load();
    try {
      final deals = await DealService(api).list();
      final reservations = await ReservationService(api).list();
      if (!mounted) return;
      setState(() {
        _dealsCount = deals.length;
        _reservationsCount = reservations
            .where((r) => r.status == ReservationStatus.active)
            .length;
        _statsLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _statsLoading = false);
    }
  }

  @override
  void dispose() {
    _headerSearch.dispose();
    _filterSearch.dispose();
    super.dispose();
  }

  void _applyFilters() {
    setState(() {
      _appliedQuery = _filterSearch.text.trim().isNotEmpty
          ? _filterSearch.text.trim()
          : _headerSearch.text.trim();
      _appliedStatus = _statusFilter;
      _appliedFrom = _fromDate;
      _appliedTo = _toDate;
    });
  }

  void _resetFilters() {
    setState(() {
      _filterSearch.clear();
      _headerSearch.clear();
      _statusFilter = null;
      _fromDate = null;
      _toDate = null;
      _complex = 'all';
      _houseType = 'all';
      _appliedQuery = '';
      _appliedStatus = null;
      _appliedFrom = null;
      _appliedTo = null;
    });
  }

  bool _sameDay(DateTime a, DateTime b) {
    final x = a.toLocal();
    final y = b.toLocal();
    return x.year == y.year && x.month == y.month && x.day == y.day;
  }

  List<Customer> _filtered(List<Customer> all) {
    var list = [...all];
    final q = _appliedQuery.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list
          .where(
            (c) =>
                c.name.toLowerCase().contains(q) || c.phone.contains(q),
          )
          .toList();
    }
    if (_appliedStatus != null) {
      list = list.where((c) => c.status == _appliedStatus).toList();
    }
    if (_appliedFrom != null) {
      list = list.where((c) {
        final d = c.createdAt;
        if (d == null) return false;
        final local = d.toLocal();
        final from = DateTime(
          _appliedFrom!.year,
          _appliedFrom!.month,
          _appliedFrom!.day,
        );
        return !local.isBefore(from);
      }).toList();
    }
    if (_appliedTo != null) {
      list = list.where((c) {
        final d = c.createdAt;
        if (d == null) return false;
        final local = d.toLocal();
        final to = DateTime(
          _appliedTo!.year,
          _appliedTo!.month,
          _appliedTo!.day,
          23,
          59,
          59,
        );
        return !local.isAfter(to);
      }).toList();
    }
    list.sort((a, b) {
      final ad = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bd = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return _sort == 'newest' ? bd.compareTo(ad) : ad.compareTo(bd);
    });
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

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final customers = context.watch<CustomerController>();
    final bookings = context.watch<BookingController>();
    final today = DateTime.now();
    final attendedToday = bookings.items
        .where(
          (b) =>
              b.status == BookingStatus.approved &&
              _sameDay(b.visitDate, today),
        )
        .length;

    final list = _filtered(customers.items);
    final userName = displayUserName(auth.user);

    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: ColoredBox(
        color: const Color(0xFFF4F7FE),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _FilesHeader(
              userName: userName,
              avatarUrl: auth.user?.avatarUrl,
              search: _headerSearch,
              suggestions: ReceptionSearchBar.uniqueOf([
                for (final c in customers.items) ...[c.name, c.phone],
              ]),
              onSearch: () {
                setState(() => _appliedQuery = _headerSearch.text.trim());
              },
              onQueryChanged: (q) {
                setState(() => _appliedQuery = q.trim());
              },
              onLogout: () => context.read<AuthController>().logout(),
              onAdd: () async {
                final ok = await EditCustomerScreen.showAdd(context);
                if (ok == true && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تم إضافة الزبون بنجاح')),
                  );
                }
              },
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _StatsRow(
                      totalCustomers: customers.items.length,
                      attendedToday: attendedToday,
                      reservations: _reservationsCount,
                      deals: _dealsCount,
                      loading: _statsLoading && customers.loading,
                    ),
                    const SizedBox(height: 14),
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _FilterPanel(
                            search: _filterSearch,
                            status: _statusFilter,
                            complex: _complex,
                            houseType: _houseType,
                            fromDate: _fromDate,
                            toDate: _toDate,
                            onStatus: (v) => setState(() => _statusFilter = v),
                            onComplex: (v) => setState(() => _complex = v),
                            onHouseType: (v) => setState(() => _houseType = v),
                            onPickFrom: () => _pickDate(from: true),
                            onPickTo: () => _pickDate(from: false),
                            onApply: _applyFilters,
                            onReset: _resetFilters,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _Toolbar(
                                  count: list.length,
                                  grid: _grid,
                                  sort: _sort,
                                  onGrid: (v) => setState(() => _grid = v),
                                  onSort: (v) => setState(() => _sort = v),
                                ),
                                const SizedBox(height: 12),
                                Expanded(
                                  child: customers.loading && customers.items.isEmpty
                                      ? const Center(child: CircularProgressIndicator())
                                      : list.isEmpty
                                          ? Center(
                                              child: Text(
                                                'لا يوجد زبائن',
                                                style: GoogleFonts.cairo(
                                                  fontWeight: FontWeight.w700,
                                                  color: ReceptionTokens.muted,
                                                ),
                                              ),
                                            )
                                          : _grid
                                              ? _CustomerGrid(
                                                  customers: list,
                                                  onOpen: widget.onOpenCustomer,
                                                )
                                              : _CustomerList(
                                                  customers: list,
                                                  onOpen: widget.onOpenCustomer,
                                                ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
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
}

// ───────────────────────── Header (same as home, bell → add customer) ─────────────────────────

class _FilesHeader extends StatelessWidget {
  const _FilesHeader({
    required this.userName,
    this.avatarUrl,
    required this.search,
    required this.suggestions,
    required this.onSearch,
    required this.onQueryChanged,
    required this.onLogout,
    required this.onAdd,
  });

  final String userName;
  final String? avatarUrl;
  final TextEditingController search;
  final List<String> suggestions;
  final VoidCallback onSearch;
  final ValueChanged<String> onQueryChanged;
  final VoidCallback onLogout;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    // Same LTR layout as reception home header
    return Directionality(
      textDirection: ui.TextDirection.ltr,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(30, 20, 24, 8),
        child: Row(
          children: [
            // Add customer (replaces notifications bell)
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onAdd,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  height: 58,
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  decoration: BoxDecoration(
                    color: ReceptionTokens.confirmBlue,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: ReceptionTokens.softShadow,
                  ),
                  child: Directionality(
                    textDirection: ui.TextDirection.rtl,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.add_rounded, color: Colors.white, size: 22),
                        const SizedBox(width: 6),
                        Text(
                          'إضافة زبون جديد',
                          style: GoogleFonts.cairo(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            // Profile
            _headerCard(
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
                hint: 'ابحث عن زبون بالاسم أو رقم الهاتف...',
                onQueryChanged: onQueryChanged,
                onSearch: onSearch,
              ),
            ),
            const SizedBox(width: 18),
            // Breadcrumb
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
                  'ملفات الزبائن',
                  style: TextStyle(
                    color: ReceptionTokens.navy.withValues(alpha: 0.8),
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(width: 8),
                RAssets.svg(
                  'dc_breadcrumb',
                  w: 16,
                  h: 16,
                  color: ReceptionTokens.navy,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _headerCard({
    required double height,
    required Widget child,
    EdgeInsets? padding,
  }) {
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
    required this.totalCustomers,
    required this.attendedToday,
    required this.reservations,
    required this.deals,
    required this.loading,
  });

  final int totalCustomers;
  final int attendedToday;
  final int reservations;
  final int deals;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            label: 'إجمالي الزبائن',
            value: loading ? '—' : '$totalCustomers',
            iconAsset: RAssets.statVisits,
            iconBg: const Color(0xFFE8F0FE),
            accent: const Color(0xFF002E45),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            label: 'حضروا اليوم',
            value: loading ? '—' : '$attendedToday',
            iconAsset: RAssets.statStatus,
            iconBg: const Color(0xFFF3E8FF),
            accent: const Color(0xFF6D28D9),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            label: 'حجوزات حالياً',
            value: loading ? '—' : '$reservations',
            iconAsset: RAssets.statLastVisit,
            iconBg: const Color(0xFFDBEAFE),
            accent: const Color(0xFF1E6FD9),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            label: 'صفقات البيع',
            value: loading ? '—' : '$deals',
            iconAsset: RAssets.statDeals,
            iconBg: const Color(0xFFD1FAE5),
            accent: const Color(0xFF059669),
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.iconAsset,
    required this.iconBg,
    required this.accent,
  });

  final String label;
  final String value;
  final String iconAsset;
  final Color iconBg;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 92,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF069BAF).withValues(alpha: 0.23),
            blurRadius: 10,
            spreadRadius: 0,
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
                  style: GoogleFonts.cairo(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: accent.withValues(alpha: 0.75),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: GoogleFonts.cairo(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: accent,
                    height: 1,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: RAssets.profileIcon(iconAsset, size: 36),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────── Toolbar ─────────────────────────

class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.count,
    required this.grid,
    required this.sort,
    required this.onGrid,
    required this.onSort,
  });

  final int count;
  final bool grid;
  final String sort;
  final ValueChanged<bool> onGrid;
  final ValueChanged<String> onSort;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.folder_shared_rounded, color: Color(0xFF1E6FD9), size: 26),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ملفات الزبائن',
                style: GoogleFonts.cairo(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF1B254B),
                ),
              ),
              Text(
                'جميع الزبائن المسجلين في النظام',
                style: GoogleFonts.cairo(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF718096),
                ),
              ),
            ],
          ),
        ),
        Text(
          'عدد الزبائن: $count',
          style: GoogleFonts.cairo(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF1B254B),
          ),
        ),
        const SizedBox(width: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: sort,
              icon: const Icon(Icons.sort_rounded, size: 18, color: Color(0xFF1E6FD9)),
              items: [
                DropdownMenuItem(
                  value: 'newest',
                  child: Text(
                    'الأحدث أولاً',
                    style: GoogleFonts.cairo(fontWeight: FontWeight.w700, fontSize: 12),
                  ),
                ),
                DropdownMenuItem(
                  value: 'oldest',
                  child: Text(
                    'الأقدم أولاً',
                    style: GoogleFonts.cairo(fontWeight: FontWeight.w700, fontSize: 12),
                  ),
                ),
              ],
              onChanged: (v) {
                if (v != null) onSort(v);
              },
            ),
          ),
        ),
        const SizedBox(width: 8),
        _ViewToggle(grid: grid, onGrid: onGrid),
      ],
    );
  }
}

class _ViewToggle extends StatelessWidget {
  const _ViewToggle({required this.grid, required this.onGrid});

  final bool grid;
  final ValueChanged<bool> onGrid;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          _toggleBtn(
            icon: Icons.grid_view_rounded,
            active: grid,
            onTap: () => onGrid(true),
          ),
          _toggleBtn(
            icon: Icons.view_list_rounded,
            active: !grid,
            onTap: () => onGrid(false),
          ),
        ],
      ),
    );
  }

  Widget _toggleBtn({
    required IconData icon,
    required bool active,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: active ? const Color(0xFF1E6FD9) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          size: 18,
          color: active ? Colors.white : const Color(0xFF94A3B8),
        ),
      ),
    );
  }
}

// ───────────────────────── Filter panel ─────────────────────────

class _FilterPanel extends StatelessWidget {
  const _FilterPanel({
    required this.search,
    required this.status,
    required this.complex,
    required this.houseType,
    required this.fromDate,
    required this.toDate,
    required this.onStatus,
    required this.onComplex,
    required this.onHouseType,
    required this.onPickFrom,
    required this.onPickTo,
    required this.onApply,
    required this.onReset,
  });

  final TextEditingController search;
  final CustomerStatus? status;
  final String complex;
  final String houseType;
  final DateTime? fromDate;
  final DateTime? toDate;
  final ValueChanged<CustomerStatus?> onStatus;
  final ValueChanged<String> onComplex;
  final ValueChanged<String> onHouseType;
  final VoidCallback onPickFrom;
  final VoidCallback onPickTo;
  final VoidCallback onApply;
  final VoidCallback onReset;

  static const _navy = Color(0xFF002E45);
  static const _blue = Color(0xFF0066D6);
  static const _fieldBg = Color(0xFFF0F6FA);
  static const _fieldBorder = Color(0xFFD5E4EE);
  static const _hint = Color(0xFF7A93A5);
  static const _radius = 12.0;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 272,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF069BAF).withValues(alpha: 0.23),
            blurRadius: 10,
            spreadRadius: 0,
            offset: Offset.zero,
          ),
        ],
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.filter_alt_rounded, color: _navy, size: 22),
                const SizedBox(width: 8),
                Text(
                  'تصفية الزبائن',
                  style: GoogleFonts.cairo(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: _navy,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _label('البحث'),
            const SizedBox(height: 8),
            _field(
              child: TextField(
                controller: search,
                textAlign: TextAlign.right,
                style: GoogleFonts.cairo(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: _navy,
                ),
                decoration: InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  hintText: 'الاسم أو رقم الهاتف...',
                  hintStyle: GoogleFonts.cairo(
                    color: _hint,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                  // Visual left in RTL = end of field
                  suffixIcon: const Icon(Icons.search_rounded, size: 20, color: _navy),
                  suffixIconConstraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                ),
              ),
            ),
            const SizedBox(height: 14),
            _label('حالة الزبون'),
            const SizedBox(height: 8),
            _dropdown<CustomerStatus?>(
              value: status,
              hint: 'كل الحالات',
              items: [
                DropdownMenuItem(
                  value: null,
                  child: Text('كل الحالات', style: _ddStyle()),
                ),
                ...CustomerStatus.values.map(
                  (s) => DropdownMenuItem(value: s, child: Text(s.label, style: _ddStyle())),
                ),
              ],
              onChanged: onStatus,
            ),
            const SizedBox(height: 14),
            _label('المجمع السكني'),
            const SizedBox(height: 8),
            _dropdown<String>(
              value: complex,
              hint: 'كل المجمعات',
              items: [
                DropdownMenuItem(value: 'all', child: Text('كل المجمعات', style: _ddStyle())),
                DropdownMenuItem(value: 'a', child: Text('مجمع A', style: _ddStyle())),
                DropdownMenuItem(value: 'b', child: Text('مجمع B', style: _ddStyle())),
              ],
              onChanged: (v) {
                if (v != null) onComplex(v);
              },
            ),
            const SizedBox(height: 14),
            _label('نوع الدار'),
            const SizedBox(height: 8),
            _dropdown<String>(
              value: houseType,
              hint: 'كل الأنواع',
              items: [
                DropdownMenuItem(value: 'all', child: Text('كل الأنواع', style: _ddStyle())),
                DropdownMenuItem(value: 'villa', child: Text('فيلا', style: _ddStyle())),
                DropdownMenuItem(value: 'house', child: Text('دار', style: _ddStyle())),
              ],
              onChanged: (v) {
                if (v != null) onHouseType(v);
              },
            ),
            const SizedBox(height: 14),
            _label('تاريخ الزيارة'),
            const SizedBox(height: 8),
            _dateField(
              label: 'من تاريخ',
              value: fromDate,
              onTap: onPickFrom,
            ),
            const SizedBox(height: 10),
            _dateField(
              label: 'إلى تاريخ',
              value: toDate,
              onTap: onPickTo,
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 48,
              child: FilledButton(
                onPressed: onApply,
                style: FilledButton.styleFrom(
                  backgroundColor: _blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(_radius),
                  ),
                  elevation: 0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.filter_alt_rounded, size: 18, color: Colors.white),
                    const SizedBox(width: 8),
                    Text(
                      'تطبيق الفلتر',
                      style: GoogleFonts.cairo(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 48,
              child: Material(
                color: _fieldBg,
                borderRadius: BorderRadius.circular(_radius),
                child: InkWell(
                  onTap: onReset,
                  borderRadius: BorderRadius.circular(_radius),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.refresh_rounded, size: 18, color: _navy),
                      const SizedBox(width: 8),
                      Text(
                        'إعادة تعيين',
                        style: GoogleFonts.cairo(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: _navy,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  TextStyle _ddStyle() => GoogleFonts.cairo(
        fontWeight: FontWeight.w700,
        fontSize: 13,
        color: _navy,
      );

  Widget _label(String text) => Text(
        text,
        textAlign: TextAlign.right,
        style: GoogleFonts.cairo(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: _navy,
        ),
      );

  Widget _field({required Widget child}) => Container(
        height: 46,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: _fieldBg,
          borderRadius: BorderRadius.circular(_radius),
          border: Border.all(color: _fieldBorder, width: 1),
        ),
        alignment: Alignment.center,
        child: child,
      );

  Widget _dropdown<T>({
    required T value,
    required String hint,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return _field(
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          hint: Text(hint, style: GoogleFonts.cairo(fontWeight: FontWeight.w600, color: _hint, fontSize: 13)),
          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: _navy, size: 22),
          style: _ddStyle(),
          dropdownColor: Colors.white,
          borderRadius: BorderRadius.circular(12),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _dateField({
    required String label,
    required DateTime? value,
    required VoidCallback onTap,
  }) {
    final empty = value == null;
    final text = empty ? label : DateFormat('dd/MM/yyyy').format(value);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(_radius),
        child: _field(
          // RTL: first child = right → calendar sits on the right like the mock
          child: Row(
            children: [
              const Icon(Icons.calendar_today_outlined, size: 18, color: _navy),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  text,
                  textAlign: TextAlign.right,
                  style: GoogleFonts.cairo(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: empty ? _hint : _navy,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ───────────────────────── Grid / List ─────────────────────────

class _CustomerGrid extends StatelessWidget {
  const _CustomerGrid({required this.customers, required this.onOpen});

  final List<Customer> customers;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 12),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 220,
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        childAspectRatio: 0.88,
      ),
      itemCount: customers.length,
      itemBuilder: (context, i) => _CustomerCard(
        customer: customers[i],
        onOpen: () => onOpen(customers[i].id),
      ),
    );
  }
}

class _CustomerList extends StatelessWidget {
  const _CustomerList({required this.customers, required this.onOpen});

  final List<Customer> customers;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      itemCount: customers.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final c = customers[i];
        return Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          child: ListTile(
            onTap: () => onOpen(c.id),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            leading: CircleAvatar(
              backgroundImage: AssetImage(
                c.gender == CustomerGender.female
                    ? RAssets.avatarFemale
                    : RAssets.avatarMale,
              ),
            ),
            title: Text(c.name, style: GoogleFonts.cairo(fontWeight: FontWeight.w800)),
            subtitle: Text(c.phone, style: GoogleFonts.cairo(fontWeight: FontWeight.w600)),
            trailing: Text(
              _statusMeta(c).label,
              style: GoogleFonts.cairo(
                fontWeight: FontWeight.w800,
                color: _statusMeta(c).color,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CustomerCard extends StatelessWidget {
  const _CustomerCard({required this.customer, required this.onOpen});

  final Customer customer;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final status = _statusMeta(customer);
    final date = customer.createdAt == null
        ? '—'
        : DateFormat('dd/MM/yyyy').format(customer.createdAt!.toLocal());
    final address = _addressLabel(customer);
    final avatar = customer.gender == CustomerGender.female
        ? RAssets.avatarFemale
        : RAssets.avatarMale;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF069BAF).withValues(alpha: 0.23),
            blurRadius: 10,
            spreadRadius: 0,
            offset: Offset.zero,
          ),
        ],
      ),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onOpen,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(
                      child: Image.asset(
                        RAssets.customerCardVilla,
                        fit: BoxFit.cover,
                        filterQuality: FilterQuality.high,
                      ),
                    ),
                    Positioned(
                      top: 10,
                      left: 10,
                      child: _GlassStatusBadge(
                        label: status.label,
                        color: status.color,
                      ),
                    ),
                    Positioned(
                      bottom: -18,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: CircleAvatar(
                          radius: 22,
                          backgroundColor: const Color(0xFFE8F0FE),
                          backgroundImage: AssetImage(avatar),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 22, 10, 10),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      customer.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.cairo(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF1B254B),
                      ),
                    ),
                    const SizedBox(height: 6),
                    _infoRow(RAssets.cardPhone, customer.phone),
                    const SizedBox(height: 3),
                    _infoRow(RAssets.cardAddress, address),
                    const SizedBox(height: 3),
                    _infoRow(RAssets.cardDate, date),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoRow(String iconAsset, String text) {
    return Row(
      children: [
        RAssets.profileIcon(iconAsset, size: 18),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.cairo(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF4A5568),
            ),
          ),
        ),
      ],
    );
  }
}

String _addressLabel(Customer c) {
  final addr = c.address?.trim();
  if (addr != null && addr.isNotEmpty) return addr;
  return 'بدون عنوان';
}

class _GlassStatusBadge extends StatefulWidget {
  const _GlassStatusBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  State<_GlassStatusBadge> createState() => _GlassStatusBadgeState();
}

class _GlassStatusBadgeState extends State<_GlassStatusBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const radius = 8.0;
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        final shine = (_ctrl.value * 1.4) - 0.2;
        return ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: CustomPaint(
              foregroundPainter: _BadgeShimmerPainter(progress: shine),
              child: child,
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: widget.color, width: 0.5),
          boxShadow: [
            BoxShadow(
              color: widget.color.withValues(alpha: 0.18),
              blurRadius: 8,
              offset: Offset.zero,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: widget.color,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: widget.color.withValues(alpha: 0.45),
                    blurRadius: 4,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Text(
              widget.label,
              style: GoogleFonts.cairo(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: widget.color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BadgeShimmerPainter extends CustomPainter {
  _BadgeShimmerPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress < 0 || progress > 1.2) return;
    final bandW = size.width * 0.45;
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
    canvas.rotate(-0.4);
    canvas.translate(-(x + bandW / 2), -size.height / 2);
    canvas.drawRect(rect, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _BadgeShimmerPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

({String label, Color color, Color bg}) _statusMeta(Customer c) {
  final s = c.status;
  if (s == null) {
    return (
      label: 'زار المركز',
      color: const Color(0xFF7C3AED),
      bg: const Color(0xFFF3E8FF),
    );
  }
  return switch (s) {
    CustomerStatus.buyer => (
        label: 'مشتري',
        color: const Color(0xFF059669),
        bg: const Color(0xFFD1FAE5),
      ),
    CustomerStatus.reservation => (
        label: 'حجز',
        color: const Color(0xFF1E6FD9),
        bg: const Color(0xFFDBEAFE),
      ),
    CustomerStatus.potential => (
        label: 'محتمل',
        color: const Color(0xFFEA580C),
        bg: const Color(0xFFFFEDD5),
      ),
    CustomerStatus.interested => (
        label: 'مهتم',
        color: const Color(0xFF0891B2),
        bg: const Color(0xFFCFFAFE),
      ),
    CustomerStatus.hesitant => (
        label: 'متردد',
        color: const Color(0xFFCA8A04),
        bg: const Color(0xFFFEF9C3),
      ),
    CustomerStatus.notInterested => (
        label: 'غير مهتم',
        color: const Color(0xFF64748B),
        bg: const Color(0xFFF1F5F9),
      ),
  };
}
