import 'dart:math';

import 'package:ocookie/ocookie.dart';
import 'package:test/test.dart';

void main() {
  group('Fuzz regression', () {
    test('Cookie.parse and Cookie.splitSetCookie should not throw', () {
      final random = Random(20260206);
      for (var i = 0; i < 5000; i++) {
        final input = randomInput(random, 100);
        try {
          Cookie.parse(input);
          Cookie.splitSetCookie(input);
        } catch (error) {
          fail('unexpected error at iteration $i for <$input>: $error');
        }
      }
    });

    test('Cookie.fromString should only throw ArgumentError on malformed input',
        () {
      final random = Random(20260206);
      for (var i = 0; i < 5000; i++) {
        final input = randomInput(random, 100);
        try {
          Cookie.fromString(input);
        } catch (error) {
          if (error is! ArgumentError) {
            fail(
              'unexpected ${error.runtimeType} at iteration $i for <$input>: $error',
            );
          }
        }
      }
    });
  });
}

String randomInput(Random random, int maxLen) {
  const chars =
      'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789=;,:" %\t\n\r-_/.';
  final len = random.nextInt(maxLen + 1);

  return String.fromCharCodes(
    List.generate(
      len,
      (_) => chars.codeUnitAt(random.nextInt(chars.length)),
    ),
  );
}
