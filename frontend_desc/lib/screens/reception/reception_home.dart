import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

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
import '../../utils/validators.dart';
import '../../widgets/reception/reception_assets.dart';
import '../../widgets/reception/reception_search_bar.dart';
import '../../widgets/staff_avatar.dart';
import '../shared/customer_profile_screen.dart';
import 'approve_booking_screen.dart';
import 'customer_files_screen.dart';
import 'sales_deals_screen.dart';
import 'visits_log_screen.dart';

/// Reception home — pixel-matched to Figma Desktop-31 (31:6256).
class ReceptionHome extends StatefulWidget {
  const ReceptionHome({super.key});

  @override
  State<ReceptionHome> createState() => _ReceptionHomeState();
}

class _ReceptionHomeState extends State<ReceptionHome> {
  int _nav = 0;
  String? _profileCustomerId;
  BookingStatus? _statusFilter;
  DateTime? _dateFilter;
  final _search = TextEditingController();
  final _qName = TextEditingController();
  final _qPhone = TextEditingController();
  final _tableScroll = ScrollController();
  List<AppUser> _sales = [];
  String? _qSalesId;

  static const _pageSize = 12;
  int _page = 0;

  void _openCustomerProfile(String customerId) {
    setState(() {
      _profileCustomerId = customerId;
    });
  }

  void _closeCustomerProfile() {
    setState(() {
      _profileCustomerId = null;
    });
  }

  Widget _mainContent(AuthController auth, BookingController bookings) {
    if (_profileCustomerId != null) {
      return CustomerProfileScreen(
        key: ValueKey(_profileCustomerId),
        customerId: _profileCustomerId!,
        embedded: true,
        onBack: _closeCustomerProfile,
        canEdit: true,
        canAddDeal: true,
        canAddVisit: true,
        canUploadDocs: true,
      );
    }
    if (_nav == 1) {
      return CustomerFilesScreen(onOpenCustomer: _openCustomerProfile);
    }
    if (_nav == 2) {
      return VisitsLogScreen(onOpenCustomer: _openCustomerProfile);
    }
    if (_nav == 3) {
      return SalesDealsScreen(onOpenCustomer: _openCustomerProfile);
    }
    return _homeBody(auth, bookings);
  }

  void _onSidebarSelect(int i) {
    setState(() {
      _nav = i;
      if (i != 1) _profileCustomerId = null;
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final bookingCtrl = context.read<BookingController>();
      final customerCtrl = context.read<CustomerController>();
      final api = context.read<ApiClient>();
      await bookingCtrl.load();
      await customerCtrl.load();
      try {
        _sales = await UserService(api).list(role: UserRole.sales);
        if (_sales.isNotEmpty) _qSalesId = _sales.first.id;
      } catch (_) {}
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _search.dispose();
    _qName.dispose();
    _qPhone.dispose();
    _tableScroll.dispose();
    super.dispose();
  }

  bool _sameDay(DateTime a, DateTime b) {
    final x = a.toLocal();
    return x.year == b.year && x.month == b.month && x.day == b.day;
  }

  void _goToPage(int p) {
    setState(() => _page = p);
    if (_tableScroll.hasClients) {
      _tableScroll.animateTo(
        0,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    }
  }

  List<Booking> _rows(List<Booking> all) {
    var list = [...all];
    // No filters → all bookings. Filters narrow the list.
    if (_dateFilter != null) {
      list = list.where((b) => _sameDay(b.visitDate, _dateFilter!)).toList();
    }
    if (_statusFilter != null) {
      list = list.where((b) => b.status == _statusFilter).toList();
    }
    final q = _search.text.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list
          .where(
            (b) =>
                b.name.toLowerCase().contains(q) ||
                b.phone.contains(q) ||
                b.governorate.toLowerCase().contains(q),
          )
          .toList();
    }
    list.sort((a, b) => b.visitDate.compareTo(a.visitDate));
    return list;
  }

  Future<void> _refresh() async {
    await context.read<BookingController>().load();
    await context.read<CustomerController>().load();
  }

  Future<void> _approve(Booking b) async {
    final outcome = await showApproveBookingDialog(context, b, sales: _sales);
    if (!mounted || outcome == null) return;
    if (outcome.result == ApproveDialogResult.viewProfile) {
      final customerId = outcome.customerId ?? b.customerId;
      if (customerId != null) _openCustomerProfile(customerId);
      return;
    }
    if (outcome.result == ApproveDialogResult.confirmed ||
        outcome.result == ApproveDialogResult.confirmedAndOpen) {
      await _refresh();
      if (outcome.result == ApproveDialogResult.confirmedAndOpen && mounted) {
        Booking updated = b;
        for (final item in context.read<BookingController>().items) {
          if (item.id == b.id) {
            updated = item;
            break;
          }
        }
        final customerId =
            outcome.customerId ?? updated.customerId ?? b.customerId;
        if (customerId != null) _openCustomerProfile(customerId);
      }
    }
  }

  void _profile(Booking b) {
    if (b.customerId == null) return;
    _openCustomerProfile(b.customerId!);
  }

  Future<void> _quickCreateCustomer() async {
    final name = _qName.text.trim();
    final phone = _qPhone.text.trim();
    final nameErr = AppValidators.personName(name);
    final phoneErr = AppValidators.phone(phone);
    if (nameErr != null || phoneErr != null || _qSalesId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            nameErr ??
                phoneErr ??
                'أكمل بيانات إنشاء ملف الزبون',
          ),
        ),
      );
      return;
    }
    final customer = await context.read<CustomerController>().create({
      'name': name,
      'phone': phone,
      'salesEmployeeId': _qSalesId,
    });
    if (!mounted) return;
    if (customer == null) {
      final err = context.read<CustomerController>().error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err ?? 'تعذر إنشاء ملف الزبون')),
      );
      return;
    }
    _qName.clear();
    _qPhone.clear();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم إنشاء ملف الزبون بنجاح')),
    );
    _openCustomerProfile(customer.id);
  }

  Widget _homeBody(AuthController auth, BookingController bookings) {
    final all = bookings.items;
    final today = DateTime.now();
    final todayList = all.where((b) => _sameDay(b.visitDate, today)).toList();
    // اليوم = حجوزات اليوم فقط؛ المكتملة/المتبقية من كل الحجوزات.
    final total = todayList.length;
    final done = all.where((b) => b.status == BookingStatus.approved).length;
    final left = all.where((b) => b.status == BookingStatus.pending).length;
    final rows = _rows(all);
    final pageCount = rows.isEmpty ? 1 : ((rows.length - 1) ~/ _pageSize) + 1;
    final safePage = _page.clamp(0, pageCount - 1);
    if (safePage != _page) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _page = safePage);
      });
    }
    final start = rows.isEmpty ? 0 : safePage * _pageSize;
    final end = (start + _pageSize).clamp(0, rows.length);
    final pageRows = rows.isEmpty ? <Booking>[] : rows.sublist(start, end);
    final from = rows.isEmpty ? 0 : start + 1;
    final to = end;

    return Column(
      children: [
        _Header(
          userName: displayUserName(auth.user),
          avatarUrl: auth.user?.avatarUrl,
          search: _search,
          suggestions: ReceptionSearchBar.uniqueOf([
            for (final b in all) ...[b.name, b.phone, b.governorate],
          ]),
          onSearch: () => setState(() => _page = 0),
          onQueryChanged: (_) => setState(() => _page = 0),
          onLogout: () => context.read<AuthController>().logout(),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(30, 12, 24, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _QuickCustomerCreate(
                      sales: _sales,
                      name: _qName,
                      phone: _qPhone,
                      salesId: _qSalesId,
                      onSales: (v) => setState(() => _qSalesId = v),
                      onCreate: _quickCreateCustomer,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const _Banner(),
                          const SizedBox(height: 16),
                          _Stats(total: total, done: done, left: left),
                          const SizedBox(height: 24),
                          _TableFilters(
                            statusFilter: _statusFilter,
                            dateFilter: _dateFilter,
                            onStatus: (v) => setState(() {
                              _statusFilter = v;
                              _page = 0;
                            }),
                            onDate: (v) => setState(() {
                              _dateFilter = v;
                              _page = 0;
                            }),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: _BookingsTable(
                    rows: pageRows,
                    rowOffset: start,
                    scrollController: _tableScroll,
                    loading: bookings.loading && all.isEmpty,
                    onApprove: _approve,
                    onProfile: _profile,
                  ),
                ),
                const SizedBox(height: 8),
                _BookingsPagination(
                  from: from,
                  to: to,
                  total: rows.length,
                  page: safePage,
                  pageCount: pageCount,
                  onPage: _goToPage,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final bookings = context.watch<BookingController>();

    // Layout follows Figma absolute LTR coordinates (sidebar on the right).
    return Directionality(
      textDirection: ui.TextDirection.ltr,
      child: Scaffold(
        backgroundColor: ReceptionTokens.bg,
        body: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: _mainContent(auth, bookings)),
            _Sidebar(
              selected: _nav,
              onSelect: _onSidebarSelect,
            ),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────── Sidebar 266px ─────────────────────────

class _Sidebar extends StatelessWidget {
  const _Sidebar({required this.selected, required this.onSelect});
  final int selected;
  final ValueChanged<int> onSelect;

  static const _logo =
      'asset/Premium Gold and Teal Real Estate Emblem.png';

  static const _items = [
    ('dc_home', 'الصفحة الرئيسية'),
    ('dc_firstaid', 'ملفات الزبائن'),
    ('dc_document', 'سجل الزيارات'),
    ('dc_target', 'صفقات البيع'),
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: ReceptionTokens.sidebarWidth,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage(RAssets.receptionSidebar),
                fit: BoxFit.cover,
                alignment: Alignment.centerRight,
                filterQuality: FilterQuality.high,
              ),
            ),
          ),
          // Dark veil so menu text stays readable over the villa photo.
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  ReceptionTokens.navy.withValues(alpha: 0.92),
                  ReceptionTokens.navy.withValues(alpha: 0.72),
                  ReceptionTokens.navy.withValues(alpha: 0.55),
                ],
              ),
            ),
          ),
          Directionality(
            textDirection: ui.TextDirection.rtl,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 28),
              child: Column(
                children: [
                // Brand block — same style as call-center sidebar.
                SizedBox(
                  width: 120,
                  height: 120,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Transform.translate(
                        offset: const Offset(0, 8),
                        child: ImageFiltered(
                          imageFilter:
                              ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: Opacity(
                            opacity: 0.45,
                            child: ColorFiltered(
                              colorFilter: const ColorFilter.mode(
                                Colors.black,
                                BlendMode.srcIn,
                              ),
                              child: Image.asset(
                                _logo,
                                width: 120,
                                height: 120,
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Image.asset(
                        _logo,
                        width: 120,
                        height: 120,
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.high,
                      ),
                    ],
                  ),
                ),
                Transform.translate(
                  offset: const Offset(0, -14),
                  child: Column(
                    children: [
                      Text(
                        'عماد سكر',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.cairo(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          height: 1.2,
                          shadows: const [
                            Shadow(
                              color: Color(0x88000000),
                              blurRadius: 8,
                              offset: Offset(0, 1),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'نظام ادارة مبيعات المجمع',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.cairo(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.white.withValues(alpha: 0.92),
                          height: 1.35,
                          shadows: const [
                            Shadow(
                              color: Color(0x88000000),
                              blurRadius: 6,
                              offset: Offset(0, 1),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                _sectionLabel('القائمة الرئيسية'),
                const SizedBox(height: 12),
                _navBtn(
                  index: 0,
                  icon: _items[0].$1,
                  label: _items[0].$2,
                ),
                const SizedBox(height: 18),
                _sectionLabel('إدارة الحجوزات'),
                const SizedBox(height: 12),
                _navBtn(
                  index: 1,
                  icon: _items[1].$1,
                  label: _items[1].$2,
                  imageAsset: RAssets.customerFilesIcon,
                ),
                const SizedBox(height: 10),
                _navBtn(
                  index: 2,
                  icon: _items[2].$1,
                  label: _items[2].$2,
                ),
                const SizedBox(height: 10),
                _navBtn(
                  index: 3,
                  icon: _items[3].$1,
                  label: _items[3].$2,
                ),
                const Spacer(),
              ],
            ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String title) {
    return Row(
      children: [
        Expanded(
          child: Divider(
            color: Colors.white.withValues(alpha: 0.28),
            thickness: 1,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            title,
            style: GoogleFonts.cairo(
              color: Colors.white.withValues(alpha: 0.75),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Expanded(
          child: Divider(
            color: Colors.white.withValues(alpha: 0.28),
            thickness: 1,
          ),
        ),
      ],
    );
  }

  Widget _navBtn({
    required int index,
    required String icon,
    required String label,
    String? imageAsset,
  }) {
    final active = selected == index;

    Widget iconChild({required double size, required Color color}) {
      if (imageAsset != null) {
        return ColorFiltered(
          colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
          child: Image.asset(
            imageAsset,
            width: size,
            height: size,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
          ),
        );
      }
      return RAssets.svg(icon, w: size, h: size, color: color);
    }

    return Align(
      alignment: Alignment.centerRight,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onSelect(index),
          borderRadius: BorderRadius.circular(14),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            height: 46,
            width: double.infinity,
            padding: const EdgeInsetsDirectional.fromSTEB(12, 0, 8, 0),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: active
                  ? const Color(0xFFE8F4F8)
                  : Colors.white.withValues(alpha: 0.10),
              border: Border.all(
                color: active
                    ? Colors.transparent
                    : Colors.white.withValues(alpha: 0.22),
                width: 1,
              ),
              boxShadow: active
                  ? [
                      BoxShadow(
                        color: const Color(0xFF069BAF).withValues(alpha: 0.45),
                        blurRadius: 14,
                        offset: const Offset(-2, 0),
                      ),
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.18),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            // RTL: first child sits on the right → icon then label.
            child: Row(
              children: [
                if (active)
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: ReceptionTokens.teal,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color:
                              ReceptionTokens.teal.withValues(alpha: 0.55),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: iconChild(size: 16, color: Colors.white),
                  )
                else
                  SizedBox(
                    width: 32,
                    height: 32,
                    child: Center(
                      child: iconChild(
                        size: 18,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    textAlign: TextAlign.right,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.cairo(
                      color: active ? ReceptionTokens.navy : Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ───────────────────────── Header ─────────────────────────

class _Header extends StatelessWidget {
  const _Header({
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(30, 20, 24, 8),
      child: Row(
        children: [
          // Bell
          _card(
            height: 58,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Center(child: RAssets.svg('dc_bell', w: 24, h: 24)),
          ),
          const SizedBox(width: 10),
          // Profile
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
                'الرئيسية',
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

// ───────────────────────── Banner 158px ─────────────────────────

class _Banner extends StatelessWidget {
  const _Banner();

  static const double _h = 140;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: _h,
        width: double.infinity,
        child: Image.asset(
          RAssets.homeBanner,
          fit: BoxFit.cover,
          width: double.infinity,
          height: _h,
          filterQuality: FilterQuality.high,
          // Positive Y shows more of the villas/road (was clipping the bottom).
          alignment: const Alignment(0, 0.55),
        ),
      ),
    );
  }
}

// ───────────────────────── Quick customer create 263×322 ─────────────────────────

class _QuickCustomerCreate extends StatelessWidget {
  const _QuickCustomerCreate({
    required this.sales,
    required this.name,
    required this.phone,
    required this.salesId,
    required this.onSales,
    required this.onCreate,
  });

  final List<AppUser> sales;
  final TextEditingController name;
  final TextEditingController phone;
  final String? salesId;
  final ValueChanged<String?> onSales;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Container(
        width: 263,
        height: 322,
        padding: const EdgeInsets.fromLTRB(11, 20, 11, 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: ReceptionTokens.softShadow,
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 52,
                  height: 46,
                  decoration: BoxDecoration(
                    color: ReceptionTokens.plusBg,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(child: RAssets.svg('dc_plus', w: 28, h: 28)),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'انشاء ملف زبون سريع',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: ReceptionTokens.navy,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      height: 1.2,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _field(
              name,
              'ادخل اسم الزبون......',
              RAssets.svg('dc_person', w: 15, h: 24),
              formatters: [PersonNameInputFormatter()],
            ),
            const SizedBox(height: 13),
            _field(
              phone,
              '07xxxxxxxxx',
              RAssets.svg('dc_phone', w: 16, h: 16),
              keyboard: TextInputType.phone,
              formatters: [IraqPhoneInputFormatter()],
            ),
            const SizedBox(height: 13),
            Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: ReceptionTokens.fieldBorder, width: 0.5),
                boxShadow: ReceptionTokens.cardShadow,
              ),
              child: Row(
                children: [
                  RAssets.svg('dc_people', w: 30, h: 30),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: salesId,
                        hint: Text(
                          'اختر موظف المبيعات .....',
                          style: TextStyle(
                            color: ReceptionTokens.navy.withValues(alpha: 0.5),
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                        icon: const SizedBox.shrink(),
                        items: sales
                            .map(
                              (u) => DropdownMenuItem(
                                value: u.id,
                                child: Row(
                                  children: [
                                    StaffAvatar(user: u, radius: 12),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                        u.fullName,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: onSales,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            SizedBox(
              width: 197,
              height: 44,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: ReceptionTokens.confirmBlue,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: onCreate,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    RAssets.svg('dc_confirm', w: 18, h: 18),
                    const SizedBox(width: 8),
                    const Text(
                      'انشاء الملف',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
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

  Widget _field(
    TextEditingController c,
    String hint,
    Widget icon, {
    TextInputType? keyboard,
    List<TextInputFormatter>? formatters,
  }) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ReceptionTokens.fieldBorder, width: 0.5),
        boxShadow: ReceptionTokens.cardShadow,
      ),
      child: Row(
        children: [
          Padding(padding: const EdgeInsets.only(left: 8, right: 10), child: icon),
          Expanded(
            child: TextField(
              controller: c,
              keyboardType: keyboard,
              inputFormatters: formatters,
              textAlign: TextAlign.right,
              textDirection: ui.TextDirection.rtl,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: ReceptionTokens.navy,
              ),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                hintText: hint,
                hintTextDirection: ui.TextDirection.rtl,
                hintStyle: TextStyle(
                  color: ReceptionTokens.navy.withValues(alpha: 0.5),
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────── Stats 268×86 ─────────────────────────

class _Stats extends StatelessWidget {
  const _Stats({required this.total, required this.done, required this.left});
  final int total;
  final int done;
  final int left;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _card('$left حجز', 'عدد الحجوزات المتبقية')),
        const SizedBox(width: 16),
        Expanded(child: _card('$done حجز', 'عدد الحجوزات المكتملة')),
        const SizedBox(width: 16),
        Expanded(child: _card('$total حجز', 'عدد الحجوزات اليوم')),
      ],
    );
  }

  Widget _card(String value, String label) {
    return Container(
      height: 86,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: ReceptionTokens.softShadow,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    color: ReceptionTokens.navy,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  label,
                  style: TextStyle(
                    color: ReceptionTokens.navy.withValues(alpha: 0.7),
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 44.4,
                height: 44.4,
                decoration: BoxDecoration(
                  color: ReceptionTokens.teal.withValues(alpha: 0.23),
                  borderRadius: BorderRadius.circular(17.76),
                ),
              ),
              Image.asset(RAssets.statIcon, width: 27, height: 27, fit: BoxFit.contain),
            ],
          ),
        ],
      ),
    );
  }
}

// ───────────────────────── Table ─────────────────────────

class _TableFilters extends StatelessWidget {
  const _TableFilters({
    required this.statusFilter,
    required this.dateFilter,
    required this.onStatus,
    required this.onDate,
  });

  final BookingStatus? statusFilter;
  final DateTime? dateFilter;
  final ValueChanged<BookingStatus?> onStatus;
  final ValueChanged<DateTime?> onDate;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _filter(
          dateFilter == null ? 'تاريخ الحضور' : DateFormat('yyyy/MM/dd').format(dateFilter!),
          () async {
            final d = await showDatePicker(
              context: context,
              initialDate: dateFilter ?? DateTime.now(),
              firstDate: DateTime(2024),
              lastDate: DateTime(2030),
            );
            onDate(d);
          },
        ),
        const SizedBox(width: 15),
        _filter(
          statusFilter?.label ?? 'كل الحالات',
          () async {
            final v = await showModalBottomSheet<BookingStatus?>(
              context: context,
              builder: (c) => SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      title: const Text('كل الحالات'),
                      onTap: () => Navigator.pop(c),
                    ),
                    ListTile(
                      title: Text(BookingStatus.pending.label),
                      onTap: () => Navigator.pop(c, BookingStatus.pending),
                    ),
                    ListTile(
                      title: Text(BookingStatus.approved.label),
                      onTap: () => Navigator.pop(c, BookingStatus.approved),
                    ),
                  ],
                ),
              ),
            );
            onStatus(v);
          },
        ),
        const Spacer(),
        const Text(
          'الحجوزات',
          style: TextStyle(
            color: ReceptionTokens.navy,
            fontWeight: FontWeight.w700,
            fontSize: 23,
          ),
        ),
      ],
    );
  }

  Widget _filter(String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 192,
        height: 50,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: ReceptionTokens.softShadow,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            RAssets.svg('dc_chevron', w: 23, h: 23),
            Text(
              label,
              style: const TextStyle(
                color: ReceptionTokens.navy,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BookingsTable extends StatelessWidget {
  const _BookingsTable({
    required this.rows,
    required this.rowOffset,
    required this.scrollController,
    required this.loading,
    required this.onApprove,
    required this.onProfile,
  });

  final List<Booking> rows;
  final int rowOffset;
  final ScrollController scrollController;
  final bool loading;
  final ValueChanged<Booking> onApprove;
  final ValueChanged<Booking> onProfile;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header container — Figma: drop shadow #069BAF 23%, blur 10, x0 y0
        Container(
          height: 62,
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            boxShadow: ReceptionTokens.cardShadow,
          ),
          child: const Row(
            children: [
              SizedBox(width: 28),
              Expanded(flex: 12, child: _Th('اجراء')),
              Expanded(flex: 11, child: _Th('الحالة')),
              Expanded(flex: 14, child: _Th('موظف الكول سنتر')),
              Expanded(flex: 11, child: _Th('الموعد')),
              Expanded(flex: 11, child: _Th('مصدر الحجز')),
              Expanded(flex: 10, child: _Th('المحافظة')),
              Expanded(flex: 12, child: _Th('رقم الهاتف')),
              Expanded(flex: 12, child: _Th('اسم الزبون')),
              SizedBox(width: 36, child: _Th('#')),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Content container
        Expanded(
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
              boxShadow: ReceptionTokens.cardShadow,
            ),
            child: loading
                ? const Center(
                    child: CircularProgressIndicator(color: ReceptionTokens.teal),
                  )
                : rows.isEmpty
                    ? const Center(
                        child: Text(
                          'لا توجد حجوزات',
                          style: TextStyle(color: ReceptionTokens.navy),
                        ),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 14),
                        itemCount: rows.length,
                        itemBuilder: (context, i) {
                          final b = rows[i];
                          final ok = b.status == BookingStatus.approved;
                          final d = b.visitDate.toLocal();
                          final date = DateFormat('dd/MM/yyyy').format(d);
                          final time = DateFormat('hh:mm a', 'ar').format(d);
                          final indexLabel =
                              (rowOffset + i + 1).toString().padLeft(2, '0');
                          return Container(
                            margin: const EdgeInsets.symmetric(vertical: 3),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                            decoration: BoxDecoration(
                              color: i.isEven ? ReceptionTokens.rowAlt : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 28,
                                  child: Center(child: RAssets.svg('dc_menu', w: 16, h: 16)),
                                ),
                                Expanded(
                                  flex: 12,
                                  child: Center(
                                    child: ok
                                        ? _outlineBtn('عرض الملف', () => onProfile(b))
                                        : _fillBtn('تاكيد الحضور', () => onApprove(b)),
                                  ),
                                ),
                                Expanded(
                                  flex: 11,
                                  child: Center(
                                    child: ok ? _attendedPill() : _pendingPill(),
                                  ),
                                ),
                                Expanded(
                                  flex: 14,
                                  child: Directionality(
                                    textDirection: ui.TextDirection.rtl,
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        StaffAvatar(
                                          avatarUrl: b.callCenterAvatarUrl,
                                          radius: 14,
                                          backgroundColor: const Color(0xFFE8F0FE),
                                        ),
                                        const SizedBox(width: 8),
                                        Flexible(
                                          child: Text(
                                            b.callCenterName ?? '—',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              color: ReceptionTokens.navy,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 11,
                                  child: Text(
                                    '$date\n$time',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: ReceptionTokens.linkBlue,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                      decoration: TextDecoration.underline,
                                      decorationColor: ReceptionTokens.linkBlue,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 11,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        b.source.label,
                                        style: const TextStyle(
                                          color: ReceptionTokens.navy,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      RAssets.source(b.source.api, size: 28),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  flex: 10,
                                  child: Text(
                                    b.governorate,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: ReceptionTokens.navy,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 12,
                                  child: Text(
                                    b.phone,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: ReceptionTokens.linkBlue,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                      decoration: TextDecoration.underline,
                                      decorationColor: ReceptionTokens.linkBlue,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 12,
                                  child: Text(
                                    b.name,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: ReceptionTokens.navy,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  width: 36,
                                  child: Text(
                                    indexLabel,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: ReceptionTokens.navy.withValues(alpha: 0.4),
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ),
      ],
    );
  }

  /// Figma: hug ~137×41, pad 12, gap 6, r16, fill #FFF, stroke #002E45 0.3,
  /// shadow blur 4 @ 77% #002E45 — icon on the right
  Widget _outlineBtn(String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 41,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: ReceptionTokens.navy, width: 0.3),
          boxShadow: [
            BoxShadow(
              color: ReceptionTokens.navy.withValues(alpha: 0.77),
              blurRadius: 4,
              offset: Offset.zero,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: ReceptionTokens.navy.withValues(alpha: 0.86),
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
            const SizedBox(width: 6),
            Image.asset(
              RAssets.viewProfileIcon,
              width: 22,
              height: 16,
              fit: BoxFit.contain,
            ),
          ],
        ),
      ),
    );
  }

  /// Figma: 141×40, pad 12, gap 6, r16, fill #002E45 — icon on the right
  Widget _fillBtn(String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 141,
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: ReceptionTokens.navy,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
            const SizedBox(width: 6),
            Image.asset(
              RAssets.confirmAttendanceIcon,
              width: 12,
              height: 16,
              fit: BoxFit.contain,
            ),
          ],
        ),
      ),
    );
  }

  /// Figma: 98×40 hug, pad 12, gap 6, r16, fill #9FD0C0
  Widget _attendedPill() {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: ReceptionTokens.statusGreenBg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'حضر',
            style: TextStyle(
              color: ReceptionTokens.statusGreenText,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
          const SizedBox(width: 6),
          Image.asset(RAssets.attendedIcon, width: 16, height: 16, fit: BoxFit.contain),
        ],
      ),
    );
  }

  /// Figma: 136×46 hug, pad 12, gap 6, r16, fill #FFE330 @ 40%
  Widget _pendingPill() {
    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: ReceptionTokens.statusYellowBg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'لم يحضر بعد',
            style: TextStyle(
              color: ReceptionTokens.statusYellowText,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
          const SizedBox(width: 6),
          Image.asset(RAssets.pendingIcon, width: 18, height: 18, fit: BoxFit.contain),
        ],
      ),
    );
  }
}

class _Th extends StatelessWidget {
  const _Th(this.t);
  final String t;

  @override
  Widget build(BuildContext context) {
    return Text(
      t,
      textAlign: TextAlign.center,
      style: const TextStyle(
        color: ReceptionTokens.navy,
        fontWeight: FontWeight.w700,
        fontSize: 14,
      ),
    );
  }
}

class _BookingsPagination extends StatelessWidget {
  const _BookingsPagination({
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
    const window = 8;
    final startPage = pageCount <= window
        ? 0
        : (page - window ~/ 2).clamp(0, pageCount - window);
    final pages = List.generate(
      pageCount.clamp(1, window),
      (i) => startPage + i,
    );

    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: ReceptionTokens.softShadow,
        ),
        child: Row(
          children: [
            Text(
              total == 0
                  ? 'لا توجد حجوزات'
                  : 'عرض $from - $to من $total حجز',
              style: GoogleFonts.cairo(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: ReceptionTokens.navy,
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
                      color: active
                          ? ReceptionTokens.confirmBlue
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${p + 1}',
                      style: GoogleFonts.cairo(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        color: active ? Colors.white : ReceptionTokens.navy,
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
