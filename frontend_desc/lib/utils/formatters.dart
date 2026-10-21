import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../models/user.dart';

final _date = DateFormat('yyyy/MM/dd', 'ar');
final _dateTime = DateFormat('yyyy/MM/dd hh:mm a', 'ar');
final _money = NumberFormat('#,##0', 'en');

/// Prefer full name; fall back to username.
String displayUserName(AppUser? user) {
  if (user == null) return '';
  final name = user.fullName.trim();
  return name.isNotEmpty ? name : user.username;
}

String formatDate(DateTime? value) {
  if (value == null) return '—';
  return _date.format(value.toLocal());
}

String formatDateTime(DateTime? value) {
  if (value == null) return '—';
  return _dateTime.format(value.toLocal());
}

String formatMoney(num? value) {
  if (value == null) return '0';
  return '${_money.format(value)} د.ع';
}

/// Digits only after stripping thousand separators (`,` or Arabic `،`).
double? parseMoneyInput(String? raw) {
  if (raw == null) return null;
  final cleaned = raw.replaceAll(RegExp(r'[,،\s]'), '');
  if (cleaned.isEmpty) return null;
  return double.tryParse(cleaned);
}

/// Inserts thousand separators while typing (e.g. 300000000 → 300,000,000).
class ThousandsSeparatorInputFormatter extends TextInputFormatter {
  final NumberFormat _fmt = NumberFormat('#,##0', 'en');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) {
      return const TextEditingValue(text: '', selection: TextSelection.collapsed(offset: 0));
    }
    final number = int.tryParse(digits);
    if (number == null) return oldValue;
    final formatted = _fmt.format(number);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
