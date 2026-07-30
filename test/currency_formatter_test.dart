import 'package:billing_app/core/utils/currency_formatter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('formats Indonesian Rupiah with dot thousand separators', () {
    expect(formatRupiah(12500), 'Rp 12.500');
    expect(formatRupiah(1000000), 'Rp 1.000.000');
  });
}
