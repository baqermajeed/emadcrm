import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../controllers/customer_controller.dart';
import '../../core/api_client.dart';
import '../../core/reception_tokens.dart';
import '../../models/customer.dart';
import '../../models/deal.dart';
import '../../services/deal_service.dart';
import '../../utils/enums.dart';
import '../../utils/formatters.dart';
import '../../utils/validators.dart';
import '../../widgets/reception/reception_assets.dart';
import '../../widgets/staff_avatar.dart';

/// Modal matching the Figma deal dashboard — villa sidebar + form.
class CreateDealScreen extends StatefulWidget {
  const CreateDealScreen({super.key, required this.customer, this.deal});

  final Customer customer;
  final Deal? deal;

  bool get isEditing => deal != null;

  static Future<bool?> show(
    BuildContext context, {
    required Customer customer,
    Deal? deal,
  }) {
    return showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (_) => CreateDealScreen(customer: customer, deal: deal),
    );
  }

  @override
  State<CreateDealScreen> createState() => _CreateDealScreenState();
}

class _CreateDealScreenState extends State<CreateDealScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _email;
  late final TextEditingController _profession;
  late final TextEditingController _governorate;
  late final TextEditingController _area;
  late final TextEditingController _block;
  late final TextEditingController _houseNo;
  late final TextEditingController _price;
  late final TextEditingController _down;
  late final TextEditingController _notes;

  HowKnewCenter? _source;
  PaymentType _payment = PaymentType.cash;
  HouseType _houseType = HouseType.house;
  bool _saving = false;

  static const _blue = Color(0xFF1E6FD9);
  static const _navy = Color(0xFF0B3A5C);
  static const _formBg = Color(0xFFF5F8FC);
  static const _fieldBg = Color(0xFFF8FAFC);
  static const _border = Color(0xFFE2E8F0);

  @override
  void initState() {
    super.initState();
    final c = widget.customer;
    final d = widget.deal;
    _name = TextEditingController(text: d?.name ?? c.name);
    _phone = TextEditingController(text: d?.phone ?? c.phone);
    _email = TextEditingController(text: d?.email ?? c.email ?? '');
    _profession = TextEditingController(text: d?.profession ?? c.profession ?? '');
    _governorate = TextEditingController(text: c.address ?? '');
    _area = TextEditingController(
      text: d?.houseArea == null ? '' : d!.houseArea!.toStringAsFixed(0),
    );
    _block = TextEditingController(text: d?.residentialBlock ?? '');
    _houseNo = TextEditingController(text: d?.houseNumber ?? '');
    _price = TextEditingController(
      text: d == null ? '' : NumberFormat('#,##0', 'en').format(d.totalPrice.round()),
    );
    _down = TextEditingController(
      text: d == null ? '' : NumberFormat('#,##0', 'en').format(d.downPayment.round()),
    );
    _notes = TextEditingController(text: d?.notes ?? '');
    _source = c.howKnew;
    _payment = d?.paymentType ?? PaymentType.cash;
    _houseType = d?.houseType ?? HouseType.house;
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    _profession.dispose();
    _governorate.dispose();
    _area.dispose();
    _block.dispose();
    _houseNo.dispose();
    _price.dispose();
    _down.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final ctrl = context.read<CustomerController>();
    final body = DealService(context.read<ApiClient>()).buildBody(
      customerId: widget.customer.id,
      name: _name.text.trim(),
      phone: _phone.text.trim(),
      houseType: _houseType,
      profession: _profession.text.trim().isEmpty ? null : _profession.text.trim(),
      email: _email.text.trim().isEmpty ? null : _email.text.trim(),
      houseArea: double.tryParse(_area.text.trim()),
      residentialBlock: _block.text.trim().isEmpty ? null : _block.text.trim(),
      houseNumber: _houseNo.text.trim().isEmpty ? null : _houseNo.text.trim(),
      totalPrice: parseMoneyInput(_price.text)!,
      paymentType: _payment,
      downPayment: parseMoneyInput(_down.text)!,
      notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      salesEmployeeId:
          widget.deal?.salesEmployeeId ?? widget.customer.salesEmployeeId,
      saleDate: widget.deal?.saleDate,
    );
    final bool ok;
    if (widget.isEditing) {
      body.remove('customer_id');
      ok = await ctrl.updateDeal(widget.deal!.id, body);
    } else {
      ok = await ctrl.addDeal(body);
    }
    setState(() => _saving = false);
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ctrl.error ?? 'فشل الحفظ')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final maxW = (size.width - 48).clamp(320.0, 1100.0);
    final maxH = (size.height * 0.88).clamp(420.0, 900.0);
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Directionality(
        textDirection: ui.TextDirection.rtl,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Material(
            color: Colors.white,
            child: SizedBox(
              width: maxW,
              height: maxH,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: _formPanel()),
                  _sidebar(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _sidebar() {
    return SizedBox(
      width: 280,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            RAssets.dealVilla,
            fit: BoxFit.cover,
            alignment: Alignment.center,
            filterQuality: FilterQuality.medium,
            cacheWidth: 560,
            gaplessPlayback: true,
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x59000000),
                  Color(0x26000000),
                  Color(0x8C000000),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 22, 18, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.95),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.home_work_rounded, color: _blue, size: 24),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.isEditing ? 'تعديل صفقة البيع' : 'إضافة صفقة جديدة',
                            style: GoogleFonts.cairo(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              height: 1.2,
                            ),
                          ),
                          Text(
                            widget.isEditing
                                ? 'تعديل بيانات الصفقة وحفظ التغييرات'
                                : 'تسجيل صفقة بيع من العميل',
                            style: GoogleFonts.cairo(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontWeight: FontWeight.w600,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0B3A5C).withValues(alpha: 0.72),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.info_outline_rounded, color: Colors.white, size: 18),
                          const SizedBox(width: 6),
                          Text(
                            'معلومات مهمة',
                            style: GoogleFonts.cairo(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ..._tips.map(
                        (t) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '•  ',
                                style: GoogleFonts.cairo(color: Colors.white, fontSize: 12),
                              ),
                              Expanded(
                                child: Text(
                                  t,
                                  style: GoogleFonts.cairo(
                                    color: Colors.white.withValues(alpha: 0.95),
                                    fontWeight: FontWeight.w600,
                                    fontSize: 11,
                                    height: 1.35,
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
              ],
            ),
          ),
        ],
      ),
    );
  }

  static const _tips = [
    'تأكد من صحة بيانات العميل قبل الحفظ',
    'أدخل السعر الكلي وقيمة المقدمة بدقة',
    'حدد نوع الدفع وقيمة المقدمة',
    'يمكن إضافة ملاحظات إضافية أسفل النموذج',
  ];

  Widget _formPanel() {
    return ColoredBox(
      color: _formBg,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: _blue,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.sell_outlined, size: 18, color: Colors.white),
                      const SizedBox(width: 6),
                      Text(
                        widget.isEditing ? 'تعديل الصفقة' : 'إضافة صفقة',
                        style: GoogleFonts.cairo(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white,
                    side: const BorderSide(color: _border),
                  ),
                  icon: const Icon(Icons.close_rounded, color: _navy),
                ),
              ],
            ),
          ),
          Expanded(
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 4, 18, 12),
                children: [
                  _sectionCard(
                    icon: Icons.person_outline_rounded,
                    title: 'معلومات العميل',
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _labeledField(
                                'الاسم الكامل',
                                required: true,
                                child: _textField(
                                  controller: _name,
                                  icon: Icons.person_outline_rounded,
                                  hint: 'اسم العميل',
                                  inputFormatters: [PersonNameInputFormatter()],
                                  validator: AppValidators.personName,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _labeledField(
                                'رقم الهاتف',
                                required: true,
                                child: _textField(
                                  controller: _phone,
                                  icon: Icons.phone_outlined,
                                  hint: '07xxxxxxxxx',
                                  keyboardType: TextInputType.phone,
                                  inputFormatters: [IraqPhoneInputFormatter()],
                                  validator: AppValidators.phone,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _labeledField(
                                'المحافظة',
                                required: true,
                                child: _textField(
                                  controller: _governorate,
                                  icon: Icons.location_city_outlined,
                                  hint: 'المحافظة',
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _labeledField(
                                'البريد الإلكتروني',
                                child: _textField(
                                  controller: _email,
                                  icon: Icons.mail_outline_rounded,
                                  hint: 'email@example.com',
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _labeledField(
                                'المهنة',
                                required: true,
                                child: _textField(
                                  controller: _profession,
                                  icon: Icons.work_outline_rounded,
                                  hint: 'المهنة',
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _labeledField(
                                'مصدر الزبون',
                                required: true,
                                child: _dropdown<HowKnewCenter>(
                                  value: _source,
                                  hint: 'اختر المصدر',
                                  items: HowKnewCenter.values,
                                  labelOf: (e) => e.label,
                                  onChanged: (v) => setState(() => _source = v),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _dealSection(),
                  const SizedBox(height: 12),
                  _sectionCard(
                    icon: Icons.groups_outlined,
                    title: 'تعيين موظف',
                    child: Row(
                      children: [
                        Expanded(
                          child: _labeledField(
                            'موظف الكول سنتر',
                            child: _staffReadonlyBox(
                              name: widget.customer.callCenterName ?? '—',
                              avatarUrl: widget.customer.callCenterAvatarUrl,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _labeledField(
                            'موظف المبيعات',
                            child: _staffReadonlyBox(
                              name: widget.customer.salesEmployeeName ?? '—',
                              avatarUrl: widget.customer.salesEmployeeAvatarUrl,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _labeledField(
                            'نوع الدفع',
                            child: _dropdown<PaymentType>(
                              value: _payment,
                              items: PaymentType.values,
                              labelOf: (e) => e.label,
                              onChanged: (v) {
                                if (v != null) setState(() => _payment = v);
                              },
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
          Container(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 14),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: _border)),
            ),
            child: Row(
              children: [
                FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.save_rounded, size: 18),
                  label: Text(
                    widget.isEditing ? 'حفظ التعديلات' : 'حفظ الصفقة',
                    style: GoogleFonts.cairo(fontWeight: FontWeight.w800),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: _blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, size: 18),
                  label: Text('إلغاء', style: GoogleFonts.cairo(fontWeight: FontWeight.w800)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _blue,
                    side: BorderSide(color: _blue.withValues(alpha: 0.35)),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _dealSection() {
    return _sectionCard(
      icon: Icons.home_work_outlined,
      title: 'معلومات الصفقة',
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _labeledField(
                  'نوع العقار',
                  required: true,
                  child: _dropdown<HouseType>(
                    value: _houseType,
                    items: HouseType.values,
                    labelOf: (e) => e.label,
                    onChanged: (v) {
                      if (v != null) setState(() => _houseType = v);
                    },
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _labeledField(
                  'مساحة الدار',
                  child: _textField(
                    controller: _area,
                    icon: Icons.square_foot_rounded,
                    hint: 'م²',
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return null;
                      return double.tryParse(v.trim()) == null ? 'رقم' : null;
                    },
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _labeledField(
                  'المربع السكني',
                  child: _textField(
                    controller: _block,
                    icon: Icons.grid_view_rounded,
                    hint: 'المربع',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _labeledField(
                  'رقم الدار',
                  child: _textField(
                    controller: _houseNo,
                    icon: Icons.tag_rounded,
                    hint: 'الرقم',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _labeledField(
                  'السعر الكلي',
                  required: true,
                  child: _textField(
                    controller: _price,
                    icon: Icons.payments_outlined,
                    hint: '300,000,000',
                    keyboardType: TextInputType.number,
                    inputFormatters: [ThousandsSeparatorInputFormatter()],
                    validator: (v) => parseMoneyInput(v) == null ? 'رقم' : null,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _labeledField(
                  'قيمة المقدمة',
                  required: true,
                  child: _textField(
                    controller: _down,
                    icon: Icons.attach_money_rounded,
                    hint: '60,000,000',
                    keyboardType: TextInputType.number,
                    inputFormatters: [ThousandsSeparatorInputFormatter()],
                    validator: (v) => parseMoneyInput(v) == null ? 'رقم' : null,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(child: SizedBox.shrink()),
            ],
          ),
          const SizedBox(height: 12),
          _labeledField(
            'ملاحظات',
            child: _textField(
              controller: _notes,
              hint: 'اكتب ملاحظات الصفقة...',
              maxLines: 3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionCard({
    required IconData icon,
    required String title,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFDCEAF8)),
        boxShadow: [
          BoxShadow(
            color: ReceptionTokens.teal.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: _blue),
              const SizedBox(width: 8),
              Text(
                title,
                style: GoogleFonts.cairo(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  color: _navy,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _labeledField(String label, {required Widget child, bool required = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              label,
              style: GoogleFonts.cairo(
                fontWeight: FontWeight.w700,
                fontSize: 12,
                color: _navy,
              ),
            ),
            if (required)
              Text(
                ' *',
                style: GoogleFonts.cairo(
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                  color: const Color(0xFFEF4444),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }

  InputDecoration _dec({Widget? prefixIcon, String? hint}) {
    return InputDecoration(
      filled: true,
      fillColor: _fieldBg,
      hintText: hint,
      hintStyle: GoogleFonts.cairo(color: const Color(0xFF94A3B8), fontSize: 13),
      prefixIcon: prefixIcon,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _blue, width: 1.4),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFEF4444)),
      ),
    );
  }

  Widget _textField({
    required TextEditingController controller,
    IconData? icon,
    String? hint,
    int maxLines = 1,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      style: GoogleFonts.cairo(fontWeight: FontWeight.w600, fontSize: 13, color: _navy),
      validator: validator,
      decoration: _dec(
        hint: hint,
        prefixIcon: icon == null ? null : Icon(icon, size: 18, color: const Color(0xFF64748B)),
      ),
    );
  }

  Widget _staffReadonlyBox({required String name, String? avatarUrl}) {
    return InputDecorator(
      decoration: _dec(),
      child: Row(
        children: [
          StaffAvatar(avatarUrl: avatarUrl, radius: 14),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.cairo(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: _navy,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dropdown<T>({
    required T? value,
    required List<T> items,
    required String Function(T) labelOf,
    required ValueChanged<T?> onChanged,
    String? hint,
  }) {
    T? safeValue;
    if (value != null && items.contains(value)) {
      safeValue = value;
    }
    return DropdownButtonFormField<T>(
      initialValue: safeValue,
      isExpanded: true,
      decoration: _dec(),
      hint: hint == null
          ? null
          : Text(hint, style: GoogleFonts.cairo(color: const Color(0xFF94A3B8), fontSize: 13)),
      items: items
          .map(
            (e) => DropdownMenuItem<T>(
              value: e,
              child: Text(
                labelOf(e),
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.cairo(fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ),
          )
          .toList(),
      onChanged: onChanged,
    );
  }
}
