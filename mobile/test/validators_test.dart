import 'package:flutter_test/flutter_test.dart';
import 'package:iniba/core/utils/validators.dart';

void main() {
  group('email', () {
    test(
      'accepts IBA email',
      () => expect(Validators.email('sara@khi.iba.edu.pk'), isNull),
    );
    test(
      'rejects gmail',
      () => expect(Validators.email('sara@gmail.com'), isNotNull),
    );
    test('rejects empty', () => expect(Validators.email(''), isNotNull));
    test(
      'rejects domain only',
      () => expect(Validators.email('@khi.iba.edu.pk'), isNotNull),
    );
  });
  group('password', () {
    test('rejects short', () => expect(Validators.password('abc'), isNotNull));
    test('accepts 8+', () => expect(Validators.password('abcdefgh'), isNull));
  });
  group('confirm', () {
    test(
      'mismatch',
      () => expect(
        Validators.confirmPassword('a', 'b'),
        'Passwords do not match.',
      ),
    );
    test(
      'match',
      () => expect(Validators.confirmPassword('abcdefgh', 'abcdefgh'), isNull),
    );
  });
}
