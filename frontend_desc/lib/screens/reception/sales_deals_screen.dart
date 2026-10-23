import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../controllers/auth_controller.dart';
import '../../controllers/customer_controller.dart';
import '../../core/api_client.dart';
import '../../core/reception_tokens.dart';
import '../../models/customer.dart';
import '../../models/deal.dart';
import '../../models/user.dart';
import '../../services/deal_service.dart';
import '../../services/user_service.dart';
import '../../utils/enums.dart';
import '../../utils/formatters.dart';
import '../../widgets/reception/reception_assets.dart';
import '../../widgets/reception/reception_search_bar.dart';
import '../../widgets/staff_avatar.dart';
import '../shared/create_deal_screen.dart';

/// صفقات البيع — matched to Arabic Sales Deals dashboard mock.
class SalesDealsScreen extends StatefulWidget {
  const SalesDealsScreen({super.key, this.onOpenCustomer});

  final ValueChanged<String>? onOpenCustomer;

  @override
  State<SalesDealsScreen> createState() => _SalesDealsScreenState();
}

class _SalesDealsScreenState extends State<SalesDealsScreen> {
  final _search = TextEditingController();
  final _scroll = ScrollController();

  List<Deal> _deals = [];
  List<AppUser> _sales = [];
  bool _loading = true;

  String _appliedSearch = '';
  String _sort = 'newest';
  String? _salesId;
  String _houseType = 'all';
  String _complex = 'all';
  DateTime? _fromDate;
  DateTime? _toDate;
  bool _grid = true;

  static const _pageSize = 12;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  void _goToPage(int p) {
    setState(() => _page = p);
    if (_scroll.hasClients) {
      _scroll.animateTo(
        0,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _bootstrap() async {
    final api = context.read<ApiClient>();
    final customers = context.read<CustomerController>();
    if (customers.items.isEmpty) await customers.load();
    try {
      final deals = await DealService(api).list();
      final sales = await UserService(api).list(role: UserRole.sales);
      if (!mounted) return;
      setState(() {
        _deals = deals;
        _sales = sales;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _reloadDeals() async {
    final api = context.read<ApiClient>();
    try {
      final deals = await DealService(api).list();
      if (!mounted) return;
      setState(() {
        _deals = deals;
        _page = 0;
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  String _complexLabel(Deal d) {
    final b = d.residentialBlock?.trim();
    if (b != null && b.isNotEmpty) return b;
    return 'لايوجد';
  }

  String _houseLabel(Deal d) {
    final n = d.houseNumber?.trim();
    if (n != null && n.isNotEmpty) return '${d.houseType.label} · $n';
    return d.houseType.label;
  }

  List<String> get _complexOptions {
    final set = <String>{};
    for (final d in _deals) {
      final b = d.residentialBlock?.trim();
      if (b != null && b.isNotEmpty) set.add(b);
    }
    final list = set.toList()..sort();
    return list;
  }

  List<Deal> _filtered() {
    var list = [..._deals];
    if (_appliedSearch.isNotEmpty) {
      final q = _appliedSearch.toLowerCase();
      list = list.where((d) {
        return d.name.toLowerCase().contains(q) ||
            d.phone.contains(q) ||
            d.id.toLowerCase().contains(q);
      }).toList();
    }
    if (_salesId != null) {
      list = list.where((d) => d.salesEmployeeId == _salesId).toList();
    }
    if (_complex != 'all') {
      list = list.where((d) => d.residentialBlock == _complex).toList();
    }
    if (_houseType != 'all') {
      list = list.where((d) => d.houseType.api == _houseType).toList();
    }
    if (_fromDate != null) {
      final from = DateTime(_fromDate!.year, _fromDate!.month, _fromDate!.day);
      list = list.where((d) {
        final x = d.saleDate.toLocal();
        return !DateTime(x.year, x.month, x.day).isBefore(from);
      }).toList();
    }
    if (_toDate != null) {
      final to = DateTime(_toDate!.year, _toDate!.month, _toDate!.day, 23, 59, 59);
      list = list.where((d) => !d.saleDate.toLocal().isAfter(to)).toList();
    }
    list.sort((a, b) {
      return _sort == 'newest'
          ? b.saleDate.compareTo(a.saleDate)
          : a.saleDate.compareTo(b.saleDate);
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
      _page = 0;
    });
  }

  void _resetFilters() {
    setState(() {
      _salesId = null;
      _houseType = 'all';
      _complex = 'all';
      _fromDate = null;
      _toDate = null;
      _sort = 'newest';
      _search.clear();
      _appliedSearch = '';
      _page = 0;
    });
  }

  Future<void> _addDeal() async {
    final customers = context.read<CustomerController>();
    if (customers.items.isEmpty) await customers.load();
    if (!mounted) return;

    final customer = await showDialog<Customer>(
      context: context,
      builder: (ctx) => _PickCustomerDialog(customers: customers.items),
    );
    if (customer == null || !mounted) return;

    final ok = await CreateDealScreen.show(context, customer: customer);
    if (ok == true && mounted) {
      await _reloadDeals();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم إضافة الصفقة بنجاح')),
      );
    }
  }

  Future<void> _openDeal(Deal deal) async {
    final customers = context.read<CustomerController>();
    if (customers.items.isEmpty) await customers.load();
    if (!mounted) return;

    Customer? customer;
    for (final c in customers.items) {
      if (c.id == deal.customerId) {
        customer = c;
        break;
      }
    }
    if (customer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر العثور على ملف الزبون')),
      );
      return;
    }

    final ok = await CreateDealScreen.show(
      context,
      customer: customer,
      deal: deal,
    );
    if (ok == true && mounted) {
      await _reloadDeals();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تحديث الصفقة بنجاح')),
      );
    }
  }

  Future<void> _openPhone(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    try {
      await launchUrl(uri);
    } catch (_) {}
  }

  Future<void> _openChat(String phone) async {
    final digits = phone.replaceAll(RegExp(r'[^\d+]'), '');
    var normalized = digits.replaceAll('+', '');
    if (normalized.startsWith('0')) {
      normalized = '964${normalized.substring(1)}';
    }
    final uri = Uri.parse('https://wa.me/$normalized');
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final filtered = _filtered();
    final totalAll = _deals.length;
    final pageCount = filtered.isEmpty ? 1 : ((filtered.length - 1) ~/ _pageSize) + 1;
    final safePage = _page.clamp(0, pageCount - 1);
    if (safePage != _page) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _page = safePage);
      });
    }
    final start = filtered.isEmpty ? 0 : safePage * _pageSize;
    final end = (start + _pageSize).clamp(0, filtered.length);
    final pageItems = filtered.isEmpty ? <Deal>[] : filtered.sublist(start, end);
    final from = filtered.isEmpty ? 0 : start + 1;
    final to = end;

    final customers = context.watch<CustomerController>().items;
    Customer? customerOf(Deal d) {
      for (final c in customers) {
        if (c.id == d.customerId) return c;
      }
      return null;
    }

    return ColoredBox(
      color: const Color(0xFFF4F7FE),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _DealsHeader(
            userName: displayUserName(auth.user),
            avatarUrl: auth.user?.avatarUrl,
            search: _search,
            suggestions: ReceptionSearchBar.uniqueOf([
              for (final d in _deals) ...[d.name, d.phone, d.id],
            ]),
            onSearch: () => setState(() {
              _appliedSearch = _search.text.trim();
              _page = 0;
            }),
            onQueryChanged: (q) => setState(() {
              _appliedSearch = q.trim();
              _page = 0;
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
                    total: totalAll,
                    loading: _loading && _deals.isEmpty,
                    onAdd: _addDeal,
                  ),
                  const SizedBox(height: 10),
                  _FiltersBar(
                    sales: _sales,
                    salesId: _salesId,
                    sort: _sort,
                    houseType: _houseType,
                    complex: _complex,
                    complexOptions: _complexOptions,
                    fromDate: _fromDate,
                    toDate: _toDate,
                    grid: _grid,
                    onSales: (v) => setState(() {
                      _salesId = v;
                      _page = 0;
                    }),
                    onSort: (v) => setState(() {
                      _sort = v;
                      _page = 0;
                    }),
                    onHouseType: (v) => setState(() {
                      _houseType = v;
                      _page = 0;
                    }),
                    onComplex: (v) => setState(() {
                      _complex = v;
                      _page = 0;
                    }),
                    onPickFrom: () => _pickDate(from: true),
                    onPickTo: () => _pickDate(from: false),
                    onGrid: (v) => setState(() => _grid = v),
                    onReset: _resetFilters,
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: _loading && _deals.isEmpty
                        ? const Center(child: CircularProgressIndicator())
                        : filtered.isEmpty
                            ? Center(
                                child: Text(
                                  'لا توجد صفقات',
                                  style: GoogleFonts.cairo(
                                    fontWeight: FontWeight.w700,
                                    color: ReceptionTokens.muted,
                                  ),
                                ),
                              )
                            : _grid
                                ? _DealsGrid(
                                    scrollController: _scroll,
                                    deals: pageItems,
                                    customerOf: customerOf,
                                    houseLabel: _houseLabel,
                                    complexLabel: _complexLabel,
                                    onOpen: (d) =>
                                        widget.onOpenCustomer?.call(d.customerId),
                                    onPhone: (d) => _openPhone(d.phone),
                                    onChat: (d) => _openChat(d.phone),
                                    onEdit: _openDeal,
                                  )
                                : _DealsList(
                                    scrollController: _scroll,
                                    deals: pageItems,
                                    onOpen: (d) =>
                                        widget.onOpenCustomer?.call(d.customerId),
                                  ),
                  ),
                  const SizedBox(height: 8),
                  _PaginationBar(
                    from: from,
                    to: to,
                    total: filtered.length,
                    page: safePage,
                    pageCount: pageCount,
                    onPage: _goToPage,
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

class _DealsHeader extends StatelessWidget {
  const _DealsHeader({
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
                hint: 'ابحث باسم الزبون أو رقم الهاتف أو رقم العقد...',
                onQueryChanged: onQueryChanged,
                onSearch: onSearch,
              ),
            ),
            const SizedBox(width: 18),
            Row(
              children: [
                Text(
                  'الرئيسية',
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
                  'صفقات البيع',
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
    required this.loading,
    required this.onAdd,
  });

  final int total;
  final bool loading;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Row(
        children: [
          SizedBox(
            width: 220,
            child: _StatCard(
              label: 'إجمالي الصفقات',
              value: loading ? '—' : '$total',
              iconAsset: RAssets.statDeals,
              accent: const Color(0xFF1E6FD9),
              iconBg: const Color(0xFFDBEAFE),
            ),
          ),
          const Spacer(),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onAdd,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                height: 72,
                padding: const EdgeInsets.symmetric(horizontal: 18),
                decoration: BoxDecoration(
                  color: ReceptionTokens.confirmBlue,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: ReceptionTokens.softShadow,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.add, color: Colors.white, size: 22),
                    const SizedBox(width: 6),
                    Text(
                      'إضافة صفقة جديدة',
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
    this.valueSize = 24,
  });

  final String label;
  final String value;
  final String iconAsset;
  final Color accent;
  final Color iconBg;
  final double valueSize;

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
                  maxLines: 1,
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
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.cairo(
                    fontSize: valueSize,
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
    required this.salesId,
    required this.sort,
    required this.houseType,
    required this.complex,
    required this.complexOptions,
    required this.fromDate,
    required this.toDate,
    required this.grid,
    required this.onSales,
    required this.onSort,
    required this.onHouseType,
    required this.onComplex,
    required this.onPickFrom,
    required this.onPickTo,
    required this.onGrid,
    required this.onReset,
  });

  final List<AppUser> sales;
  final String? salesId;
  final String sort;
  final String houseType;
  final String complex;
  final List<String> complexOptions;
  final DateTime? fromDate;
  final DateTime? toDate;
  final bool grid;
  final ValueChanged<String?> onSales;
  final ValueChanged<String> onSort;
  final ValueChanged<String> onHouseType;
  final ValueChanged<String> onComplex;
  final VoidCallback onPickFrom;
  final VoidCallback onPickTo;
  final ValueChanged<bool> onGrid;
  final VoidCallback onReset;

  static const _navy = Color(0xFF002E45);
  static const _fieldBg = Color(0xFFF0F6FA);
  static const _border = Color(0xFFD5E4EE);

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
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
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: _filterField(
                label: 'ترتيب حسب',
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: sort,
                    isExpanded: true,
                    icon: const Icon(Icons.keyboard_arrow_down_rounded, color: _navy),
                    items: [
                      DropdownMenuItem(value: 'newest', child: Text('الأحدث أولاً', style: _item())),
                      DropdownMenuItem(value: 'oldest', child: Text('الأقدم أولاً', style: _item())),
                    ],
                    onChanged: (v) {
                      if (v != null) onSort(v);
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
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
                        (u) => DropdownMenuItem(
                          value: u.id,
                          child: Text(u.fullName, style: _item()),
                        ),
                      ),
                    ],
                    onChanged: onSales,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _filterField(
                label: 'نوع الدار',
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: houseType,
                    isExpanded: true,
                    icon: const Icon(Icons.keyboard_arrow_down_rounded, color: _navy),
                    items: [
                      DropdownMenuItem(value: 'all', child: Text('كل الأنواع', style: _item())),
                      DropdownMenuItem(value: 'villa', child: Text('فيلا', style: _item())),
                      DropdownMenuItem(value: 'house', child: Text('دار', style: _item())),
                    ],
                    onChanged: (v) {
                      if (v != null) onHouseType(v);
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _filterField(
                label: 'المجمع السكني',
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: complex,
                    isExpanded: true,
                    icon: const Icon(Icons.keyboard_arrow_down_rounded, color: _navy),
                    items: [
                      DropdownMenuItem(value: 'all', child: Text('كل المجمعات', style: _item())),
                      ...complexOptions.map(
                        (c) => DropdownMenuItem(value: c, child: Text(c, style: _item())),
                      ),
                    ],
                    onChanged: (v) {
                      if (v != null) onComplex(v);
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _filterField(
                label: 'التاريخ',
                child: Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: onPickFrom,
                        child: Text(
                          fromDate == null
                              ? 'من تاريخ'
                              : DateFormat('dd/MM/yyyy').format(fromDate!),
                          style: fromDate == null ? _hint() : _item(),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    Text(' - ', style: _hint()),
                    Expanded(
                      child: InkWell(
                        onTap: onPickTo,
                        child: Text(
                          toDate == null
                              ? 'إلى تاريخ'
                              : DateFormat('dd/MM/yyyy').format(toDate!),
                          style: toDate == null ? _hint() : _item(),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    const Icon(Icons.calendar_today_outlined, size: 16, color: _navy),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'إعادة تعيين',
                    onPressed: onReset,
                    icon: const Icon(Icons.refresh_rounded, size: 20),
                    color: ReceptionTokens.confirmBlue,
                    visualDensity: VisualDensity.compact,
                  ),
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
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
                  ),
                ],
              ),
            ),
          ],
        ),
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

  Widget _filterField({required String label, required Widget child}) {
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

  TextStyle _hint() =>
      GoogleFonts.cairo(fontWeight: FontWeight.w600, fontSize: 13, color: const Color(0xFF7A93A5));
  TextStyle _item() => GoogleFonts.cairo(fontWeight: FontWeight.w700, fontSize: 13, color: _navy);
}

// ───────────────────────── Grid / List ─────────────────────────

class _DealsGrid extends StatelessWidget {
  const _DealsGrid({
    required this.scrollController,
    required this.deals,
    required this.customerOf,
    required this.houseLabel,
    required this.complexLabel,
    required this.onOpen,
    required this.onPhone,
    required this.onChat,
    required this.onEdit,
  });

  final ScrollController scrollController;
  final List<Deal> deals;
  final Customer? Function(Deal) customerOf;
  final String Function(Deal) houseLabel;
  final String Function(Deal) complexLabel;
  final ValueChanged<Deal> onOpen;
  final ValueChanged<Deal> onPhone;
  final ValueChanged<Deal> onChat;
  final ValueChanged<Deal> onEdit;

  static const _cols = 4;
  static const _gap = 12.0;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final cardW =
              (constraints.maxWidth - _gap * (_cols - 1)) / _cols;
          return SingleChildScrollView(
            controller: scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(2, 2, 2, 8),
            child: Wrap(
              spacing: _gap,
              runSpacing: _gap,
              children: [
                for (final d in deals)
                  SizedBox(
                    width: cardW,
                    child: _DealCard(
                      deal: d,
                      house: houseLabel(d),
                      complex: complexLabel(d),
                      callCenterName: customerOf(d)?.callCenterName,
                      callCenterAvatarUrl: customerOf(d)?.callCenterAvatarUrl,
                      onOpen: () => onOpen(d),
                      onPhone: () => onPhone(d),
                      onChat: () => onChat(d),
                      onEdit: () => onEdit(d),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _DealsList extends StatelessWidget {
  const _DealsList({
    required this.scrollController,
    required this.deals,
    required this.onOpen,
  });

  final ScrollController scrollController;
  final List<Deal> deals;
  final ValueChanged<Deal> onOpen;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: ListView.separated(
        controller: scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: deals.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, i) {
          final d = deals[i];
          return Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            child: ListTile(
              onTap: () => onOpen(d),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset(
                  RAssets.salesDealVilla,
                  width: 56,
                  height: 56,
                  fit: BoxFit.cover,
                ),
              ),
              title: Text(
                d.name,
                style: GoogleFonts.cairo(fontWeight: FontWeight.w800, color: const Color(0xFF123B70)),
              ),
              subtitle: Text(
                '${d.houseType.label} · ${formatMoney(d.totalPrice)} · ${DateFormat('dd/MM/yyyy').format(d.saleDate.toLocal())}',
                style: GoogleFonts.cairo(fontWeight: FontWeight.w600, fontSize: 12),
              ),
              trailing: Text(
                d.status.label,
                style: GoogleFonts.cairo(
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF059669),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _DealCard extends StatelessWidget {
  const _DealCard({
    required this.deal,
    required this.house,
    required this.complex,
    required this.callCenterName,
    this.callCenterAvatarUrl,
    required this.onOpen,
    required this.onPhone,
    required this.onChat,
    required this.onEdit,
  });

  final Deal deal;
  final String house;
  final String complex;
  final String? callCenterName;
  final String? callCenterAvatarUrl;
  final VoidCallback onOpen;
  final VoidCallback onPhone;
  final VoidCallback onChat;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final date = DateFormat('dd/MM/yyyy').format(deal.saleDate.toLocal());
    final paid = deal.downPayment;
    final total = deal.totalPrice;
    final ratio = total <= 0 ? 0.0 : (paid / total).clamp(0.0, 1.0);
    final pct = (ratio * 100).round();
    final barColor = pct >= 100 ? const Color(0xFF059669) : const Color(0xFF1E6FD9);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF069BAF).withValues(alpha: 0.23),
            blurRadius: 10,
            offset: Offset.zero,
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 118,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  RAssets.salesDealVilla,
                  fit: BoxFit.cover,
                  filterQuality: FilterQuality.high,
                ),
                Positioned(
                  top: 10,
                  right: 10,
                  child: _GlassStatusBadge(
                    label: deal.status.label,
                    color: const Color(0xFF059669),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  deal.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.cairo(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF123B70),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.home_outlined, size: 13, color: Color(0xFF64748B)),
                    const SizedBox(width: 3),
                    Flexible(
                      child: Text(
                        house,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.cairo(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.apartment, size: 13, color: Color(0xFF64748B)),
                    const SizedBox(width: 3),
                    Flexible(
                      child: Text(
                        complex,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.cairo(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.calendar_today, size: 11, color: Color(0xFF64748B)),
                    const SizedBox(width: 3),
                    Text(
                      date,
                      style: GoogleFonts.cairo(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      'قيمة الدار',
                      style: GoogleFonts.cairo(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      formatMoney(total),
                      style: GoogleFonts.cairo(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF123B70),
                      ),
                    ),
                  ],
                ),
                Text(
                  'المدفوع: ${formatMoney(paid)}',
                  style: GoogleFonts.cairo(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF94A3B8),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: ratio,
                          minHeight: 6,
                          backgroundColor: const Color(0xFFE2E8F0),
                          valueColor: AlwaysStoppedAnimation(barColor),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$pct%',
                      style: GoogleFonts.cairo(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: barColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: _PersonRow(
                        label: 'موظف المبيعات',
                        name: deal.salesEmployeeName ?? '—',
                        avatarUrl: deal.salesEmployeeAvatarUrl,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _PersonRow(
                        label: 'موظف الكول سنتر',
                        name: callCenterName ?? '—',
                        avatarUrl: callCenterAvatarUrl,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _OutlineIconBtn(icon: Icons.phone_outlined, onTap: onPhone),
                    const SizedBox(width: 6),
                    _OutlineIconBtn(
                      onTap: onChat,
                      child: RAssets.source('whatsapp', size: 16),
                    ),
                    const SizedBox(width: 6),
                    _OutlineIconBtn(icon: Icons.edit_outlined, onTap: onEdit),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Material(
                        color: const Color(0xFFE8F4FF),
                        borderRadius: BorderRadius.circular(10),
                        child: InkWell(
                          onTap: onOpen,
                          borderRadius: BorderRadius.circular(10),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 8),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'عرض التفاصيل',
                                  style: GoogleFonts.cairo(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: ReceptionTokens.confirmBlue,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Transform.rotate(
                                  angle: 3.141592653589793,
                                  child: const Icon(
                                    Icons.chevron_left,
                                    size: 16,
                                    color: ReceptionTokens.confirmBlue,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PersonRow extends StatelessWidget {
  const _PersonRow({
    required this.label,
    required this.name,
    this.avatarUrl,
  });

  final String label;
  final String name;
  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        StaffAvatar(avatarUrl: avatarUrl, radius: 11),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.cairo(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF94A3B8),
                  height: 1.1,
                ),
              ),
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.cairo(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF123B70),
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _OutlineIconBtn extends StatelessWidget {
  const _OutlineIconBtn({
    required this.onTap,
    this.icon,
    this.child,
  }) : assert(icon != null || child != null);

  final IconData? icon;
  final Widget? child;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: ReceptionTokens.confirmBlue.withValues(alpha: 0.45)),
          ),
          child: child ??
              Icon(icon, size: 16, color: ReceptionTokens.confirmBlue),
        ),
      ),
    );
  }
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
      duration: const Duration(milliseconds: 2400),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const radius = 20.0;
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        final shine = (_ctrl.value * 1.35) - 0.2;
        return ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: CustomPaint(
              foregroundPainter: _DealShimmerPainter(progress: shine),
              child: child,
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.82),
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: widget.color.withValues(alpha: 0.55), width: 0.8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
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

class _DealShimmerPainter extends CustomPainter {
  _DealShimmerPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress < 0 || progress > 1.15) return;
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
    canvas.rotate(-0.35);
    canvas.translate(-(x + bandW / 2), -size.height / 2);
    canvas.drawRect(rect, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _DealShimmerPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

// ───────────────────────── Pagination ─────────────────────────

class _PaginationBar extends StatelessWidget {
  const _PaginationBar({
    required this.from,
    required this.to,
    required this.total,
    required this.page,
    required this.pageCount,
    required this.onPage,
  });

  final int from;
  final int to;
  final int total;
  final int page;
  final int pageCount;
  final ValueChanged<int> onPage;

  @override
  Widget build(BuildContext context) {
    final pages = List.generate(pageCount.clamp(1, 8), (i) => i);

    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF069BAF).withValues(alpha: 0.12),
              blurRadius: 8,
              offset: Offset.zero,
            ),
          ],
        ),
        child: Row(
          children: [
            Text(
              'عرض $from - $to من $total صفقة',
              style: GoogleFonts.cairo(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: const Color(0xFF123B70),
              ),
            ),
            const SizedBox(width: 10),
            Container(
              height: 32,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F6FA),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFD5E4EE)),
              ),
              alignment: Alignment.center,
              child: Text(
                '12',
                style: GoogleFonts.cairo(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  color: const Color(0xFF123B70),
                ),
              ),
            ),
            const Spacer(),
            IconButton(
              onPressed: page > 0 ? () => onPage(page - 1) : null,
              icon: const Icon(Icons.chevron_right, size: 20),
              color: ReceptionTokens.confirmBlue,
              visualDensity: VisualDensity.compact,
            ),
            ...pages.map((p) {
              final active = p == page;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: InkWell(
                  onTap: () => onPage(p),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 32,
                    height: 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: active ? ReceptionTokens.confirmBlue : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${p + 1}',
                      style: GoogleFonts.cairo(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        color: active ? Colors.white : const Color(0xFF123B70),
                      ),
                    ),
                  ),
                ),
              );
            }),
            IconButton(
              onPressed: page < pageCount - 1 ? () => onPage(page + 1) : null,
              icon: const Icon(Icons.chevron_left, size: 20),
              color: ReceptionTokens.confirmBlue,
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────── Pick customer ─────────────────────────

class _PickCustomerDialog extends StatefulWidget {
  const _PickCustomerDialog({required this.customers});

  final List<Customer> customers;

  @override
  State<_PickCustomerDialog> createState() => _PickCustomerDialogState();
}

class _PickCustomerDialogState extends State<_PickCustomerDialog> {
  final _q = TextEditingController();

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final q = _q.text.trim();
    final list = q.isEmpty
        ? widget.customers
        : widget.customers
            .where((c) => c.name.contains(q) || c.phone.contains(q))
            .toList();

    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: AlertDialog(
        title: Text(
          'اختر الزبون',
          style: GoogleFonts.cairo(fontWeight: FontWeight.w800),
        ),
        content: SizedBox(
          width: 420,
          height: 420,
          child: Column(
            children: [
              TextField(
                controller: _q,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'ابحث عن زبون...',
                  hintStyle: GoogleFonts.cairo(),
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                style: GoogleFonts.cairo(),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: list.isEmpty
                    ? Center(
                        child: Text(
                          'لا يوجد زبائن',
                          style: GoogleFonts.cairo(fontWeight: FontWeight.w700),
                        ),
                      )
                    : ListView.separated(
                        itemCount: list.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final c = list[i];
                          return ListTile(
                            onTap: () => Navigator.pop(context, c),
                            title: Text(
                              c.name,
                              style: GoogleFonts.cairo(fontWeight: FontWeight.w800),
                            ),
                            subtitle: Text(
                              c.phone,
                              style: GoogleFonts.cairo(fontWeight: FontWeight.w600),
                            ),
                            trailing: const Icon(Icons.chevron_left),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('إلغاء', style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}
