import 'package:flutter/services.dart';

/// Formats whole-number input using Indonesian thousands separators.
///
/// This keeps the text field easy to read (`5000` becomes `5.000`) while
/// [parseThousandsSeparatedInt] converts it back to a value suitable for the
/// database.
class IndonesianThousandsSeparatorInputFormatter extends TextInputFormatter {
  const IndonesianThousandsSeparatorInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    digits = digits.replaceFirst(RegExp(r'^0+(?=\d)'), '');

    if (digits.isEmpty) {
      return const TextEditingValue();
    }

    final formatted = formatThousandsSeparatedInt(int.tryParse(digits) ?? 0);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

int? parseThousandsSeparatedInt(String? value) {
  final digits = (value ?? '').replaceAll(RegExp(r'[^0-9]'), '');
  return digits.isEmpty ? null : int.tryParse(digits);
}

String formatThousandsSeparatedInt(int value) {
  final digits = value.toString();
  final groups = <String>[];
  for (var end = digits.length; end > 0; end -= 3) {
    final start = end > 3 ? end - 3 : 0;
    groups.add(digits.substring(start, end));
  }
  return groups.reversed.join('.');
}
