import 'package:ocookie/ocookie.dart';
import 'package:test/test.dart';

void main() {
  group('Cookie.copyWith', () {
    final expires = DateTime.utc(2026, 1, 1, 0, 0, 0);
    final cookie = Cookie(
      'sid',
      'abc',
      expires: expires,
      domain: 'example.com',
      httpOnly: true,
      maxAge: const Duration(seconds: 60),
      path: '/demo',
      priority: CookiePriority.high,
      sameSite: CookieSameSite.lax,
      secure: true,
      partitioned: true,
    );

    test('should preserve all nullable fields when omitted', () {
      final result = cookie.copyWith();

      expect(result.name, cookie.name);
      expect(result.value, cookie.value);
      expect(result.expires, cookie.expires);
      expect(result.domain, cookie.domain);
      expect(result.httpOnly, cookie.httpOnly);
      expect(result.maxAge, cookie.maxAge);
      expect(result.path, cookie.path);
      expect(result.priority, cookie.priority);
      expect(result.sameSite, cookie.sameSite);
      expect(result.secure, cookie.secure);
      expect(result.partitioned, cookie.partitioned);
    });

    test('should allow overriding values', () {
      final result = cookie.copyWith(
        name: 'token',
        value: 'xyz',
        secure: false,
        httpOnly: false,
        sameSite: CookieSameSite.none,
      );

      expect(result.name, 'token');
      expect(result.value, 'xyz');
      expect(result.secure, isFalse);
      expect(result.httpOnly, isFalse);
      expect(result.sameSite, CookieSameSite.none);
    });

    test('should allow clearing nullable fields via clear set', () {
      final result = cookie.copyWith(
        clear: {
          CookieNullableField.expires,
          CookieNullableField.domain,
          CookieNullableField.httpOnly,
          CookieNullableField.maxAge,
          CookieNullableField.path,
          CookieNullableField.priority,
          CookieNullableField.sameSite,
          CookieNullableField.secure,
          CookieNullableField.partitioned,
        },
      );

      expect(result.expires, isNull);
      expect(result.domain, isNull);
      expect(result.httpOnly, isNull);
      expect(result.maxAge, isNull);
      expect(result.path, isNull);
      expect(result.priority, isNull);
      expect(result.sameSite, isNull);
      expect(result.secure, isNull);
      expect(result.partitioned, isNull);
    });

    test('should throw when a field is set and cleared together', () {
      expect(
        () => cookie.copyWith(
          path: '/next',
          clear: {CookieNullableField.path},
        ),
        throwsArgumentError,
      );
    });
  });

  group('Cookie equality', () {
    test('should compare by value', () {
      final a = Cookie(
        'sid',
        'abc',
        path: '/',
        secure: true,
        sameSite: CookieSameSite.none,
      );
      final b = Cookie(
        'sid',
        'abc',
        path: '/',
        secure: true,
        sameSite: CookieSameSite.none,
      );

      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });
  });
}
