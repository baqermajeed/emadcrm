import 'dart:io';
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../../controllers/customer_controller.dart';
import '../../core/constants.dart';
import '../../core/reception_tokens.dart';
import '../../models/customer.dart';
import '../../models/deal.dart';
import '../../models/visit.dart';
import '../../utils/enums.dart';
import '../../utils/formatters.dart';
import '../../widgets/reception/reception_assets.dart';
import '../../widgets/staff_avatar.dart';
import 'create_deal_screen.dart';
import 'edit_customer_screen.dart';

/// Customer profile — matched to Arabic CRM Customer Profile Dashboard mock.
class CustomerProfileScreen extends StatefulWidget {
  const CustomerProfileScreen({
    super.key,
    required this.customerId,
    this.canEdit = false,
    this.canAddDeal = false,
    this.canAddVisit = false,
    this.canUploadDocs = false,
    this.embedded = false,
    this.onBack,
  });

  final String customerId;
  final bool canEdit;
  final bool canAddDeal;
  final bool canAddVisit;
  final bool canUploadDocs;
  final bool embedded;
  final VoidCallback? onBack;

  @override
  State<CustomerProfileScreen> createState() => _CustomerProfileScreenState();
}

class _CustomerProfileScreenState extends State<CustomerProfileScreen> {
  final _scroll = ScrollController();

  final _secInfo = GlobalKey();
  final _secVisits = GlobalKey();
  final _secDeals = GlobalKey();
  final _secDocs = GlobalKey();
  final _secNotes = GlobalKey();

  static const _bg = Color(0xFFF4F7FE);
  static const _navy = Color(0xFF1B254B);
  static const _blue = Color(0xFF2B6CB0);
  static const _muted = Color(0xFF718096);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CustomerController>().openProfile(widget.customerId);
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _addVisit() async {
    final result = await showDialog<(String, String)?>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (context) => const _AddVisitDialog(),
    );
    if (result == null || !mounted) return;
    final (outcome, note) = result;
    final notes = note.trim().isEmpty ? outcome : '$outcome\n$note';
    await context.read<CustomerController>().addVisit(notes: notes);
  }

  Future<void> _viewVisit(Visit v, int index) async {
    final outcome = _visitResult(v, index);
    final note = visitNotesDisplay(v.notes);
    final result = await showDialog<(String, String)?>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (context) => _AddVisitDialog(
        isEditing: true,
        initialResult: outcome,
        initialNote: note == '—' ? '' : note,
      ),
    );
    if (result == null || !mounted) return;
    final (newOutcome, newNote) = result;
    final notes = newNote.trim().isEmpty ? newOutcome : '$newOutcome\n$newNote';
    await context.read<CustomerController>().updateVisit(visitId: v.id, notes: notes);
  }

  Future<void> _uploadDoc() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (file == null || !mounted) return;
    final note = await showDialog<String>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (_) => const _DocNoteDialog(),
    );
    if (!mounted) return;
    if (note == null) return; // cancelled
    final ctrl = context.read<CustomerController>();
    var filename = file.name;
    if (!filename.contains('.')) {
      filename = '$filename.jpg';
    }
    final ok = await ctrl.uploadDocument(
          file.path,
          filename,
          notes: note.trim().isEmpty ? null : note.trim(),
        );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? 'تم رفع الملف' : (ctrl.error ?? 'فشل رفع الملف'))),
    );
  }

  Future<void> _editCustomer() async {
    final c = context.read<CustomerController>().selected;
    if (c == null) return;
    final updated = await EditCustomerScreen.show(context, customer: c);
    if (updated == true && mounted) {
      await context.read<CustomerController>().openProfile(widget.customerId);
    }
  }

  Future<void> _addDeal(Customer c) async {
    final ok = await CreateDealScreen.show(context, customer: c);
    if (ok == true && mounted) {
      await context.read<CustomerController>().openProfile(widget.customerId);
    }
  }

  Future<void> _editDeal(Customer c, Deal deal) async {
    final ok = await CreateDealScreen.show(context, customer: c, deal: deal);
    if (ok == true && mounted) {
      await context.read<CustomerController>().openProfile(widget.customerId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تحديث الصفقة بنجاح')),
      );
    }
  }

  Future<void> _changeStatus() async {
    final ctrl = context.read<CustomerController>();
    final current = ctrl.selected?.status ?? _inferredStatus(ctrl);
    final picked = await showDialog<CustomerStatus>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (_) => _ChangeStatusDialog(current: current),
    );
    if (picked == null || !mounted) return;
    final ok = await ctrl.updateSelected({'status': picked});
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'تم تحديث حالة الزبون' : (ctrl.error ?? 'فشل تحديث الحالة')),
      ),
    );
  }

  String _customerCode(Customer c) {
    final tail = c.id.length >= 5 ? c.id.substring(c.id.length - 5) : c.id;
    return '#C-${tail.toUpperCase()}';
  }

  CustomerStatus _inferredStatus(CustomerController ctrl) {
    if (ctrl.deals.isNotEmpty) return CustomerStatus.buyer;
    if (ctrl.reservations.any((r) => r.status == ReservationStatus.active)) {
      return CustomerStatus.reservation;
    }
    if (ctrl.visits.isNotEmpty) return CustomerStatus.interested;
    return CustomerStatus.potential;
  }

  String _customerStatusLabel(CustomerController ctrl) {
    final saved = ctrl.selected?.status;
    if (saved != null) return saved.label;
    return _inferredStatus(ctrl).label;
  }

  String _visitResult(Visit v, int index) {
    final raw = (v.notes ?? '').trim();
    if (raw.isEmpty) {
      return switch (index % 3) {
        0 => 'مهتم',
        1 => 'زيارة ثانية',
        _ => 'استفسار',
      };
    }
    final first = raw.split('\n').first.trim();
    if (first == 'مهتم' || first == 'زيارة ثانية' || first == 'استفسار') return first;
    final n = raw.toLowerCase();
    if (n.contains('مهتم') || n.contains('interest')) return 'مهتم';
    if (n.contains('ثانية') || n.contains('ثاني')) return 'زيارة ثانية';
    if (n.contains('استفسار') || n.contains('inquiry')) return 'استفسار';
    return switch (index % 3) {
      0 => 'مهتم',
      1 => 'زيارة ثانية',
      _ => 'استفسار',
    };
  }

  static String visitNotesDisplay(String? notes) {
    if (notes == null || notes.trim().isEmpty) return '—';
    final lines = notes.trim().split('\n');
    if (lines.length == 1) {
      final first = lines.first.trim();
      if (first == 'مهتم' || first == 'زيارة ثانية' || first == 'استفسار') return '—';
      return first;
    }
    return lines.skip(1).join('\n').trim().isEmpty ? '—' : lines.skip(1).join('\n').trim();
  }

  Color _resultBg(String label) => switch (label) {
        'مهتم' => const Color(0xFFD1FAE5),
        'زيارة ثانية' => const Color(0xFFFEF3C7),
        _ => const Color(0xFFDBEAFE),
      };

  Color _resultFg(String label) => switch (label) {
        'مهتم' => const Color(0xFF047857),
        'زيارة ثانية' => const Color(0xFFB45309),
        _ => const Color(0xFF1D4ED8),
      };

  Widget _sourceGlyph(HowKnewCenter? how) {
    if (how == HowKnewCenter.socialMedia || how == HowKnewCenter.externalAds) {
      return RAssets.source('facebook', size: 28);
    }
    if (how == HowKnewCenter.buyerReferral) {
      return const Icon(Icons.people_alt_rounded, color: _blue, size: 26);
    }
    return const Icon(Icons.campaign_rounded, color: _blue, size: 26);
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<CustomerController>();
    final c = ctrl.selected;

    final body = ctrl.loading && c == null
        ? const Center(child: CircularProgressIndicator(color: ReceptionTokens.teal))
        : c == null
            ? Center(child: Text(ctrl.error ?? 'تعذر التحميل', style: GoogleFonts.cairo()))
            : SingleChildScrollView(
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                          _PageTitle(
                            onHome: widget.onBack ?? () => Navigator.of(context).maybePop(),
                          ),
                          const SizedBox(height: 12),
                          _ProfileSummary(
                            customer: c,
                            code: _customerCode(c),
                            sourceGlyph: _sourceGlyph(c.howKnew),
                          ),
                          const SizedBox(height: 14),
                          _StatsRow(
                            visits: ctrl.visits.length,
                            reservations: ctrl.reservations.length,
                            deals: ctrl.deals.length,
                            lastVisit: ctrl.visits.isEmpty ? null : ctrl.visits.first.visitDate,
                            status: _customerStatusLabel(ctrl),
                            hasActiveReservation: ctrl.reservations
                                .any((r) => r.status == ReservationStatus.active),
                            hasSold: ctrl.deals.isNotEmpty,
                            onChangeStatus: _changeStatus,
                          ),
                          const SizedBox(height: 14),
                          const _BasicInfoChip(),
                          const SizedBox(height: 14),
                          Row(
                            textDirection: ui.TextDirection.ltr,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: 280,
                                child: KeyedSubtree(
                                  key: _secInfo,
                                  child: KeyedSubtree(
                                    key: _secNotes,
                                    child: _InfoPanel(
                                      customer: c,
                                      canEdit: widget.canEdit,
                                      onEdit: _editCustomer,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  key: _secVisits,
                                  children: [
                                    _VisitsTable(
                                      visits: ctrl.visits,
                                      resultOf: _visitResult,
                                      resultBg: _resultBg,
                                      resultFg: _resultFg,
                                      canAdd: widget.canAddVisit,
                                      onAdd: _addVisit,
                                      onView: _viewVisit,
                                    ),
                                    const SizedBox(height: 14),
                                    KeyedSubtree(
                                      key: _secDeals,
                                      child: _DealsTable(
                                        items: ctrl.deals,
                                        canAdd: widget.canAddDeal,
                                        onAdd: () => _addDeal(c),
                                        onView: (d) => _editDeal(c, d),
                                      ),
                                    ),
                                    const SizedBox(height: 14),
                                    KeyedSubtree(
                                      key: _secDocs,
                                      child: _DocsSection(
                                        docs: c.documents,
                                        canUpload: widget.canUploadDocs,
                                        onUpload: _uploadDoc,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                  ],
                ),
              );

    final shell = Directionality(
      textDirection: ui.TextDirection.rtl,
      child: ColoredBox(
        color: _bg,
        child: body,
      ),
    );

    if (widget.embedded) return shell;

    return Scaffold(
      backgroundColor: _bg,
      body: shell,
    );
  }
}

// ───────────────────────── Page title / breadcrumb ─────────────────────────

class _PageTitle extends StatelessWidget {
  const _PageTitle({required this.onHome});

  final VoidCallback onHome;

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(
      fontFamily: 'LamaSans',
      fontSize: 15,
      fontWeight: FontWeight.w600,
      color: _CustomerProfileScreenState._navy,
    );
    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Row(
        children: [
          InkWell(
            onTap: onHome,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RAssets.svg(
                    'dc_home',
                    w: 16,
                    h: 16,
                    color: _CustomerProfileScreenState._navy,
                  ),
                  const SizedBox(width: 6),
                  const Text('الرئيسية', style: style),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6),
                    child: Text('/', style: style),
                  ),
                  const Text('ملف الزبون', style: style),
                ],
              ),
            ),
          ),
          const Spacer(),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onHome,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _CustomerProfileScreenState._navy.withValues(alpha: 0.12),
                  ),
                  boxShadow: ReceptionTokens.softShadow,
                ),
                child: Transform.rotate(
                  angle: 3.141592653589793, // 180°
                  child: const Icon(
                    Icons.arrow_back_rounded,
                    size: 22,
                    color: _CustomerProfileScreenState._navy,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────── Profile summary ─────────────────────────

class _ProfileSummary extends StatelessWidget {
  const _ProfileSummary({
    required this.customer,
    required this.code,
    required this.sourceGlyph,
  });

  final Customer customer;
  final String code;
  final Widget sourceGlyph;

  @override
  Widget build(BuildContext context) {
    final created = customer.createdAt;
    final dateStr = created == null ? '—' : DateFormat('dd/MM/yyyy').format(created.toLocal());
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: ReceptionTokens.cardShadow,
      ),
      // Visual LTR: avatar/name | assignment cards | property thumb
      child: Row(
        textDirection: ui.TextDirection.ltr,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 64,
            backgroundColor: const Color(0xFFE8F0FE),
            backgroundImage: AssetImage(
              customer.gender == CustomerGender.female
                  ? RAssets.avatarFemale
                  : RAssets.avatarMale,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // الاسم + الرمز + الحالة بنفس الصف (بجانب الصورة)
                Row(
                  textDirection: ui.TextDirection.ltr,
                  children: [
                    Flexible(
                      child: Text(
                        customer.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.cairo(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: _CustomerProfileScreenState._navy,
                          height: 1.2,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    _chip(code, const Color(0xFFEBF8FF), const Color(0xFF3182CE)),
                    const SizedBox(width: 8),
                    _chip('زبون نشط', const Color(0xFFF0FFF4), const Color(0xFF38A169)),
                  ],
                ),
                const SizedBox(height: 14),
                // صف1: هاتف | بريد
                Row(
                  textDirection: ui.TextDirection.ltr,
                  children: [
                    Expanded(
                      child: _contact(RAssets.profilePhone, customer.phone),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _contact(
                        RAssets.profileEmail,
                        (customer.email == null || customer.email!.trim().isEmpty)
                            ? '—'
                            : customer.email!,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // صف2: عنوان | مهنة
                Row(
                  textDirection: ui.TextDirection.ltr,
                  children: [
                    Expanded(
                      child: _contact(
                        RAssets.profileLocation,
                        customer.address ?? '—',
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _contact(
                        RAssets.profileJob,
                        customer.profession ?? '—',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            height: 132,
            child: Row(
              textDirection: ui.TextDirection.rtl,
              children: [
                SizedBox(width: 200, child: _propertyThumb()),
                const SizedBox(width: 8),
                SizedBox(
                  width: 132,
                  child: _stackedInfoCard(
                    title: 'موظف المبيعات',
                    avatar: StaffAvatar(
                      avatarUrl: customer.salesEmployeeAvatarUrl,
                      radius: 20,
                      backgroundColor: Colors.white,
                    ),
                    name: customer.salesEmployeeName ?? '—',
                    subtitle: dateStr,
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 132,
                  child: _stackedInfoCard(
                    title: 'موظف الكول سنتر',
                    avatar: StaffAvatar(
                      avatarUrl: customer.callCenterAvatarUrl,
                      radius: 20,
                      backgroundColor: Colors.white,
                    ),
                    name: customer.callCenterName ?? '—',
                    subtitle: dateStr,
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 132,
                  child: _stackedInfoCard(
                    title: 'مصدر الزبون',
                    avatar: _sourceAvatar(sourceGlyph),
                    name: customer.howKnew?.label ?? '—',
                    subtitle: 'إعلان مدفوع',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String text, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(
        text,
        style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.w700, color: fg),
      ),
    );
  }

  Widget _contact(String iconAsset, String text) {
    return Row(
      textDirection: ui.TextDirection.ltr,
      children: [
        RAssets.profileIcon(iconAsset, size: 30),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            textAlign: TextAlign.left,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.cairo(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _CustomerProfileScreenState._navy,
            ),
          ),
        ),
      ],
    );
  }

  /// عنوان → صورة/أيقونة → اسم/مصدر → تاريخ (مطابق للتصميم)
  Widget _stackedInfoCard({
    required String title,
    required Widget avatar,
    required String name,
    required String subtitle,
  }) {
    return Container(
      height: 132,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFE7F5F7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.max,
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.cairo(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: _CustomerProfileScreenState._navy,
            ),
          ),
          const SizedBox(height: 6),
          avatar,
          const SizedBox(height: 6),
          Text(
            name,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.cairo(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: _CustomerProfileScreenState._navy,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.cairo(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: _CustomerProfileScreenState._muted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sourceAvatar(Widget glyph) {
    return Container(
      width: 40,
      height: 40,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: glyph,
    );
  }

  Widget _propertyThumb() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: 132,
        width: double.infinity,
        child: Image.asset(
          RAssets.propertyVilla,
          fit: BoxFit.cover,
          alignment: Alignment.center,
          filterQuality: FilterQuality.high,
        ),
      ),
    );
  }
}

// ───────────────────────── Stats ─────────────────────────

class _StatsRow extends StatelessWidget {
  const _StatsRow({
    required this.visits,
    required this.reservations,
    required this.deals,
    required this.lastVisit,
    required this.status,
    required this.hasActiveReservation,
    required this.hasSold,
    this.onChangeStatus,
  });

  final int visits;
  final int reservations;
  final int deals;
  final DateTime? lastVisit;
  final String status;
  final bool hasActiveReservation;
  final bool hasSold;
  final VoidCallback? onChangeStatus;

  @override
  Widget build(BuildContext context) {
    final lastDate = lastVisit == null ? '—' : DateFormat('dd/MM/yyyy').format(lastVisit!.toLocal());
    final lastTime = lastVisit == null ? '' : DateFormat('hh:mm a').format(lastVisit!.toLocal());

    return Row(
      children: [
        Expanded(
          child: _stat(
            iconAsset: RAssets.statVisits,
            label: 'عدد الزيارات',
            value: '$visits',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _stat(
            iconAsset: RAssets.statReservations,
            label: 'حجوزات الدور',
            value: '$reservations',
            badge: hasActiveReservation ? 'حجز فعّال' : null,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _stat(
            iconAsset: RAssets.statDeals,
            label: 'صفقات البيع',
            value: '$deals',
            badge: hasSold ? 'تم البيع' : null,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _stat(
            iconAsset: RAssets.statLastVisit,
            label: 'آخر زيارة',
            value: lastDate,
            sub: lastTime,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _stat(
            iconAsset: RAssets.statStatus,
            label: 'حالة الزبون',
            value: status,
            action: onChangeStatus == null
                ? null
                : _StatusChangeChip(onPressed: onChangeStatus!),
          ),
        ),
      ],
    );
  }

  Widget _stat({
    required String iconAsset,
    required String label,
    required String value,
    String? sub,
    String? badge,
    Widget? action,
  }) {
    return Container(
      height: action != null ? 104 : 88,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: ReceptionTokens.cardShadow,
      ),
      child: Row(
        textDirection: ui.TextDirection.ltr,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              color: Color(0xFFE7F5F7),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: RAssets.profileIcon(iconAsset, size: 30),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: GoogleFonts.cairo(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _CustomerProfileScreenState._muted,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.cairo(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: _CustomerProfileScreenState._navy,
                        ),
                      ),
                    ),
                    if (badge != null) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD1FAE5),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          badge,
                          style: GoogleFonts.cairo(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF047857),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (sub != null && sub.isNotEmpty)
                  Text(
                    sub,
                    style: GoogleFonts.cairo(
                      fontSize: 10,
                      color: _CustomerProfileScreenState._muted,
                    ),
                  ),
                if (action != null) ...[
                  const SizedBox(height: 4),
                  action,
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChangeChip extends StatefulWidget {
  const _StatusChangeChip({required this.onPressed});

  final VoidCallback onPressed;

  @override
  State<_StatusChangeChip> createState() => _StatusChangeChipState();
}

class _StatusChangeChipState extends State<_StatusChangeChip>
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
    const radius = 8.0;
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        final shine = (_ctrl.value * 1.35) - 0.2;
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onPressed,
            borderRadius: BorderRadius.circular(radius),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(radius),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: CustomPaint(
                  foregroundPainter: _ShimmerPainter(progress: shine),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(radius),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          const Color(0xFF3B82F6).withValues(alpha: 0.72),
                          const Color(0xFF069BAF).withValues(alpha: 0.78),
                          const Color(0xFF2563EB).withValues(alpha: 0.70),
                        ],
                      ),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.55),
                        width: 1,
                      ),
                    ),
                    child: child,
                  ),
                ),
              ),
            ),
          ),
        );
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.swap_horiz_rounded, size: 13, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            'تغيير',
            style: GoogleFonts.cairo(
              fontWeight: FontWeight.w800,
              fontSize: 10,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────── Add visit dialog ─────────────────────────

class _AddVisitDialog extends StatefulWidget {
  const _AddVisitDialog({
    this.isEditing = false,
    this.initialResult,
    this.initialNote,
  });

  final bool isEditing;
  final String? initialResult;
  final String? initialNote;

  @override
  State<_AddVisitDialog> createState() => _AddVisitDialogState();
}

class _AddVisitDialogState extends State<_AddVisitDialog> {
  late final TextEditingController _notes;
  late String _result;

  static const _results = ['مهتم', 'زيارة ثانية', 'استفسار'];

  @override
  void initState() {
    super.initState();
    _result = widget.initialResult ?? 'مهتم';
    if (!_results.contains(_result)) _result = 'مهتم';
    _notes = TextEditingController(text: widget.initialNote ?? '');
  }

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  InputDecoration _fieldDecoration() {
    return InputDecoration(
      filled: true,
      fillColor: const Color(0xFFF6FCFF),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: ReceptionTokens.navy.withValues(alpha: 0.15)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: ReceptionTokens.navy.withValues(alpha: 0.15)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: ReceptionTokens.teal, width: 1.4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.isEditing;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      child: Directionality(
        textDirection: ui.TextDirection.rtl,
        child: Container(
          width: 420,
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: ReceptionTokens.cardShadow,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                      color: Color(0xFFE7F5F7),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: RAssets.profileIcon(RAssets.statLastVisit, size: 26),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          editing ? 'تفاصيل الزيارة' : 'زيارة جديدة',
                          style: GoogleFonts.cairo(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: ReceptionTokens.navy,
                          ),
                        ),
                        Text(
                          editing
                              ? 'عدّل نتيجة الزيارة والملاحظات'
                              : 'سجّل نتيجة الزيارة والملاحظات',
                          style: GoogleFonts.cairo(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: ReceptionTokens.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, color: ReceptionTokens.navy),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                'نتيجة الزيارة',
                style: GoogleFonts.cairo(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: ReceptionTokens.navy,
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _result,
                decoration: _fieldDecoration(),
                items: _results
                    .map(
                      (e) => DropdownMenuItem(
                        value: e,
                        child: Text(e, style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
                      ),
                    )
                    .toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _result = v);
                },
              ),
              const SizedBox(height: 16),
              Text(
                'ملاحظة',
                style: GoogleFonts.cairo(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: ReceptionTokens.navy,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _notes,
                maxLines: 4,
                style: GoogleFonts.cairo(fontWeight: FontWeight.w600, color: ReceptionTokens.navy),
                decoration: _fieldDecoration().copyWith(
                  hintText: 'اكتب ملاحظة عن الزيارة...',
                  hintStyle: GoogleFonts.cairo(color: ReceptionTokens.muted),
                  contentPadding: const EdgeInsets.all(14),
                ),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.pop(context, (_result, _notes.text)),
                      style: FilledButton.styleFrom(
                        backgroundColor: ReceptionTokens.navy,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: Text(
                        'حفظ',
                        style: GoogleFonts.cairo(fontWeight: FontWeight.w800, fontSize: 15),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: ReceptionTokens.navy,
                        side: BorderSide(color: ReceptionTokens.navy.withValues(alpha: 0.2)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                        'إلغاء',
                        style: GoogleFonts.cairo(fontWeight: FontWeight.w800, fontSize: 15),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ───────────────────────── Change status dialog ─────────────────────────

class _ChangeStatusDialog extends StatefulWidget {
  const _ChangeStatusDialog({required this.current});

  final CustomerStatus current;

  @override
  State<_ChangeStatusDialog> createState() => _ChangeStatusDialogState();
}

class _ChangeStatusDialogState extends State<_ChangeStatusDialog> {
  late CustomerStatus _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.current;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      child: Directionality(
        textDirection: ui.TextDirection.rtl,
        child: Container(
          width: 400,
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: ReceptionTokens.cardShadow,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                      color: Color(0xFFE7F5F7),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: RAssets.profileIcon(RAssets.statStatus, size: 26),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'تغيير حالة الزبون',
                          style: GoogleFonts.cairo(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: ReceptionTokens.navy,
                          ),
                        ),
                        Text(
                          'اختر الحالة الجديدة للزبون',
                          style: GoogleFonts.cairo(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: ReceptionTokens.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, color: ReceptionTokens.navy),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ...CustomerStatus.values.map((s) {
                final selected = s == _selected;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => setState(() => _selected = s),
                      borderRadius: BorderRadius.circular(12),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: selected
                              ? const Color(0xFFE7F5F7)
                              : const Color(0xFFF6FCFF),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: selected
                                ? ReceptionTokens.teal
                                : ReceptionTokens.navy.withValues(alpha: 0.12),
                            width: selected ? 1.6 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              selected
                                  ? Icons.radio_button_checked_rounded
                                  : Icons.radio_button_off_rounded,
                              size: 20,
                              color: selected
                                  ? ReceptionTokens.teal
                                  : ReceptionTokens.muted,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                s.label,
                                style: GoogleFonts.cairo(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: ReceptionTokens.navy,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.pop(context, _selected),
                      style: FilledButton.styleFrom(
                        backgroundColor: ReceptionTokens.navy,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        'حفظ',
                        style: GoogleFonts.cairo(fontWeight: FontWeight.w800, fontSize: 15),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: ReceptionTokens.navy,
                        side: BorderSide(
                          color: ReceptionTokens.navy.withValues(alpha: 0.2),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'إلغاء',
                        style: GoogleFonts.cairo(fontWeight: FontWeight.w800, fontSize: 15),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ───────────────────────── Basic info chip ─────────────────────────

class _BasicInfoChip extends StatelessWidget {
  const _BasicInfoChip();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF2B6CB0),
          borderRadius: BorderRadius.circular(14),
          boxShadow: ReceptionTokens.cardShadow,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          textDirection: ui.TextDirection.rtl,
          children: [
            RAssets.profileIcon(RAssets.statDeals, size: 28),
            const SizedBox(width: 10),
            Text(
              'المعلومات الأساسية',
              style: GoogleFonts.cairo(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────── Info panel ─────────────────────────

class _InfoPanel extends StatelessWidget {
  const _InfoPanel({
    required this.customer,
    required this.canEdit,
    required this.onEdit,
  });

  final Customer customer;
  final bool canEdit;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: ReceptionTokens.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'معلومات الزبون',
                  style: GoogleFonts.cairo(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: _CustomerProfileScreenState._navy,
                  ),
                ),
              ),
              if (canEdit)
                TextButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: Text('تعديل', style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
                  style: TextButton.styleFrom(
                    foregroundColor: _CustomerProfileScreenState._blue,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          _fieldAsset(RAssets.profileName, 'الاسم الكامل', customer.name),
          _fieldAsset(RAssets.profilePhone, 'رقم الهاتف', customer.phone),
          _fieldAsset(
            RAssets.profileEmail,
            'البريد الإلكتروني',
            (customer.email == null || customer.email!.trim().isEmpty)
                ? '—'
                : customer.email!,
          ),
          _fieldAsset(RAssets.profileJob, 'المهنة', customer.profession ?? '—'),
          _fieldAsset(RAssets.profileLocation, 'العنوان', customer.address ?? '—'),
          _fieldAsset(RAssets.profileShare, 'مصدر الزبون', customer.howKnew?.label ?? '—'),
          const SizedBox(height: 12),
          Text(
            'ملاحظات عامة',
            style: GoogleFonts.cairo(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: _CustomerProfileScreenState._navy,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F4FC),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              (customer.notes == null || customer.notes!.trim().isEmpty)
                  ? 'لا توجد ملاحظات'
                  : customer.notes!,
              style: GoogleFonts.cairo(
                fontSize: 12,
                height: 1.55,
                color: _CustomerProfileScreenState._navy,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _fieldAsset(String asset, String label, String value) {
    return _fieldRow(
      label: label,
      value: value,
      leading: RAssets.profileIcon(asset, size: 30),
    );
  }

  Widget _fieldRow({
    required String label,
    required String value,
    required Widget leading,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        textDirection: ui.TextDirection.rtl,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 30, height: 30, child: leading),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  label,
                  textAlign: TextAlign.right,
                  style: GoogleFonts.cairo(
                    fontSize: 11,
                    color: _CustomerProfileScreenState._muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  value,
                  textAlign: TextAlign.right,
                  style: GoogleFonts.cairo(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _CustomerProfileScreenState._navy,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────── Shared table chrome ─────────────────────────

Widget _badge(String text, {Color? bg, Color? fg}) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: bg ?? const Color(0xFFD1FAE5),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      text,
      style: GoogleFonts.cairo(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: fg ?? const Color(0xFF047857),
      ),
    ),
  );
}

TextStyle get _td => GoogleFonts.cairo(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: _CustomerProfileScreenState._navy,
    );

// ───────────────────────── Glass shimmer button ─────────────────────────

class _GlassShimmerButton extends StatefulWidget {
  const _GlassShimmerButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  State<_GlassShimmerButton> createState() => _GlassShimmerButtonState();
}

class _GlassShimmerButtonState extends State<_GlassShimmerButton>
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
    const radius = 12.0;
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        final t = _ctrl.value;
        // Sweep from left → right with a soft pause feel
        final shine = (t * 1.35) - 0.2;
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onPressed,
            borderRadius: BorderRadius.circular(radius),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(radius),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: CustomPaint(
                  foregroundPainter: _ShimmerPainter(progress: shine),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(radius),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          const Color(0xFF3B82F6).withValues(alpha: 0.72),
                          const Color(0xFF069BAF).withValues(alpha: 0.78),
                          const Color(0xFF2563EB).withValues(alpha: 0.70),
                        ],
                      ),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.55),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF069BAF).withValues(alpha: 0.28),
                          blurRadius: 14,
                          offset: const Offset(0, 4),
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
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(widget.icon, size: 18, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            widget.label,
            style: GoogleFonts.cairo(
              fontWeight: FontWeight.w800,
              fontSize: 13,
              color: Colors.white,
              shadows: [
                Shadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 4,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ShimmerPainter extends CustomPainter {
  _ShimmerPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress < 0 || progress > 1.15) return;
    final bandW = size.width * 0.38;
    final x = (size.width + bandW) * progress - bandW;
    final rect = Rect.fromLTWH(x, -4, bandW, size.height + 8);
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          Colors.white.withValues(alpha: 0),
          Colors.white.withValues(alpha: 0.55),
          Colors.white.withValues(alpha: 0.15),
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
  bool shouldRepaint(covariant _ShimmerPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

// ───────────────────────── Visits ─────────────────────────

class _VisitsTable extends StatelessWidget {
  const _VisitsTable({
    required this.visits,
    required this.resultOf,
    required this.resultBg,
    required this.resultFg,
    required this.canAdd,
    required this.onAdd,
    required this.onView,
  });

  final List<Visit> visits;
  final String Function(Visit, int) resultOf;
  final Color Function(String) resultBg;
  final Color Function(String) resultFg;
  final bool canAdd;
  final VoidCallback onAdd;
  final void Function(Visit visit, int index) onView;

  static const _titleBarBg = Colors.white;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: ReceptionTokens.cardShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // شريط العنوان
          Container(
            color: _titleBarBg,
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Row(
              textDirection: ui.TextDirection.ltr,
              children: [
                if (canAdd)
                  _GlassShimmerButton(
                    label: 'إضافة زيارة جديدة',
                    icon: Icons.add_rounded,
                    onPressed: onAdd,
                  ),
                const Spacer(),
                Text(
                  'سجل الزيارات',
                  style: GoogleFonts.cairo(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: _CustomerProfileScreenState._navy,
                  ),
                ),
                const SizedBox(width: 8),
                RAssets.profileIcon(RAssets.statLastVisit, size: 28),
              ],
            ),
          ),
          if (visits.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text('لا توجد زيارات', textAlign: TextAlign.center, style: _td),
            )
          else
            Column(
              children: [
                _autoRow(
                  background: const Color(0xFFE7F5F7),
                  isHeader: true,
                  cells: const [
                    '#',
                    'تاريخ الزيارة',
                    'الشهر',
                    'وقت الزيارة',
                    'موظف الاستقبال',
                    'موظف المبيعات',
                    'نتيجة الزيارة',
                    'ملاحظات',
                    'اجراءات',
                  ],
                ),
                for (var i = 0; i < visits.length; i++)
                  () {
                    final v = visits[i];
                    final local = v.visitDate.toLocal();
                    final result = resultOf(v, i);
                    return Column(
                      children: [
                        _autoRow(
                          cells: [
                            (i + 1).toString().padLeft(2, '0'),
                            DateFormat('dd/MM/yyyy').format(local),
                            DateFormat('MMMM yyyy', 'ar').format(local),
                            DateFormat('hh:mm a', 'ar').format(local),
                            v.recordedByName ?? '—',
                            v.salesEmployeeName ?? '—',
                            result,
                            _CustomerProfileScreenState.visitNotesDisplay(v.notes),
                            '__action__',
                          ],
                          resultLabel: result,
                          resultBg: resultBg(result),
                          resultFg: resultFg(result),
                          onView: () => onView(v, i),
                        ),
                        if (i < visits.length - 1)
                          const Center(
                            child: FractionallySizedBox(
                              widthFactor: 0.72,
                              child: Divider(height: 1, thickness: 0.8, color: Color(0xFFE8EEF2)),
                            ),
                          ),
                      ],
                    );
                  }(),
              ],
            ),
        ],
      ),
    );
  }

  static const _flexes = [1, 2, 2, 2, 2, 2, 2, 3, 2];

  Widget _autoRow({
    required List<String> cells,
    Color? background,
    bool isHeader = false,
    String? resultLabel,
    Color? resultBg,
    Color? resultFg,
    VoidCallback? onView,
  }) {
    return Container(
      margin: isHeader ? const EdgeInsets.symmetric(horizontal: 6) : null,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: isHeader
            ? const BorderRadius.vertical(top: Radius.circular(16))
            : null,
      ),
      child: Row(
        textDirection: ui.TextDirection.rtl,
        children: [
          for (var i = 0; i < cells.length; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            Expanded(
              flex: _flexes[i],
              child: _autoCell(
                cells[i],
                column: i,
                isHeader: isHeader,
                resultBg: resultBg,
                resultFg: resultFg,
                onView: onView,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _autoCell(
    String value, {
    required int column,
    required bool isHeader,
    Color? resultBg,
    Color? resultFg,
    VoidCallback? onView,
  }) {
    if (isHeader) {
      return Text(
        value,
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.cairo(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: _CustomerProfileScreenState._navy,
        ),
      );
    }
    // 6 = نتيجة الزيارة ، 8 = اجراءات
    if (column == 8) return Center(child: _visitsViewBtn(onView));
    if (column == 6) {
      return Center(child: _badge(value, bg: resultBg, fg: resultFg));
    }
    return Text(
      value,
      textAlign: TextAlign.center,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: _td,
    );
  }

  Widget _visitsViewBtn(VoidCallback? onPressed) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF2B6CB0),
        side: const BorderSide(color: Color(0xFFBFDBFE)),
        backgroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        minimumSize: const Size(0, 32),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Text(
        'عرض',
        style: GoogleFonts.cairo(fontWeight: FontWeight.w800, fontSize: 12),
      ),
    );
  }
}

// ───────────────────────── Deals ─────────────────────────

class _DealsTable extends StatelessWidget {
  const _DealsTable({
    required this.items,
    required this.canAdd,
    required this.onAdd,
    required this.onView,
  });

  final List<Deal> items;
  final bool canAdd;
  final VoidCallback onAdd;
  final ValueChanged<Deal> onView;

  static const _statusBg = Color(0xFFD1FAE5);
  static const _statusFg = Color(0xFF047857);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: ReceptionTokens.cardShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Row(
              textDirection: ui.TextDirection.ltr,
              children: [
                if (canAdd)
                  _GlassShimmerButton(
                    label: 'إضافة صفقة جديدة',
                    icon: Icons.add_rounded,
                    onPressed: onAdd,
                  ),
                const Spacer(),
                Text(
                  'صفقات البيع',
                  style: GoogleFonts.cairo(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: _CustomerProfileScreenState._navy,
                  ),
                ),
                const SizedBox(width: 8),
                RAssets.profileIcon(RAssets.statDeals, size: 28),
              ],
            ),
          ),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text('لا توجد صفقات', textAlign: TextAlign.center, style: _td),
            )
          else
            Column(
              children: [
                _row(
                  background: const Color(0xFFE7F5F7),
                  isHeader: true,
                  cells: const [
                    '#',
                    'البلوك',
                    'رقم الدار',
                    'المساحة',
                    'السعر الكلي',
                    'نوع الدفع',
                    'المقدم',
                    'تاريخ البيع',
                    'الحالة',
                    'إجراء',
                  ],
                ),
                for (var i = 0; i < items.length; i++)
                  () {
                    final d = items[i];
                    return Column(
                      children: [
                        _row(
                          deal: d,
                          cells: [
                            (i + 1).toString().padLeft(2, '0'),
                            d.residentialBlock ?? '—',
                            d.houseNumber ?? '—',
                            d.houseArea == null
                                ? '—'
                                : '${d.houseArea!.toStringAsFixed(0)} م²',
                            formatMoney(d.totalPrice),
                            d.paymentType.label,
                            formatMoney(d.downPayment),
                            formatDate(d.saleDate),
                            d.status.label,
                            '__action__',
                          ],
                        ),
                        if (i < items.length - 1)
                          const Center(
                            child: FractionallySizedBox(
                              widthFactor: 0.72,
                              child: Divider(
                                height: 1,
                                thickness: 0.8,
                                color: Color(0xFFE8EEF2),
                              ),
                            ),
                          ),
                      ],
                    );
                  }(),
              ],
            ),
        ],
      ),
    );
  }

  static const _flexes = [1, 2, 2, 2, 3, 2, 3, 2, 2, 2];

  Widget _row({
    required List<String> cells,
    Color? background,
    bool isHeader = false,
    Deal? deal,
  }) {
    return Container(
      margin: isHeader ? const EdgeInsets.symmetric(horizontal: 6) : null,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: isHeader
            ? const BorderRadius.vertical(top: Radius.circular(16))
            : null,
      ),
      child: Row(
        textDirection: ui.TextDirection.rtl,
        children: [
          for (var i = 0; i < cells.length; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            Expanded(
              flex: _flexes[i],
              child: _cell(
                cells[i],
                column: i,
                isHeader: isHeader,
                deal: deal,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _cell(
    String value, {
    required int column,
    required bool isHeader,
    Deal? deal,
  }) {
    if (isHeader) {
      return Text(
        value,
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.cairo(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: _CustomerProfileScreenState._navy,
        ),
      );
    }
    // 8 = الحالة ، 9 = إجراء
    if (column == 9) {
      return Center(
        child: OutlinedButton(
          onPressed: deal == null ? null : () => onView(deal),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF2B6CB0),
            side: const BorderSide(color: Color(0xFFBFDBFE)),
            backgroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            minimumSize: const Size(0, 32),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: Text(
            'عرض',
            style: GoogleFonts.cairo(fontWeight: FontWeight.w800, fontSize: 12),
          ),
        ),
      );
    }
    if (column == 8) {
      return Center(child: _badge(value, bg: _statusBg, fg: _statusFg));
    }
    return Text(
      value,
      textAlign: TextAlign.center,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: _td,
    );
  }
}

// ───────────────────────── Documents ─────────────────────────

class _DocsSection extends StatelessWidget {
  const _DocsSection({
    required this.docs,
    required this.canUpload,
    required this.onUpload,
  });

  final List<CustomerDocument> docs;
  final bool canUpload;
  final VoidCallback onUpload;

  static const _previewCount = 5;

  Future<void> _openDialog(BuildContext context) {
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (_) => _DocsDialog(
        docs: docs,
        canUpload: canUpload,
        onUpload: onUpload,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visible = docs.take(_previewCount).toList();
    final extra = docs.length - visible.length;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: ReceptionTokens.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            textDirection: ui.TextDirection.ltr,
            children: [
              if (canUpload)
                _GlassShimmerButton(
                  label: 'رفع ملف جديد',
                  icon: Icons.add_rounded,
                  onPressed: onUpload,
                ),
              const Spacer(),
              Text(
                'المستندات والصور',
                style: GoogleFonts.cairo(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: _CustomerProfileScreenState._navy,
                ),
              ),
              const SizedBox(width: 8),
              RAssets.profileIcon(RAssets.statDeals, size: 26),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 168,
            child: Directionality(
              textDirection: ui.TextDirection.rtl,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  if (canUpload) ...[
                    _DocUploadCard(onTap: onUpload),
                    const SizedBox(width: 10),
                  ],
                  for (final d in visible) ...[
                    _DocCard(doc: d),
                    const SizedBox(width: 10),
                  ],
                  if (extra > 0)
                    _DocMoreCard(
                      count: extra,
                      onTap: () => _openDialog(context),
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

class _DocsDialog extends StatelessWidget {
  const _DocsDialog({
    required this.docs,
    required this.canUpload,
    required this.onUpload,
  });

  final List<CustomerDocument> docs;
  final bool canUpload;
  final VoidCallback onUpload;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 28),
      child: Directionality(
        textDirection: ui.TextDirection.rtl,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Material(
            color: Colors.white,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 820,
                maxHeight: size.height * 0.82,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
                    child: Row(
                      textDirection: ui.TextDirection.ltr,
                      children: [
                        if (canUpload)
                          _GlassShimmerButton(
                            label: 'رفع ملف جديد',
                            icon: Icons.add_rounded,
                            onPressed: () {
                              Navigator.pop(context);
                              onUpload();
                            },
                          ),
                        const Spacer(),
                        Text(
                          'المستندات والصور',
                          style: GoogleFonts.cairo(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: _CustomerProfileScreenState._navy,
                          ),
                        ),
                        const SizedBox(width: 8),
                        RAssets.profileIcon(RAssets.statDeals, size: 28),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close_rounded),
                          color: _CustomerProfileScreenState._navy,
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: Color(0xFFE8EEF2)),
                  Expanded(
                    child: docs.isEmpty && !canUpload
                        ? Center(
                            child: Text('لا توجد مستندات', style: _td),
                          )
                        : GridView.builder(
                            padding: const EdgeInsets.all(18),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 4,
                              mainAxisSpacing: 12,
                              crossAxisSpacing: 12,
                              childAspectRatio: 0.68,
                            ),
                            itemCount: docs.length + (canUpload ? 1 : 0),
                            itemBuilder: (context, i) {
                              if (canUpload && i == 0) {
                                return _DocUploadCard(
                                  onTap: () {
                                    Navigator.pop(context);
                                    onUpload();
                                  },
                                );
                              }
                              final doc = docs[canUpload ? i - 1 : i];
                              return _DocCard(doc: doc, large: true);
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DocUploadCard extends StatelessWidget {
  const _DocUploadCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: CustomPaint(
        painter: _DashedBorderPainter(
          color: const Color(0xFF93C5FD),
          radius: 14,
        ),
        child: Container(
          width: 118,
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.note_add_outlined, color: Color(0xFF1E6FD9), size: 26),
              ),
              const SizedBox(height: 10),
              Text(
                'رفع ملف',
                style: GoogleFonts.cairo(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF1E6FD9),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DocCard extends StatelessWidget {
  const _DocCard({required this.doc, this.large = false});

  final CustomerDocument doc;
  final bool large;

  void _openPreview(BuildContext context) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (_) => _DocPreviewDialog(doc: doc),
    );
  }

  @override
  Widget build(BuildContext context) {
    final url = '${AppConstants.apiBaseUrl}${doc.url}';
    final note = doc.notes?.trim() ?? '';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openPreview(context),
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          width: large ? null : 118,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: ReceptionTokens.teal.withValues(alpha: 0.08),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: doc.isImage
                      ? CachedNetworkImage(
                          imageUrl: url,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          errorWidget: (context, url, error) => const ColoredBox(
                            color: Color(0xFFF1F5F9),
                            child: Icon(Icons.broken_image_outlined, color: Color(0xFF94A3B8)),
                          ),
                        )
                      : ColoredBox(
                          color: const Color(0xFFF8FAFC),
                          child: Icon(
                            Icons.picture_as_pdf_rounded,
                            color: Colors.red.shade400,
                            size: 42,
                          ),
                        ),
                ),
                if (note.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
                    child: Text(
                      note,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.cairo(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: _CustomerProfileScreenState._navy,
                        height: 1.3,
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

class _DocPreviewDialog extends StatefulWidget {
  const _DocPreviewDialog({required this.doc});

  final CustomerDocument doc;

  @override
  State<_DocPreviewDialog> createState() => _DocPreviewDialogState();
}

class _DocPreviewDialogState extends State<_DocPreviewDialog> {
  bool _saving = false;

  String get _url => '${AppConstants.apiBaseUrl}${widget.doc.url}';

  String get _fileName {
    final name = widget.doc.originalName.trim().isNotEmpty
        ? widget.doc.originalName.trim()
        : widget.doc.filename;
    return name.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
  }

  Future<Directory> _downloadsDir() async {
    final downloads = await getDownloadsDirectory();
    if (downloads != null) return downloads;
    return getApplicationDocumentsDirectory();
  }

  Future<File> _uniqueFile(Directory dir, String name) async {
    var file = File('${dir.path}${Platform.pathSeparator}$name');
    if (!await file.exists()) return file;
    final dot = name.lastIndexOf('.');
    final base = dot > 0 ? name.substring(0, dot) : name;
    final ext = dot > 0 ? name.substring(dot) : '';
    var i = 1;
    while (await file.exists()) {
      file = File('${dir.path}${Platform.pathSeparator}$base ($i)$ext');
      i++;
    }
    return file;
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final res = await http.get(Uri.parse(_url));
      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw Exception('HTTP ${res.statusCode}');
      }
      final dir = await _downloadsDir();
      final file = await _uniqueFile(dir, _fileName);
      await file.writeAsBytes(res.bodyBytes);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تم الحفظ في: ${file.path}')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('فشل حفظ الملف')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final note = widget.doc.notes?.trim() ?? '';

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 36, vertical: 28),
      child: Directionality(
        textDirection: ui.TextDirection.rtl,
        child: Container(
          width: 560,
          constraints: BoxConstraints(maxHeight: size.height * 0.86),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: ReceptionTokens.cardShadow,
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        note.isNotEmpty ? note : 'معاينة الملف',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.cairo(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: _CustomerProfileScreenState._navy,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                      color: _CustomerProfileScreenState._navy,
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Color(0xFFE8EEF2)),
              Flexible(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: size.height * 0.58,
                    minHeight: 220,
                  ),
                  child: ColoredBox(
                    color: const Color(0xFFF8FAFC),
                    child: widget.doc.isImage
                        ? InteractiveViewer(
                            minScale: 0.8,
                            maxScale: 4,
                            child: Center(
                              child: CachedNetworkImage(
                                imageUrl: _url,
                                fit: BoxFit.contain,
                                errorWidget: (context, url, error) => const Padding(
                                  padding: EdgeInsets.all(32),
                                  child: Icon(
                                    Icons.broken_image_outlined,
                                    size: 56,
                                    color: Color(0xFF94A3B8),
                                  ),
                                ),
                              ),
                            ),
                          )
                        : Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.picture_as_pdf_rounded,
                                  size: 72,
                                  color: Colors.red.shade400,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  _fileName,
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.cairo(
                                    fontWeight: FontWeight.w700,
                                    color: _CustomerProfileScreenState._navy,
                                  ),
                                ),
                              ],
                            ),
                          ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _saving ? null : _save,
                        icon: _saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.download_rounded, size: 20),
                        label: Text(
                          _saving ? 'جاري الحفظ...' : 'حفظ',
                          style: GoogleFonts.cairo(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF1E6FD9),
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: const Color(0xFF93C5FD),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _CustomerProfileScreenState._navy,
                          side: BorderSide(
                            color: ReceptionTokens.navy.withValues(alpha: 0.2),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'إغلاق',
                          style: GoogleFonts.cairo(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DocNoteDialog extends StatefulWidget {
  const _DocNoteDialog();

  @override
  State<_DocNoteDialog> createState() => _DocNoteDialogState();
}

class _DocNoteDialogState extends State<_DocNoteDialog> {
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 36, vertical: 24),
      child: Directionality(
        textDirection: ui.TextDirection.rtl,
        child: Container(
          width: 400,
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: ReceptionTokens.cardShadow,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'ملاحظة على الملف',
                style: GoogleFonts.cairo(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: _CustomerProfileScreenState._navy,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'اختياري — ستظهر أسفل الصورة',
                style: GoogleFonts.cairo(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _CustomerProfileScreenState._muted,
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _note,
                maxLines: 3,
                maxLength: 300,
                style: GoogleFonts.cairo(
                  fontWeight: FontWeight.w600,
                  color: _CustomerProfileScreenState._navy,
                ),
                decoration: InputDecoration(
                  hintText: 'اكتب ملاحظة قصيرة...',
                  hintStyle: GoogleFonts.cairo(color: _CustomerProfileScreenState._muted),
                  filled: true,
                  fillColor: const Color(0xFFF6FCFF),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: ReceptionTokens.navy.withValues(alpha: 0.15)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: ReceptionTokens.navy.withValues(alpha: 0.15)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: ReceptionTokens.teal, width: 1.4),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.pop(context, _note.text),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF1E6FD9),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                      child: Text(
                        'رفع',
                        style: GoogleFonts.cairo(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _CustomerProfileScreenState._navy,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: Text(
                        'إلغاء',
                        style: GoogleFonts.cairo(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DocMoreCard extends StatelessWidget {
  const _DocMoreCard({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 118,
        decoration: BoxDecoration(
          color: const Color(0xFFEFF6FF),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFBFDBFE)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '+$count',
              style: GoogleFonts.cairo(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF1E6FD9),
                height: 1,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'مزيد من الملفات',
              textAlign: TextAlign.center,
              style: GoogleFonts.cairo(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1E6FD9),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  _DashedBorderPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0.75, 0.75, size.width - 1.5, size.height - 1.5),
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rrect);
    final dashed = _dashPath(path, dashWidth: 5, dashSpace: 4);
    canvas.drawPath(dashed, paint);
  }

  Path _dashPath(Path source, {required double dashWidth, required double dashSpace}) {
    final dest = Path();
    for (final metric in source.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = distance + dashWidth;
        dest.addPath(metric.extractPath(distance, next.clamp(0, metric.length)), Offset.zero);
        distance = next + dashSpace;
      }
    }
    return dest;
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.radius != radius;
}
