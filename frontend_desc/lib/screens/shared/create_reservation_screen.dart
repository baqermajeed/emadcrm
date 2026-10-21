import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/customer_controller.dart';
import '../../models/customer.dart';
import '../../utils/enums.dart';
import '../../utils/formatters.dart';
import '../../utils/validators.dart';

class CreateReservationScreen extends StatefulWidget {
  const CreateReservationScreen({super.key, required this.customer});

  final Customer customer;

  @override
  State<CreateReservationScreen> createState() => _CreateReservationScreenState();
}

class _CreateReservationScreenState extends State<CreateReservationScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  final _area = TextEditingController();
  final _block = TextEditingController();
  final _houseNo = TextEditingController();
  final _price = TextEditingController();
  final _down = TextEditingController();
  final _notes = TextEditingController();
  PaymentType _payment = PaymentType.cash;
  DateTime _deadline = DateTime.now().add(const Duration(days: 14));
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.customer.name);
  }

  @override
  void dispose() {
    _name.dispose();
    _area.dispose();
    _block.dispose();
    _houseNo.dispose();
    _price.dispose();
    _down.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickDeadline() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _deadline,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (date != null) setState(() => _deadline = date);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final ok = await context.read<CustomerController>().addReservation(
          name: _name.text.trim(),
          houseArea: double.parse(_area.text.trim()),
          residentialBlock: _block.text.trim(),
          houseNumber: _houseNo.text.trim(),
          totalPrice: double.parse(_price.text.trim()),
          paymentType: _payment,
          downPayment: double.parse(_down.text.trim()),
          completionDeadline: _deadline,
          notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
          salesEmployeeId: widget.customer.salesEmployeeId,
        );
    setState(() => _saving = false);
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.read<CustomerController>().error ?? 'فشل الحفظ')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('حجز دار')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _name,
              inputFormatters: [PersonNameInputFormatter()],
              decoration: const InputDecoration(labelText: 'الاسم'),
              validator: AppValidators.personName,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _area,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'المساحة'),
              validator: (v) => double.tryParse(v ?? '') == null ? 'رقم' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _block,
              decoration: const InputDecoration(labelText: 'المربع السكني'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'مطلوب' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _houseNo,
              decoration: const InputDecoration(labelText: 'رقم الدار'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'مطلوب' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _price,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'السعر الكلي'),
              validator: (v) => double.tryParse(v ?? '') == null ? 'رقم' : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<PaymentType>(
              initialValue: _payment,
              decoration: const InputDecoration(labelText: 'نوع الدفع'),
              items: PaymentType.values
                  .map((e) => DropdownMenuItem(value: e, child: Text(e.label)))
                  .toList(),
              onChanged: (v) => setState(() => _payment = v ?? _payment),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _down,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'قيمة المقدمة'),
              validator: (v) => double.tryParse(v ?? '') == null ? 'رقم' : null,
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('موعد إكمال الحجز'),
              subtitle: Text(formatDate(_deadline)),
              trailing: const Icon(Icons.event),
              onTap: _pickDeadline,
            ),
            TextFormField(
              controller: _notes,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'ملاحظات أخرى'),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _saving ? null : _save,
              child: const Text('حفظ الحجز'),
            ),
          ],
        ),
      ),
    );
  }
}
