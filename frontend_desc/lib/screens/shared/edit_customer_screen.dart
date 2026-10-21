import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../controllers/customer_controller.dart';
import '../../core/api_client.dart';
import '../../core/reception_tokens.dart';
import '../../models/customer.dart';
import '../../models/user.dart';
import '../../services/user_service.dart';
import '../../utils/enums.dart';
import '../../utils/validators.dart';
import '../../widgets/reception/reception_assets.dart';

class EditCustomerScreen extends StatefulWidget {
  const EditCustomerScreen({super.key, this.customer});

  final Customer? customer;

  bool get isEditing => customer != null;

  static Future<bool?> show(BuildContext context, {required Customer customer}) {
    return showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (_) => EditCustomerScreen(customer: customer),
    );
  }

  static Future<bool?> showAdd(BuildContext context) {
    return showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (_) => const EditCustomerScreen(),
    );
  }

  @override
  State<EditCustomerScreen> createState() => _EditCustomerScreenState();
}

class _EditCustomerScreenState extends State<EditCustomerScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _email;
  late final TextEditingController _profession;
  late final TextEditingController _address;
  late final TextEditingController _referral;
  late final TextEditingController _notes;
  HowKnewCenter? _howKnew;
  CustomerGender _gender = CustomerGender.male;
  String? _salesId;
  List<AppUser> _sales = [];
  bool _saving = false;

  static const _navy = Color(0xFF002E45);
  static const _fieldBg = Color(0xFFF6FCFF);
  static const _muted = Color(0xFF718096);

  @override
  void initState() {
    super.initState();
    final c = widget.customer;
    _name = TextEditingController(text: c?.name ?? '');
    _phone = TextEditingController(text: c?.phone ?? '');
    _email = TextEditingController(text: c?.email ?? '');
    _profession = TextEditingController(text: c?.profession ?? '');
    _address = TextEditingController(text: c?.address ?? '');
    _referral = TextEditingController(text: c?.referralBuyerName ?? '');
    _notes = TextEditingController(text: c?.notes ?? '');
    _howKnew = c?.howKnew;
    _gender = c?.gender ?? CustomerGender.male;
    _salesId = c?.salesEmployeeId;
    _loadSales();
  }

  Future<void> _loadSales() async {
    try {
      _sales = await UserService(context.read<ApiClient>()).list(role: UserRole.sales);
      if (mounted) setState(() {});
    } catch (_) {}
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    _profession.dispose();
    _address.dispose();
    _referral.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final fields = {
      'name': _name.text.trim(),
      'phone': _phone.text.trim(),
      'email': _email.text.trim(),
      'gender': _gender,
      'profession': _profession.text.trim(),
      'address': _address.text.trim(),
      'howKnew': _howKnew,
      'referralBuyerName': _referral.text.trim(),
      'salesEmployeeId': _salesId,
      'notes': _notes.text.trim(),
    };
    final ctrl = context.read<CustomerController>();
    final ok = widget.isEditing
        ? await ctrl.updateSelected(fields)
        : (await ctrl.create(fields)) != null;
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) {
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ctrl.error ?? 'فشلت العملية')),
      );
    }
  }

  InputDecoration _decoration({String? hint}) {
    return InputDecoration(
      filled: true,
      fillColor: _fieldBg,
      hintText: hint,
      hintStyle: GoogleFonts.cairo(color: _muted, fontWeight: FontWeight.w600, fontSize: 13),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: _navy.withValues(alpha: 0.12)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: _navy.withValues(alpha: 0.12)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: ReceptionTokens.teal, width: 1.4),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFEF4444)),
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          text,
          style: GoogleFonts.cairo(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: _navy,
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      child: Directionality(
        textDirection: ui.TextDirection.rtl,
        child: Container(
          width: 720,
          constraints: BoxConstraints(maxHeight: size.height * 0.88),
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
              // Header
              Container(
                padding: const EdgeInsets.fromLTRB(20, 14, 12, 14),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerRight,
                    end: Alignment.centerLeft,
                    colors: [Color(0xFF002E45), Color(0xFF014A6B)],
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: RAssets.profileIcon(RAssets.statStatus, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.isEditing ? 'تعديل بيانات الزبون' : 'إضافة زبون جديد',
                            style: GoogleFonts.cairo(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            widget.isEditing
                                ? (widget.customer?.name ?? '')
                                : 'أدخل بيانات الزبون الجديد',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.cairo(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withValues(alpha: 0.75),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded, color: Colors.white),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: Form(
                  key: _formKey,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(22, 20, 22, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _label('الاسم'),
                                  TextFormField(
                                    controller: _name,
                                    style: _fieldStyle(),
                                    inputFormatters: [PersonNameInputFormatter()],
                                    decoration: _decoration(hint: 'اسم الزبون'),
                                    validator: AppValidators.personName,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _label('الهاتف'),
                                  TextFormField(
                                    controller: _phone,
                                    style: _fieldStyle(),
                                    keyboardType: TextInputType.phone,
                                    inputFormatters: [IraqPhoneInputFormatter()],
                                    decoration: _decoration(hint: '07xxxxxxxxx'),
                                    validator: AppValidators.phone,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _label('البريد الإلكتروني'),
                                  TextFormField(
                                    controller: _email,
                                    style: _fieldStyle(),
                                    keyboardType: TextInputType.emailAddress,
                                    decoration: _decoration(hint: 'email@example.com'),
                                    validator: (v) {
                                      final value = v?.trim() ?? '';
                                      if (value.isEmpty) return null;
                                      if (!value.contains('@') || !value.contains('.')) {
                                        return 'بريد غير صالح';
                                      }
                                      return null;
                                    },
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _label('الجنس'),
                                  DropdownButtonFormField<CustomerGender>(
                                    initialValue: _gender,
                                    decoration: _decoration(),
                                    style: _fieldStyle(),
                                    items: CustomerGender.values
                                        .map(
                                          (e) => DropdownMenuItem(
                                            value: e,
                                            child: Text(e.label, style: _fieldStyle()),
                                          ),
                                        )
                                        .toList(),
                                    onChanged: (v) {
                                      if (v != null) setState(() => _gender = v);
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _label('المهنة'),
                                  TextFormField(
                                    controller: _profession,
                                    style: _fieldStyle(),
                                    decoration: _decoration(hint: 'المهنة'),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _label('عنوان السكن'),
                                  TextFormField(
                                    controller: _address,
                                    style: _fieldStyle(),
                                    decoration: _decoration(hint: 'العنوان'),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _label('موظف المبيعات'),
                                  DropdownButtonFormField<String>(
                                    initialValue: _salesId,
                                    decoration: _decoration(hint: 'اختر الموظف'),
                                    style: _fieldStyle(),
                                    items: _sales
                                        .map(
                                          (u) => DropdownMenuItem(
                                            value: u.id,
                                            child: Text(u.fullName, style: _fieldStyle()),
                                          ),
                                        )
                                        .toList(),
                                    onChanged: (v) => setState(() => _salesId = v),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _label('من أين عرفت المركز'),
                                  DropdownButtonFormField<HowKnewCenter>(
                                    initialValue: _howKnew,
                                    decoration: _decoration(hint: 'اختر المصدر'),
                                    style: _fieldStyle(),
                                    items: HowKnewCenter.values
                                        .map(
                                          (e) => DropdownMenuItem(
                                            value: e,
                                            child: Text(e.label, style: _fieldStyle()),
                                          ),
                                        )
                                        .toList(),
                                    onChanged: (v) => setState(() => _howKnew = v),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (_howKnew == HowKnewCenter.buyerReferral) ...[
                          const SizedBox(height: 14),
                          _label('اسم المشتري'),
                          TextFormField(
                            controller: _referral,
                            style: _fieldStyle(),
                            inputFormatters: [PersonNameInputFormatter()],
                            decoration: _decoration(hint: 'اسم المشتري المُحيل'),
                            validator: (v) => AppValidators.personName(v, required: false),
                          ),
                        ],
                        const SizedBox(height: 14),
                        _label('ملاحظات'),
                        TextFormField(
                          controller: _notes,
                          maxLines: 3,
                          style: _fieldStyle(),
                          decoration: _decoration(hint: 'اكتب ملاحظاتك هنا...'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 10, 22, 18),
                child: Row(
                  children: [
                    Expanded(
                      child: FilledButton(
                        onPressed: _saving ? null : _save,
                        style: FilledButton.styleFrom(
                          backgroundColor: _navy,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: _navy.withValues(alpha: 0.5),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: _saving
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                widget.isEditing ? 'حفظ التعديلات' : 'إضافة الزبون',
                                style: GoogleFonts.cairo(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _saving ? null : () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _navy,
                          side: BorderSide(color: _navy.withValues(alpha: 0.2)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'إلغاء',
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

  TextStyle _fieldStyle() => GoogleFonts.cairo(
        fontWeight: FontWeight.w700,
        fontSize: 13,
        color: _navy,
      );
}
