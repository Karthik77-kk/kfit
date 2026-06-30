import 'package:flutter/services.dart';

/// Hard input guards for numeric fields — block anything that isn't a positive
/// number, so letters, spaces, minus signs and stray symbols can't be typed OR
/// pasted (the keyboard hint alone doesn't stop paste / hardware keyboards).

/// Allows only digits and a single leading-or-mid decimal point (e.g. "72.5").
/// No sign, no letters, at most one '.'.
class _PositiveDecimalFormatter extends TextInputFormatter {
  static final _ok = RegExp(r'^\d*\.?\d*$');
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    return _ok.hasMatch(newValue.text) ? newValue : oldValue;
  }
}

/// For decimals (weight, grams, protein, %, cm…): digits + one '.'.
final List<TextInputFormatter> positiveDecimalInput = <TextInputFormatter>[
  _PositiveDecimalFormatter(),
];

/// For whole numbers (age, steps, reps, ml, kcal, barcode…): digits only.
final List<TextInputFormatter> positiveIntInput = <TextInputFormatter>[
  FilteringTextInputFormatter.digitsOnly,
];
