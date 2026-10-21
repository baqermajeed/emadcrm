import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../controllers/booking_controller.dart';
import '../../controllers/customer_controller.dart';
import '../../core/api_client.dart';
import '../../core/reception_tokens.dart';
import '../../models/booking.dart';
import '../../models/customer.dart';
import '../../models/user.dart';
import '../../services/user_service.dart';
import '../../utils/enums.dart';
import '../../widgets/reception/reception_assets.dart';

enum ApproveDialogResult { cancelled, confirmed, confirmedAndOpen, viewProfile }

class ApproveDialogOutcome {
  const ApproveDialogOutcome(this.result, {this.customerId});
  final ApproveDialogResult result;
  final String? customerId;
}

Future<ApproveDialogOutcome?> showApproveBookingDialog(
  BuildContext context,
  Booking booking, {
  List<AppUser> sales = const [],
}) {
  return showGeneralDialog<ApproveDialogOutcome>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'إغلاق',
    barrierColor: Colors.black.withValues(alpha: 0.55),
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (ctx, anim, _) => ApproveBookingDialog(
      booking: booking,
      initialSales: sales,
    ),
    transitionBuilder: (ctx, anim, _, child) {
      final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.96, end: 1).animate(curved),
          child: child,
        ),
      );
    },
  );
}

class ApproveBookingDialog extends StatefulWidget {
  const ApproveBookingDialog({
    super.key,
    required this.booking,
    this.initialSales = const [],
  });

  final Booking booking;
  final List<AppUser> initialSales;

  @override
  State<ApproveBookingDialog> createState() => _ApproveBookingDialogState();
}

class _ApproveBookingDialogState extends State<ApproveBookingDialog> {
  final _notes = TextEditingController();

  late List<AppUser> _sales;
  String? _salesId;
  DateTime _attendAt = DateTime.now();
  bool _loadingUsers = true;
  bool _saving = false;
  Customer? _existingCustomer;

  @override
  void initState() {
    super.initState();
    _sales = List<AppUser>.from(widget.initialSales);
    if (_sales.isNotEmpty) {
      _salesId = _sales.first.id;
      _loadingUsers = false;
    }
    final visit = widget.booking.visitDate.toLocal();
    _attendAt = DateTime(
      visit.year,
      visit.month,
      visit.day,
      DateTime.now().hour,
      DateTime.now().minute,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _resolveCustomer();
      _loadSales();
    });
  }

  void _resolveCustomer() {
    final customers = context.read<CustomerController>().items;
    final b = widget.booking;
    Customer? found;
    if (b.customerId != null) {
      for (final c in customers) {
        if (c.id == b.customerId) {
          found = c;
          break;
        }
      }
    }
    if (found == null) {
      for (final c in customers) {
        if (c.phone == b.phone) {
          found = c;
          break;
        }
      }
    }
    if (mounted) setState(() => _existingCustomer = found);
  }

  Future<void> _loadSales() async {
    try {
      final api = context.read<ApiClient>();
      final list = await UserService(api).list(role: UserRole.sales);
      if (!mounted) return;
      setState(() {
        _sales = list;
        if (_sales.isNotEmpty) {
          final ok = _sales.any((u) => u.id == _salesId);
          _salesId = ok ? _salesId : _sales.first.id;
        }
        _loadingUsers = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingUsers = false);
    }
  }

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _attendAt,
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: ReceptionTokens.navy,
            onPrimary: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (d == null) return;
    setState(() {
      _attendAt = DateTime(d.year, d.month, d.day, _attendAt.hour, _attendAt.minute);
    });
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_attendAt),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: ReceptionTokens.navy,
            onPrimary: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (t == null) return;
    setState(() {
      _attendAt = DateTime(
        _attendAt.year,
        _attendAt.month,
        _attendAt.day,
        t.hour,
        t.minute,
      );
    });
  }

  Future<void> _submit({required bool openProfile}) async {
    if (_salesId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اختر موظف المبيعات')),
      );
      return;
    }
    setState(() => _saving = true);
    final stamp = DateFormat('yyyy/MM/dd HH:mm').format(_attendAt);
    final noteParts = <String>[
      if (_notes.text.trim().isNotEmpty) _notes.text.trim(),
      'وقت الحضور الفعلي: $stamp',
    ];
    final ok = await context.read<BookingController>().approve(
          bookingId: widget.booking.id,
          salesEmployeeId: _salesId!,
          notes: noteParts.join('\n'),
        );
    setState(() => _saving = false);
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.read<BookingController>().error ?? 'فشلت الموافقة')),
      );
      return;
    }
    Navigator.pop(
      context,
      ApproveDialogOutcome(
        openProfile ? ApproveDialogResult.confirmedAndOpen : ApproveDialogResult.confirmed,
        customerId: _existingCustomer?.id ?? widget.booking.customerId,
      ),
    );
  }

  void _openExistingProfile() {
    final id = _existingCustomer?.id ?? widget.booking.customerId;
    if (id == null) return;
    Navigator.pop(context, ApproveDialogOutcome(ApproveDialogResult.viewProfile, customerId: id));
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.booking;
    final visit = b.visitDate.toLocal();
    final dateStr = DateFormat('EEEE dd/MM/yyyy', 'ar').format(visit);
    final timeStr = DateFormat('hh:mm a', 'ar').format(visit);
    final attendDate = DateFormat('dd/MM/yyyy').format(_attendAt);
    final attendTime = DateFormat('HH:mm').format(_attendAt);
    final hasFile = _existingCustomer != null || b.customerId != null;
    final bookingCode = '# HB-${b.id.length >= 5 ? b.id.substring(b.id.length - 5).toUpperCase() : b.id.toUpperCase()}';

    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Center(
        child: Material(
          color: Colors.transparent,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 820,
              maxHeight: MediaQuery.sizeOf(context).height * 0.94 - 60,
            ),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: ReceptionTokens.bg,
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: ReceptionTokens.navy.withValues(alpha: 0.25),
                    blurRadius: 36,
                    offset: const Offset(0, 14),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: Column(
                  children: [
                    _header(),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(22, 8, 22, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _bookingInfoPanel(
                              b: b,
                              bookingCode: bookingCode,
                              dateStr: dateStr,
                              timeStr: timeStr,
                            ),
                            const SizedBox(height: 16),
                            _customerStatusPanel(hasFile),
                            const SizedBox(height: 16),
                            IntrinsicHeight(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Expanded(flex: 5, child: _salesPanel()),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    flex: 4,
                                    child: _attendanceTimePanel(
                                      attendDate: attendDate,
                                      attendTime: attendTime,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            _visitNotesPanel(),
                          ],
                        ),
                      ),
                    ),
                    _footer(hasFile: hasFile),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _header() {
    // RTL: icon + title on the right (icon before text), close on the left
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: ReceptionTokens.cardShadow,
            ),
            child: const Icon(Icons.how_to_reg_rounded, color: ReceptionTokens.navy, size: 26),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'تسجيل الحضور',
                textAlign: TextAlign.right,
                style: TextStyle(
                  color: ReceptionTokens.navy,
                  fontWeight: FontWeight.w900,
                  fontSize: 21,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'تأكيد حضور الزبون وإنشاء سجل الزيارة',
                textAlign: TextAlign.right,
                style: TextStyle(
                  color: ReceptionTokens.navy.withValues(alpha: 0.78),
                  fontWeight: FontWeight.w700,
                  fontSize: 12.5,
                ),
              ),
            ],
          ),
          const Spacer(),
          IconButton(
            onPressed: () => Navigator.pop(context, const ApproveDialogOutcome(ApproveDialogResult.cancelled)),
            style: IconButton.styleFrom(
              backgroundColor: ReceptionTokens.rowAlt,
              shape: const CircleBorder(),
            ),
            icon: const Icon(Icons.close, color: ReceptionTokens.navy, size: 20),
          ),
        ],
      ),
    );
  }

  static final _tileBorder = Border.all(
    color: ReceptionTokens.navy.withValues(alpha: 0.5),
    width: 0.5,
  );

  Widget _infoTile({required Widget child, int flex = 1}) {
    return Expanded(
      flex: flex,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: _tileBorder,
        ),
        child: child,
      ),
    );
  }

  /// Layout: icon → title → info (vertical)
  Widget _infoBlock({
    required Widget icon,
    required String title,
    required List<Widget> info,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        icon,
        const SizedBox(height: 8),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: ReceptionTokens.navy,
            fontWeight: FontWeight.w800,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 10),
        ...info,
      ],
    );
  }

  Widget _assetIcon(String path, {double size = 28}) {
    return Image.asset(path, width: size, height: size, fit: BoxFit.contain);
  }

  Widget _infoText(String text, {bool link = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: link ? ReceptionTokens.linkBlue : ReceptionTokens.navy,
          fontWeight: FontWeight.w700,
          fontSize: 13,
          decoration: link ? TextDecoration.underline : null,
          decorationColor: ReceptionTokens.linkBlue,
        ),
      ),
    );
  }

  /// Outer white panel + colored header + inner info tiles (matches design)
  Widget _bookingInfoPanel({
    required Booking b,
    required String bookingCode,
    required String dateStr,
    required String timeStr,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: _tileBorder,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            color: const Color(0xFFE7F5F7),
            child: const Row(
              children: [
                Icon(Icons.calendar_month_outlined, size: 18, color: ReceptionTokens.navy),
                SizedBox(width: 8),
                Text(
                  'معلومات الحجز',
                  style: TextStyle(
                    color: ReceptionTokens.navy,
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Patient — no nested box (like design)
                  Expanded(
                    flex: 14,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 22,
                                backgroundColor: ReceptionTokens.plusBg,
                                child: Icon(
                                  Icons.person_rounded,
                                  color: ReceptionTokens.navy.withValues(alpha: 0.85),
                                  size: 26,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      b.name,
                                      style: const TextStyle(
                                        color: ReceptionTokens.navy,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 15,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: ReceptionTokens.rowAlt,
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        bookingCode,
                                        style: TextStyle(
                                          color: ReceptionTokens.navy.withValues(alpha: 0.7),
                                          fontWeight: FontWeight.w700,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Icon(Icons.phone, size: 20, color: ReceptionTokens.navy.withValues(alpha: 0.8)),
                              const SizedBox(width: 8),
                              Text(
                                b.phone,
                                style: const TextStyle(
                                  color: ReceptionTokens.linkBlue,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  decoration: TextDecoration.underline,
                                  decorationColor: ReceptionTokens.linkBlue,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(Icons.location_on, size: 20, color: ReceptionTokens.navy.withValues(alpha: 0.8)),
                              const SizedBox(width: 8),
                              Text(
                                b.governorate,
                                style: const TextStyle(
                                  color: ReceptionTokens.navy,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  _infoTile(
                    flex: 11,
                    child: _infoBlock(
                      icon: _assetIcon(RAssets.bookingDateIcon),
                      title: 'موعد الحجز',
                      info: [
                        _infoText(dateStr),
                        _infoText(timeStr),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  _infoTile(
                    flex: 10,
                    child: _infoBlock(
                      icon: _assetIcon(RAssets.bookingSourceIcon),
                      title: 'مصدر الحجز',
                      info: [
                        const SizedBox(height: 2),
                        RAssets.source(b.source.api, size: 28),
                        const SizedBox(height: 6),
                        _infoText(b.source.label),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  _infoTile(
                    flex: 12,
                    child: _infoBlock(
                      icon: _assetIcon(RAssets.bookingNotesIcon),
                      title: 'ملاحظات الحجز',
                      info: [
                        _infoText(
                          (b.notes == null || b.notes!.trim().isEmpty)
                              ? 'لا توجد ملاحظات'
                              : b.notes!.trim(),
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
    );
  }

  /// Green when prior file exists, red when creating new — separate title + status
  Widget _customerStatusPanel(bool hasFile) {
    const greenHeader = Color(0xFFDCEFE8);
    const greenBody = Color(0xFFEAF7F1);
    const greenAccent = Color(0xFF00661B);
    const redHeader = Color(0xFFF8E0E0);
    const redBody = Color(0xFFFDF0F0);
    const redAccent = Color(0xFFB00020);

    final headerBg = hasFile ? greenHeader : redHeader;
    final bodyBg = hasFile ? greenBody : redBody;
    final accent = hasFile ? greenAccent : redAccent;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: headerBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
          ),
          child: Row(
            children: [
              Icon(Icons.person_outline, size: 18, color: accent),
              const SizedBox(width: 8),
              Text(
                'حالة ملف الزبون',
                style: TextStyle(
                  color: accent,
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: bodyBg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: accent,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  hasFile ? Icons.check_rounded : Icons.close_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasFile
                          ? 'يوجد ملف مسبق لهذا الزبون'
                          : 'لا يوجد ملف مسبق لهذا الزبون',
                      style: TextStyle(
                        color: accent,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      hasFile
                          ? 'سيتم إضافة الزيارة إلى الملف الحالي'
                          : 'سيتم إنشاء ملف زبون جديد عند تأكيد الحضور',
                      style: TextStyle(
                        color: accent.withValues(alpha: 0.75),
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (hasFile) ...[
                const SizedBox(width: 10),
                InkWell(
                  onTap: _openExistingProfile,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE7F5F7),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image.asset(RAssets.viewProfileIcon, width: 18, height: 14),
                        const SizedBox(width: 6),
                        Text(
                          'عرض ملف الزبون',
                          style: TextStyle(
                            color: accent,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _panelShell({
    required Widget header,
    required Widget body,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: _tileBorder,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          header,
          Padding(padding: const EdgeInsets.fromLTRB(12, 10, 12, 10), child: body),
        ],
      ),
    );
  }

  Widget _panelHeader({
    required IconData icon,
    required String title,
    bool iconInCircle = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: const Color(0xFFE7F5F7),
      child: Row(
        children: [
          if (iconInCircle)
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: ReceptionTokens.navy.withValues(alpha: 0.35)),
              ),
              child: Icon(icon, size: 15, color: ReceptionTokens.navy),
            )
          else
            Icon(icon, size: 18, color: ReceptionTokens.navy),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              color: ReceptionTokens.navy,
              fontWeight: FontWeight.w900,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _salesPanel() {
    return _panelShell(
      header: _panelHeader(icon: Icons.groups_outlined, title: 'تعيين موظف المبيعات'),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'اختر موظف المبيعات',
            style: TextStyle(
              color: ReceptionTokens.navy.withValues(alpha: 0.55),
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 6),
          if (_loadingUsers)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: ReceptionTokens.teal),
                ),
              ),
            )
          else
            Container(
              height: 42,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: ReceptionTokens.fieldBorder),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _salesId,
                  isExpanded: true,
                  hint: Text(
                    'اختر موظف المبيعات',
                    style: TextStyle(
                      color: ReceptionTokens.navy.withValues(alpha: 0.5),
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  icon: const Icon(Icons.keyboard_arrow_down_rounded, color: ReceptionTokens.navy, size: 20),
                  dropdownColor: Colors.white,
                  items: _sales
                      .map(
                        (u) => DropdownMenuItem(
                          value: u.id,
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 12,
                                backgroundColor: ReceptionTokens.plusBg,
                                child: Text(
                                  u.fullName.isNotEmpty ? u.fullName.substring(0, 1) : '?',
                                  style: const TextStyle(
                                    color: ReceptionTokens.navy,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  u.fullName,
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
                      )
                      .toList(),
                  onChanged: _sales.isEmpty ? null : (v) => setState(() => _salesId = v),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _attendanceTimePanel({
    required String attendDate,
    required String attendTime,
  }) {
    return _panelShell(
      header: _panelHeader(
        icon: Icons.access_time,
        title: 'وقت الحضور الفعلي',
        iconInCircle: true,
      ),
      body: Row(
        children: [
          Expanded(
            child: _pickerField(
              value: attendDate,
              icon: Icons.calendar_today_outlined,
              onTap: _pickDate,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _pickerField(
              value: attendTime,
              icon: Icons.schedule,
              onTap: _pickTime,
            ),
          ),
        ],
      ),
    );
  }

  Widget _pickerField({
    required String value,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: ReceptionTokens.fieldBorder),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: ReceptionTokens.navy.withValues(alpha: 0.65)),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                value,
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
    );
  }

  Widget _visitNotesPanel() {
    final len = _notes.text.length;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: _tileBorder,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            color: const Color(0xFFE7F5F7),
            child: const Row(
              children: [
                Icon(Icons.description_outlined, size: 18, color: ReceptionTokens.navy),
                SizedBox(width: 8),
                Text(
                  'ملاحظات الزيارة',
                  style: TextStyle(
                    color: ReceptionTokens.navy,
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
            child: Column(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: ReceptionTokens.fieldBorder),
                  ),
                  child: TextField(
                    controller: _notes,
                    maxLines: 4,
                    maxLength: 500,
                    textAlign: TextAlign.right,
                    onChanged: (_) => setState(() {}),
                    style: const TextStyle(
                      color: ReceptionTokens.navy,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                    decoration: InputDecoration(
                      counterText: '',
                      hintText: 'أضف أي ملاحظات حول الزيارة .....',
                      hintStyle: TextStyle(
                        color: ReceptionTokens.navy.withValues(alpha: 0.4),
                        fontWeight: FontWeight.w600,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '$len / 500',
                    style: TextStyle(
                      color: ReceptionTokens.navy.withValues(alpha: 0.45),
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _footer({required bool hasFile}) {
    // ملف سابق → فقط «تأكيد الحضور وإنشاء الزيارة»
    // بدون ملف → فقط «تسجيل الحضور وفتح الملف»
    final confirmEnabled = hasFile && !_saving;
    final createAndOpenEnabled = !hasFile && !_saving;

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.7),
        border: Border(top: BorderSide(color: ReceptionTokens.fieldBorder.withValues(alpha: 0.5))),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: _actionBtn(
              label: 'تاكيد الحضور واضافة زيارة',
              icon: Icons.check_circle_outline,
              enabled: confirmEnabled,
              loading: _saving && hasFile,
              onTap: confirmEnabled ? () => _submit(openProfile: false) : null,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 4,
            child: _actionBtn(
              label: 'تاكيد الحضور وانشاء ملف',
              icon: Icons.how_to_reg_outlined,
              enabled: createAndOpenEnabled,
              loading: _saving && !hasFile,
              onTap: createAndOpenEnabled ? () => _submit(openProfile: true) : null,
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 100,
            child: _actionBtn(
              label: 'إلغاء',
              enabled: !_saving,
              muted: true,
              onTap: _saving
                  ? null
                  : () => Navigator.pop(
                        context,
                        const ApproveDialogOutcome(ApproveDialogResult.cancelled),
                      ),
            ),
          ),
        ],
      ),
    );
  }

  /// Active: #002E45 — Disabled: #002E45 @ 25%
  Widget _actionBtn({
    required String label,
    IconData? icon,
    VoidCallback? onTap,
    bool enabled = true,
    bool loading = false,
    bool muted = false,
  }) {
    final active = (enabled && onTap != null) || loading;
    final bg = muted
        ? ReceptionTokens.rowAlt
        : ReceptionTokens.navy.withValues(alpha: active ? 1 : 0.25);
    final fg = muted
        ? ReceptionTokens.navy.withValues(alpha: active ? 1 : 0.45)
        : Colors.white.withValues(alpha: active ? 1 : 0.85);

    return InkWell(
      onTap: (enabled && onTap != null) ? onTap : null,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
        ),
        child: loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 18, color: fg),
                    const SizedBox(width: 6),
                  ],
                  Flexible(
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: fg,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
