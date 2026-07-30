import 'package:intl/intl.dart';

/// Formats monetary values as Indonesian Rupiah, for example: Rp 25.000.
String formatRupiah(num amount) {
  return NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  ).format(amount);
}
