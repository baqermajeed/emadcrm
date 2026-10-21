import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../controllers/booking_controller.dart';
import '../../core/reception_tokens.dart';
import '../../utils/enums.dart';
import '../../utils/formatters.dart';
import '../../utils/validators.dart';
import '../../widgets/reception/reception_assets.dart';

class CreateBookingScreen extends StatefulWidget {
  const CreateBookingScreen({super.key});

  static Future<bool?> show(BuildContext context) {
    return showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (_) => const CreateBookingScreen(),
    );
  }

  @override
  State<CreateBookingScreen> createState() => _CreateBookingScreenState();
}

class _CreateBookingScreenState extends State<CreateBookingScreen> {
  static const _ink = Color(0xFF123B70);

  static const _governorates = [
    'بغداد',
    'البصرة',
    'نينوى',
    'أربيل',
    'النجف',
    'كربلاء',
    'بابل',
    'الأنبار',
    'ديالى',
    'كركوك',
    'صلاح الدين',
    'واسط',
    'ميسان',
    'ذي قار',
    'المثنى',
    'القادسية',
    'دهوك',
    'السليمانية',
  ];

  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _notes = TextEditingController();
  String? _governorate;
  BookingSource _source = BookingSource.whatsapp;
  DateTime _visitDate = DateTime.now().add(const Duration(days: 1));
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _visitDate,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
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
    if (date == null) return;
    if (!mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_visitDate),
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
    setState(() {
      _visitDate = DateTime(
        date.year,
        date.month,
        date.day,
        time?.hour ?? 10,
        time?.minute ?? 0,
      );
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_governorate == null || _governorate!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اختر المحافظة')),
      );
      return;
    }
    setState(() => _saving = true);
    final ok = await context.read<BookingController>().create(
          name: _name.text.trim(),
          phone: _phone.text.trim(),
          governorate: _governorate!,
          source: _source,
          visitDate: _visitDate,
          notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
        );
    setState(() => _saving = false);
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.read<BookingController>().error ?? 'فشل الحفظ'),
        ),
      );
    }
  }

  InputDecoration _fieldDeco({
    required String label,
    String? hint,
    Widget? prefix,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: prefix,
      isDense: true,
      filled: true,
      fillColor: const Color(0xFFF8FAFD),
      labelStyle: GoogleFonts.cairo(
        fontWeight: FontWeight.w700,
        fontSize: 12,
        color: ReceptionTokens.navy.withValues(alpha: 0.55),
      ),
      hintStyle: GoogleFonts.cairo(
        fontWeight: FontWeight.w600,
        fontSize: 12,
        color: ReceptionTokens.navy.withValues(alpha: 0.35),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: ReceptionTokens.fieldBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: ReceptionTokens.fieldBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: ReceptionTokens.teal, width: 1.4),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFDC2626)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final maxH = size.height * 0.88;

    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 560, maxHeight: maxH),
          child: Material(
            color: ReceptionTokens.bg,
            borderRadius: BorderRadius.circular(18),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _DialogHeader(onClose: () => Navigator.pop(context)),
                Flexible(
                  child: Form(
                    key: _formKey,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(18, 4, 18, 18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _section(
                            title: 'بيانات الزبون',
                            child: Column(
                              children: [
                                TextFormField(
                                  controller: _name,
                                  style: GoogleFonts.cairo(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                    color: _ink,
                                  ),
                                  inputFormatters: [PersonNameInputFormatter()],
                                  decoration: _fieldDeco(
                                    label: 'اسم الحجز',
                                    hint: 'الاسم الكامل',
                                    prefix: const Icon(
                                      Icons.person_rounded,
                                      color: ReceptionTokens.teal,
                                      size: 18,
                                    ),
                                  ),
                                  validator: AppValidators.personName,
                                ),
                                const SizedBox(height: 10),
                                TextFormField(
                                  controller: _phone,
                                  keyboardType: TextInputType.phone,
                                  style: GoogleFonts.cairo(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                    color: _ink,
                                  ),
                                  inputFormatters: [IraqPhoneInputFormatter()],
                                  decoration: _fieldDeco(
                                    label: 'رقم الهاتف',
                                    hint: '07xxxxxxxxx',
                                    prefix: const Icon(
                                      Icons.phone_rounded,
                                      color: ReceptionTokens.teal,
                                      size: 18,
                                    ),
                                  ),
                                  validator: AppValidators.phone,
                                ),
                                const SizedBox(height: 10),
                                DropdownButtonFormField<String>(
                                  initialValue: _governorate,
                                  decoration: _fieldDeco(
                                    label: 'المحافظة',
                                    prefix: const Icon(
                                      Icons.location_on_rounded,
                                      color: ReceptionTokens.teal,
                                      size: 18,
                                    ),
                                  ),
                                  style: GoogleFonts.cairo(
                                    fontWeight: FontWeight.w700,
                                    color: _ink,
                                    fontSize: 13,
                                  ),
                                  dropdownColor: Colors.white,
                                  items: _governorates
                                      .map(
                                        (g) => DropdownMenuItem(
                                          value: g,
                                          child: Text(g),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (v) =>
                                      setState(() => _governorate = v),
                                  validator: (v) =>
                                      (v == null || v.isEmpty) ? 'مطلوب' : null,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          _section(
                            title: 'تفاصيل الحجز',
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  'مصدر الحجز',
                                  style: GoogleFonts.cairo(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: ReceptionTokens.navy
                                        .withValues(alpha: 0.55),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: BookingSource.values.map((s) {
                                    final active = _source == s;
                                    return Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        onTap: () =>
                                            setState(() => _source = s),
                                        borderRadius: BorderRadius.circular(10),
                                        child: AnimatedContainer(
                                          duration: const Duration(
                                              milliseconds: 160),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 7,
                                          ),
                                          decoration: BoxDecoration(
                                            borderRadius:
                                                BorderRadius.circular(10),
                                            color: active
                                                ? ReceptionTokens.plusBg
                                                : ReceptionTokens.bg,
                                            border: Border.all(
                                              color: active
                                                  ? ReceptionTokens.teal
                                                  : ReceptionTokens.fieldBorder,
                                              width: active ? 1.2 : 0.5,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              RAssets.source(s.api, size: 14),
                                              const SizedBox(width: 5),
                                              Text(
                                                s.label,
                                                style: GoogleFonts.cairo(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w800,
                                                  color: active
                                                      ? ReceptionTokens.teal
                                                      : _ink,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                                const SizedBox(height: 12),
                                Material(
                                  color: ReceptionTokens.bg,
                                  borderRadius: BorderRadius.circular(10),
                                  child: InkWell(
                                    onTap: _pickDate,
                                    borderRadius: BorderRadius.circular(10),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 10,
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 36,
                                            height: 36,
                                            decoration: BoxDecoration(
                                              color: ReceptionTokens.plusBg,
                                              borderRadius:
                                                  BorderRadius.circular(9),
                                            ),
                                            child: const Icon(
                                              Icons.calendar_month_rounded,
                                              color: ReceptionTokens.teal,
                                              size: 18,
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'تاريخ الحضور',
                                                  style: GoogleFonts.cairo(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w700,
                                                    color: ReceptionTokens.navy
                                                        .withValues(
                                                            alpha: 0.55),
                                                  ),
                                                ),
                                                Text(
                                                  formatDateTime(_visitDate),
                                                  style: GoogleFonts.cairo(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w800,
                                                    color: _ink,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Icon(
                                            Icons.chevron_left_rounded,
                                            color: ReceptionTokens.navy
                                                .withValues(alpha: 0.4),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                TextFormField(
                                  controller: _notes,
                                  maxLines: 2,
                                  style: GoogleFonts.cairo(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                    color: _ink,
                                  ),
                                  decoration: _fieldDeco(
                                    label: 'ملاحظة',
                                    hint: 'اختياري',
                                    prefix: const Icon(
                                      Icons.notes_rounded,
                                      color: ReceptionTokens.teal,
                                      size: 18,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            height: 46,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                gradient: const LinearGradient(
                                  colors: [
                                    ReceptionTokens.teal,
                                    ReceptionTokens.confirmBlue,
                                  ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: ReceptionTokens.teal
                                        .withValues(alpha: 0.35),
                                    blurRadius: 10,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: _saving ? null : _save,
                                  borderRadius: BorderRadius.circular(12),
                                  child: Center(
                                    child: _saving
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2.2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : Text(
                                            'حفظ الحجز',
                                            style: GoogleFonts.cairo(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w800,
                                              color: Colors.white,
                                            ),
                                          ),
                                  ),
                                ),
                              ),
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
        ),
      ),
    );
  }

  Widget _section({required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ReceptionTokens.fieldBorder, width: 0.5),
        boxShadow: ReceptionTokens.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: GoogleFonts.cairo(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: _ink,
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _DialogHeader extends StatelessWidget {
  const _DialogHeader({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'إضافة حجز جديد',
              style: GoogleFonts.cairo(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF123B70),
              ),
            ),
          ),
          Material(
            color: ReceptionTokens.plusBg,
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              onTap: onClose,
              borderRadius: BorderRadius.circular(10),
              child: const SizedBox(
                width: 36,
                height: 36,
                child: Icon(
                  Icons.close_rounded,
                  size: 20,
                  color: ReceptionTokens.navy,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
