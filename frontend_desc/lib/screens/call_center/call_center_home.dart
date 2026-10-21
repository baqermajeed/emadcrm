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
import '../../core/reception_tokens.dart';
import '../../models/booking.dart';
import '../../utils/enums.dart';
import '../../utils/formatters.dart';
import '../../widgets/reception/reception_assets.dart';
import '../../widgets/reception/reception_search_bar.dart';
import 'create_booking_screen.dart';

class CallCenterHome extends StatefulWidget {
  const CallCenterHome({super.key});

  @override
  State<CallCenterHome> createState() => _CallCenterHomeState();
}

class _CallCenterHomeState extends State<CallCenterHome> {
  static const _ink = Color(0xFF123B70);

  final _search = TextEditingController();
  BookingStatus? _statusFilter;
  DateTime? _fromDate;
  DateTime? _toDate;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BookingController>().load();
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<Booking> _filtered(List<Booking> items) {
    final q = _search.text.trim().toLowerCase();
    return items.where((b) {
      if (_statusFilter != null) {
        // «لم يحضر» includes cancelled + no-show.
        if (_statusFilter == BookingStatus.noShow) {
          if (b.status != BookingStatus.noShow &&
              b.status != BookingStatus.cancelled) {
            return false;
          }
        } else if (b.status != _statusFilter) {
          return false;
        }
      }
      final visit = b.visitDate.toLocal();
      if (_fromDate != null) {
        final from =
            DateTime(_fromDate!.year, _fromDate!.month, _fromDate!.day);
        if (visit.isBefore(from)) return false;
      }
      if (_toDate != null) {
        final to = DateTime(
            _toDate!.year, _toDate!.month, _toDate!.day, 23, 59, 59);
        if (visit.isAfter(to)) return false;
      }
      if (q.isEmpty) return true;
      return b.name.toLowerCase().contains(q) ||
          b.phone.contains(q) ||
          b.governorate.toLowerCase().contains(q) ||
          b.source.label.contains(q) ||
          (b.notes?.toLowerCase().contains(q) ?? false);
    }).toList();
  }

  Future<void> _pickDate({required bool from}) async {
    final initial =
        from ? (_fromDate ?? DateTime.now()) : (_toDate ?? DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: ReceptionTokens.teal,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: ReceptionTokens.navy,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked == null) return;
    setState(() {
      if (from) {
        _fromDate = picked;
        if (_toDate != null && _toDate!.isBefore(picked)) _toDate = picked;
      } else {
        _toDate = picked;
        if (_fromDate != null && _fromDate!.isAfter(picked)) {
          _fromDate = picked;
        }
      }
    });
  }

  void _clearDates() => setState(() {
        _fromDate = null;
        _toDate = null;
      });

  Future<void> _openCreate() async {
    final created = await CreateBookingScreen.show(context);
    if (created == true && mounted) {
      await context.read<BookingController>().load();
    }
  }

  Future<void> _openWhatsApp(String phone) async {
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

    if (!opened && !kIsWeb && Platform.isWindows) {
      try {
        await Process.start('cmd', ['/c', 'start', '', url], runInShell: true);
        opened = true;
      } catch (_) {
        opened = false;
      }
    }

    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر فتح واتساب')),
      );
    }
  }

  Future<void> _callPhone(String phone) async {
    final digits = phone.replaceAll(RegExp(r'[^\d+]'), '');
    final uri = Uri.parse('tel:$digits');
    try {
      await launchUrl(uri);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر فتح الاتصال')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<BookingController>();
    final user = context.watch<AuthController>().user;
    final items = _filtered(ctrl.items);

    final total = ctrl.items.length;
    final pending =
        ctrl.items.where((b) => b.status == BookingStatus.pending).length;
    final attended =
        ctrl.items.where((b) => b.status == BookingStatus.approved).length;
    final missed = ctrl.items
        .where((b) =>
            b.status == BookingStatus.cancelled ||
            b.status == BookingStatus.noShow)
        .length;

    // Layout follows reception: sidebar on the right (LTR shell).
    return Directionality(
      textDirection: ui.TextDirection.ltr,
      child: Scaffold(
        backgroundColor: ReceptionTokens.bg,
        floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
        floatingActionButton: _NewBookingFab(onTap: _openCreate),
        body: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Directionality(
                textDirection: ui.TextDirection.rtl,
                child: SafeArea(
                  child: Column(
                    children: [
                      _Header(
                        userName: displayUserName(user),
                        search: _search,
                        suggestions: ReceptionSearchBar.uniqueOf([
                          for (final b in ctrl.items)
                            ...[b.name, b.phone, b.governorate, b.source.label],
                        ]),
                        onSearch: () => setState(() {}),
                        onQueryChanged: (_) => setState(() {}),
                        onLogout: () =>
                            context.read<AuthController>().logout(),
                      ),
                      Expanded(
                        child: RefreshIndicator(
                          color: ReceptionTokens.teal,
                          onRefresh: () =>
                              context.read<BookingController>().load(),
                          child: CustomScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            slivers: [
                              SliverPadding(
                                padding:
                                    const EdgeInsets.fromLTRB(20, 12, 20, 0),
                                sliver: SliverToBoxAdapter(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      _StatsRow(
                                        total: total,
                                        pending: pending,
                                        attended: attended,
                                        missed: missed,
                                        loading: ctrl.loading &&
                                            ctrl.items.isEmpty,
                                      ),
                                      const SizedBox(height: 14),
                                      _FiltersRow(
                                        selected: _statusFilter,
                                        onStatus: (v) => setState(
                                            () => _statusFilter = v),
                                        fromDate: _fromDate,
                                        toDate: _toDate,
                                        onPickFrom: () =>
                                            _pickDate(from: true),
                                        onPickTo: () =>
                                            _pickDate(from: false),
                                        onClearDates: _clearDates,
                                      ),
                                      const SizedBox(height: 14),
                                      Row(
                                        children: [
                                          Text(
                                            'قائمة الحجوزات',
                                            style: GoogleFonts.cairo(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w800,
                                              color: _ink,
                                            ),
                                          ),
                                          const Spacer(),
                                          Text(
                                            '${items.length} حجز',
                                            style: GoogleFonts.cairo(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              color: ReceptionTokens.navy
                                                  .withValues(alpha: 0.55),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                    ],
                                  ),
                                ),
                              ),
                              if (ctrl.loading && ctrl.items.isEmpty)
                                const SliverFillRemaining(
                                  hasScrollBody: false,
                                  child: Center(
                                    child: CircularProgressIndicator(
                                      color: ReceptionTokens.teal,
                                    ),
                                  ),
                                )
                              else if (items.isEmpty)
                                SliverFillRemaining(
                                  hasScrollBody: false,
                                  child:
                                      _EmptyBookings(onCreate: _openCreate),
                                )
                              else
                                SliverPadding(
                                  padding: const EdgeInsets.fromLTRB(
                                      20, 0, 20, 100),
                                  sliver: SliverToBoxAdapter(
                                    child: _BookingsTable(
                                      rows: items,
                                      onCall: _callPhone,
                                      onWhatsApp: _openWhatsApp,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const _Sidebar(),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────── Sidebar 266px ─────────────────────────

class _Sidebar extends StatelessWidget {
  const _Sidebar();

  static const _logo =
      'asset/Premium Gold and Teal Real Estate Emblem.png';
  @override
  Widget build(BuildContext context) {
    const radius = BorderRadius.only(
      topLeft: Radius.circular(24),
      bottomLeft: Radius.circular(24),
    );
    return ClipRRect(
      borderRadius: radius,
      child: SizedBox(
        width: ReceptionTokens.sidebarWidth,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const DecoratedBox(
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: AssetImage(RAssets.callCenterSidebar),
                  fit: BoxFit.cover,
                  alignment: Alignment.centerRight,
                  filterQuality: FilterQuality.high,
                ),
              ),
            ),
            // Soft frosted veil ~10% over the photo.
            BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 2.5, sigmaY: 2.5),
              child: Container(
                color: Colors.white.withValues(alpha: 0.10),
              ),
            ),
            Positioned(
              top: 36,
              left: 16,
              right: 16,
              child: Column(
                children: [
                  // Drop-shadow only (no filled circle) so the logo looks raised.
                  SizedBox(
                    width: 150,
                    height: 150,
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
                                  width: 150,
                                  height: 150,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Image.asset(
                          _logo,
                          width: 150,
                          height: 150,
                          fit: BoxFit.contain,
                          filterQuality: FilterQuality.high,
                        ),
                      ],
                    ),
                  ),
                  Transform.translate(
                    offset: const Offset(0, -18),
                    child: Column(
                      children: [
                        Text(
                          'عماد سكر',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.cairo(
                            fontSize: 24,
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
                          'نظام ادارة مبيعات المجمعات ',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.cairo(
                            fontSize: 12,
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────── Header (matches reception) ─────────────────────────

class _Header extends StatelessWidget {
  const _Header({
    required this.userName,
    required this.search,
    required this.suggestions,
    required this.onSearch,
    required this.onQueryChanged,
    required this.onLogout,
  });

  final String userName;
  final TextEditingController search;
  final List<String> suggestions;
  final VoidCallback onSearch;
  final ValueChanged<String> onQueryChanged;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    // Same LTR header layout as reception (bell → profile → search → title).
    return Directionality(
      textDirection: ui.TextDirection.ltr,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(30, 20, 24, 8),
        child: Row(
          children: [
            _card(
              height: 58,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Center(child: RAssets.svg('dc_bell', w: 24, h: 24)),
            ),
            const SizedBox(width: 10),
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
                          'موظف الكول سنتر',
                          style: TextStyle(
                            color:
                                ReceptionTokens.navy.withValues(alpha: 0.7),
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 6),
                    RAssets.svg('dc_chevron', w: 12, h: 12),
                    const SizedBox(width: 8),
                    ClipOval(
                      child: Image.asset(
                        RAssets.avatar,
                        width: 44,
                        height: 44,
                        fit: BoxFit.cover,
                      ),
                    ),
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
            Row(
              children: [
                Text(
                  'الكول سنتر',
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

  Widget _card({
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
    required this.total,
    required this.pending,
    required this.attended,
    required this.missed,
    required this.loading,
  });

  final int total;
  final int pending;
  final int attended;
  final int missed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            label: 'الإجمالي',
            value: loading ? '—' : '$total',
            accent: const Color(0xFF1E6FD9),
            iconBg: const Color(0xFFDBEAFE),
            icon: Icons.calendar_month_rounded,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            label: 'بانتظار',
            value: loading ? '—' : '$pending',
            accent: const Color(0xFFEA580C),
            iconBg: const Color(0xFFFFEDD5),
            icon: Icons.schedule_rounded,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            label: 'تم الحضور',
            value: loading ? '—' : '$attended',
            accent: const Color(0xFF059669),
            iconBg: const Color(0xFFD1FAE5),
            icon: Icons.check_circle_rounded,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            label: 'ملغي / غائب',
            value: loading ? '—' : '$missed',
            accent: const Color(0xFFDC2626),
            iconBg: const Color(0xFFFEE2E2),
            icon: Icons.cancel_rounded,
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
    required this.accent,
    required this.iconBg,
    required this.icon,
  });

  final String label;
  final String value;
  final Color accent;
  final Color iconBg;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 78,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.22), width: 0.5),
        boxShadow: ReceptionTokens.cardShadow,
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
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: accent.withValues(alpha: 0.85),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: GoogleFonts.cairo(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: accent,
                    height: 1,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
            child: Icon(icon, size: 18, color: accent),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────── Search / filters ─────────────────────────

class _FiltersRow extends StatelessWidget {
  const _FiltersRow({
    required this.selected,
    required this.onStatus,
    required this.fromDate,
    required this.toDate,
    required this.onPickFrom,
    required this.onPickTo,
    required this.onClearDates,
  });

  final BookingStatus? selected;
  final ValueChanged<BookingStatus?> onStatus;
  final DateTime? fromDate;
  final DateTime? toDate;
  final VoidCallback onPickFrom;
  final VoidCallback onPickTo;
  final VoidCallback onClearDates;

  @override
  Widget build(BuildContext context) {
    final chips = <(BookingStatus?, String)>[
      (null, 'الكل'),
      (BookingStatus.approved, 'تم الحضور'),
      (BookingStatus.pending, 'لم يحضر بعد'),
      (BookingStatus.noShow, 'لم يحضر'),
    ];
    final hasRange = fromDate != null || toDate != null;

    return SizedBox(
      height: 44,
      child: Row(
        children: [
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: chips.length,
              separatorBuilder: (context, index) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final (status, label) = chips[i];
                final active = selected == status;
                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => onStatus(status),
                    borderRadius: BorderRadius.circular(10),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        gradient: active
                            ? const LinearGradient(
                                colors: [
                                  ReceptionTokens.teal,
                                  Color(0xFF0178BE),
                                ],
                              )
                            : null,
                        color: active ? null : Colors.white,
                        border: Border.all(
                          color: active
                              ? Colors.transparent
                              : ReceptionTokens.fieldBorder,
                          width: 0.5,
                        ),
                        boxShadow:
                            active ? ReceptionTokens.softShadow : null,
                      ),
                      child: Text(
                        label,
                        style: GoogleFonts.cairo(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: active
                              ? Colors.white
                              : const Color(0xFF123B70),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 10),
          _dateChip(
            label: 'من تاريخ',
            value: fromDate,
            onTap: onPickFrom,
            width: 148,
          ),
          const SizedBox(width: 8),
          _dateChip(
            label: 'إلى تاريخ',
            value: toDate,
            onTap: onPickTo,
            width: 148,
          ),
          if (hasRange) ...[
            const SizedBox(width: 8),
            Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              child: InkWell(
                onTap: onClearDates,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: ReceptionTokens.fieldBorder,
                      width: 0.5,
                    ),
                  ),
                  child: Text(
                    'مسح',
                    style: GoogleFonts.cairo(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFFDC2626),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _dateChip({
    required String label,
    required DateTime? value,
    required VoidCallback onTap,
    required double width,
  }) {
    return SizedBox(
      width: width,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: ReceptionTokens.fieldBorder,
                width: 0.5,
              ),
              boxShadow: ReceptionTokens.softShadow,
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.calendar_today_outlined,
                  size: 15,
                  color: ReceptionTokens.teal,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    value == null
                        ? label
                        : DateFormat('dd/MM/yyyy').format(value),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.cairo(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: value == null
                          ? ReceptionTokens.navy.withValues(alpha: 0.45)
                          : const Color(0xFF123B70),
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

// ───────────────────────── Bookings table ─────────────────────────

class _BookingsTable extends StatelessWidget {
  const _BookingsTable({
    required this.rows,
    required this.onCall,
    required this.onWhatsApp,
  });

  final List<Booking> rows;
  final Future<void> Function(String phone) onCall;
  final Future<void> Function(String phone) onWhatsApp;

  static const _tableText = Color(0xFF123B70);
  static const _colGap = 14.0;
  static const _rowH = 52.0;
  static const _minW = 1360.0;
  static const _hPad = 24.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width =
            constraints.maxWidth < _minW ? _minW : constraints.maxWidth;
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: width,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _headerBar(),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: ReceptionTokens.cardShadow,
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      for (var i = 0; i < rows.length; i++)
                        _dataRow(rows[i], i + 1, i.isOdd),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Figma: fill #069BAF, r16, pad 24×69, h hug (~64).
  Widget _headerBar() {
    final style = GoogleFonts.cairo(
      fontWeight: FontWeight.w800,
      fontSize: 12,
      color: Colors.white,
    );
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 64),
      padding: const EdgeInsets.symmetric(horizontal: _hPad, vertical: 18),
      decoration: BoxDecoration(
        color: ReceptionTokens.teal,
        borderRadius: BorderRadius.circular(16),
        boxShadow: ReceptionTokens.cardShadow,
      ),
      alignment: Alignment.center,
      child: _cols([
        _fixed(40, Text('#', style: style, textAlign: TextAlign.center)),
        _fixed(78, Text('الوقت', style: style, textAlign: TextAlign.center)),
        _fixed(
            100, Text('تاريخ الزيارة', style: style, textAlign: TextAlign.center)),
        _flex(2, Text('اسم الزبون', style: style)),
        _fixed(
            120, Text('رقم الهاتف', style: style, textAlign: TextAlign.center)),
        _flex(1, Text('المحافظة', style: style)),
        _fixed(110, Text('المصدر', style: style, textAlign: TextAlign.center)),
        _fixed(120, Text('الحالة', style: style, textAlign: TextAlign.center)),
        _flex(2, Text('موظف الكول سنتر', style: style)),
        _flex(1, Text('ملاحظات', style: style)),
        _fixed(90, Text('الإجراءات', style: style, textAlign: TextAlign.center)),
      ]),
    );
  }

  Widget _dataRow(Booking b, int index, bool alt) {
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
    final (bg, fg) = _statusColors(b.status);

    return Container(
      height: _rowH,
      padding: const EdgeInsets.symmetric(horizontal: _hPad),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: alt ? const Color(0xFFF7FBFC) : Colors.white,
        border: const Border(bottom: BorderSide(color: Color(0xFFEEF2F6))),
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
        _fixed(78, Text(time, textAlign: TextAlign.center, style: muted)),
        _fixed(100, Text(date, textAlign: TextAlign.center, style: style)),
        _flex(
          2,
          Row(
            children: [
              const CircleAvatar(
                radius: 15,
                backgroundColor: Color(0xFFE8F0FE),
                backgroundImage: AssetImage(RAssets.avatarMale),
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
          120,
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
        _fixed(
          110,
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              RAssets.source(b.source.api, size: 24),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  b.source.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: style,
                ),
              ),
            ],
          ),
        ),
        _fixed(
          120,
          Center(
            child: _GlassShimmerChip(
              bg: bg,
              fg: fg,
              label: _statusLabel(b.status),
            ),
          ),
        ),
        _flex(
          2,
          Row(
            children: [
              const CircleAvatar(
                radius: 15,
                backgroundColor: Color(0xFFE8F0FE),
                backgroundImage: AssetImage(RAssets.avatarMale),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  (b.callCenterName ?? '').trim().isEmpty
                      ? '—'
                      : b.callCenterName!.trim(),
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
            (b.notes ?? '').trim().isEmpty ? '—' : b.notes!.trim(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: muted,
          ),
        ),
        _fixed(
          90,
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _GlassActionBtn(
                onTap: () => onCall(b.phone),
                bg: const Color(0xFFEFF6FF),
                fg: const Color(0xFF1E6FD9),
                child: RAssets.profileIcon(RAssets.callPhoneIcon, size: 16),
              ),
              const SizedBox(width: 4),
              _GlassActionBtn(
                onTap: () => onWhatsApp(b.phone),
                bg: const Color(0xFFE8F8EF),
                fg: const Color(0xFF059669),
                child: RAssets.source('whatsapp', size: 16),
              ),
            ],
          ),
        ),
      ]),
    );
  }

  String _statusLabel(BookingStatus s) => switch (s) {
        BookingStatus.approved => 'تم الحضور',
        BookingStatus.pending => 'لم يحضر بعد',
        BookingStatus.cancelled || BookingStatus.noShow => 'لم يحضر',
      };

  (Color bg, Color fg) _statusColors(BookingStatus s) => switch (s) {
        BookingStatus.pending => (
            ReceptionTokens.statusYellowBg,
            const Color(0xFFB45309),
          ),
        BookingStatus.approved => (
            ReceptionTokens.statusGreenBg,
            ReceptionTokens.statusGreenText,
          ),
        BookingStatus.cancelled => (
            const Color(0xFFFECACA),
            const Color(0xFFB91C1C),
          ),
        BookingStatus.noShow => (
            const Color(0xFFE5E7EB),
            const Color(0xFF4B5563),
          ),
      };

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

  Widget _fixed(double width, Widget child) =>
      SizedBox(width: width, child: child);

  Widget _flex(int flex, Widget child) => Expanded(flex: flex, child: child);
}

// ───────────────────────── Empty / FAB ─────────────────────────

class _EmptyBookings extends StatelessWidget {
  const _EmptyBookings({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: ReceptionTokens.plusBg,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.event_note_rounded,
                size: 36,
                color: ReceptionTokens.teal,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'لا توجد حجوزات بعد',
              style: GoogleFonts.cairo(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF123B70),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'أضف أول حجز من زر «حجز جديد»',
              style: GoogleFonts.cairo(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: ReceptionTokens.navy.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 18),
            TextButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add_rounded),
              label: const Text('حجز جديد'),
              style: TextButton.styleFrom(
                foregroundColor: ReceptionTokens.teal,
                textStyle: GoogleFonts.cairo(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NewBookingFab extends StatelessWidget {
  const _NewBookingFab({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [ReceptionTokens.teal, ReceptionTokens.confirmBlue],
            ),
            boxShadow: [
              BoxShadow(
                color: ReceptionTokens.teal.withValues(alpha: 0.35),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.add_rounded, color: Colors.white, size: 22),
                const SizedBox(width: 8),
                Text(
                  'حجز جديد',
                  style: GoogleFonts.cairo(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
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

// ───────────────────────── Glass widgets ─────────────────────────

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
    const size = 34.0;
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
  });

  final Color bg;
  final Color fg;
  final String label;

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
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
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
                ),
                child: child,
              ),
            ),
          ),
        );
      },
      child: Text(
        widget.label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.cairo(
          fontWeight: FontWeight.w800,
          fontSize: 10,
          color: widget.fg,
        ),
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
