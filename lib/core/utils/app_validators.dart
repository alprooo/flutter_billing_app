import 'thousands_separator_input_formatter.dart';

class AppValidators {
  static String? Function(String?) required(String message) {
    return (String? value) {
      if (value == null || value.trim().isEmpty) {
        return message;
      }
      return null;
    };
  }

  static String? price(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Masukkan harga';
    }
    final price = parseThousandsSeparatedInt(value);
    if (price == null) {
      return 'Masukkan angka yang valid';
    }
    if (price < 0) {
      return 'Harga tidak boleh negatif';
    }
    return null;
  }
}
