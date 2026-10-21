import 'package:flutter/services.dart';

/// Shared field rules used across the whole app.
class AppValidators {
  AppValidators._();

  /// Arabic + Latin letters and spaces only.
  static final RegExp nameChars = RegExp(
    r'^[\p{L}\s]+$',
    unicode: true,
  );

  /// Iraqi mobile: 11 digits starting with 07.
  static final RegExp iraqMobile = RegExp(r'^07\d{9}$');

  static String? personName(String? value, {bool required = true}) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return required ? 'الاسم مطلوب' : null;
    if (v.length < 2) return 'الاسم يجب أن يكون حرفين على الأقل';
    if (!nameChars.hasMatch(v) || RegExp(r'\d').hasMatch(v)) {
      return 'الاسم يجب أن يكون حروفاً فقط';
    }
    return null;
  }

  static String? phone(String? value, {bool required = true}) {
    final v = (value ?? '').replaceAll(RegExp(r'[\s\-]'), '');
    if (v.isEmpty) return required ? 'رقم الهاتف مطلوب' : null;
    if (!iraqMobile.hasMatch(v)) {
      return 'رقم الهاتف يجب أن يكون 11 رقماً ويبدأ بـ 07';
    }
    return null;
  }

  /// True when value is a valid person name (letters only).
  static bool isPersonName(String value) => personName(value) == null;

  /// True when value is a valid Iraqi mobile.
  static bool isPhone(String value) => phone(value) == null;
}

/// Blocks digits and symbols; keeps letters and spaces.
class PersonNameInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final filtered = StringBuffer();
    for (final rune in newValue.text.runes) {
      final ch = String.fromCharCode(rune);
      if (RegExp(r'\p{L}', unicode: true).hasMatch(ch) || ch == ' ') {
        filtered.write(ch);
      }
    }
    final text = filtered.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

/// Digits only, max 11 (Iraqi mobile).
class IraqPhoneInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final clipped = digits.length > 11 ? digits.substring(0, 11) : digits;
    return TextEditingValue(
      text: clipped,
      selection: TextSelection.collapsed(offset: clipped.length),
    );
  }
}
