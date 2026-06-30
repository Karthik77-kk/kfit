import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kfit/widgets/input_formatters.dart';

/// Hard numeric input guards: positive numbers only, no letters/sign, decimals
/// limited to a single '.'.
void main() {
  TextEditingValue val(String s) =>
      TextEditingValue(text: s, selection: TextSelection.collapsed(offset: s.length));

  String apply(TextInputFormatter f, String oldText, String newText) =>
      f.formatEditUpdate(val(oldText), val(newText)).text;

  group('positiveDecimalInput', () {
    final f = positiveDecimalInput.first;
    test('accepts digits and a single decimal point', () {
      expect(apply(f, '72', '72.'), '72.');
      expect(apply(f, '72.', '72.5'), '72.5');
      expect(apply(f, '', '0.25'), '0.25');
    });
    test('rejects a second dot, letters and signs (keeps prior text)', () {
      expect(apply(f, '72.5', '72.5.'), '72.5'); // second dot blocked
      expect(apply(f, '72', '72a'), '72');        // letter blocked
      expect(apply(f, '', '-5'), '');             // minus blocked
      expect(apply(f, '5', '5 '), '5');           // space blocked
    });
  });

  group('positiveIntInput', () {
    final f = positiveIntInput.first;
    test('strips anything that is not a digit', () {
      expect(apply(f, '', '123'), '123');
      expect(apply(f, '12', '12a3'), '123');
      expect(apply(f, '', '-5'), '5');
      expect(apply(f, '', '7.5'), '75');
    });
  });
}
