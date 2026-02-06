import 'package:ocookie/ocookie.dart';
import 'package:test/test.dart';

void main() {
  group('Cookie.fromString', () {
    test('should parse set-cookie attributes', () {
      final cookie = Cookie.fromString(
        'sid=abc; Path=/; Domain=example.com; HttpOnly; Secure; SameSite=None; Max-Age=120; Priority=High; Partitioned',
      );

      expect(cookie.name, 'sid');
      expect(cookie.value, 'abc');
      expect(cookie.path, '/');
      expect(cookie.domain, 'example.com');
      expect(cookie.httpOnly, isTrue);
      expect(cookie.secure, isTrue);
      expect(cookie.sameSite, CookieSameSite.none);
      expect(cookie.maxAge, const Duration(seconds: 120));
      expect(cookie.priority, CookiePriority.high);
      expect(cookie.partitioned, isTrue);
    });

    test('should trim attribute values', () {
      final cookie =
          Cookie.fromString('a=b; Path= /demo ; Domain= example.com ');

      expect(cookie.path, '/demo');
      expect(cookie.domain, 'example.com');
    });

    test('should ignore invalid max-age and expires values', () {
      expect(
        () => Cookie.fromString('a=b; Max-Age=not-number; Expires=not-date'),
        returnsNormally,
      );

      final cookie =
          Cookie.fromString('a=b; Max-Age=not-number; Expires=not-date');
      expect(cookie.maxAge, isNull);
      expect(cookie.expires, isNull);
    });

    test('should parse quoted cookie values', () {
      final cookie = Cookie.fromString('a="hello%20world"');

      expect(cookie.value, 'hello world');
    });

    test('should throw for invalid first pair without equals', () {
      expect(
        () => Cookie.fromString('HttpOnly; Path=/'),
        throwsArgumentError,
      );
    });

    test('should throw for empty cookie name', () {
      expect(
        () => Cookie.fromString('=value; Path=/'),
        throwsArgumentError,
      );
    });
  });

  group('Cookie.splitSetCookie', () {
    test('should split values and keep Expires date intact', () {
      final values = Cookie.splitSetCookie(
        'a=b; Expires=Wed, 21 Oct 2015 07:28:00 GMT, c=d; Path=/',
      );

      expect(values, [
        'a=b; Expires=Wed, 21 Oct 2015 07:28:00 GMT',
        'c=d; Path=/',
      ]);
    });

    test('should trim optional whitespace around each cookie value', () {
      final values = Cookie.splitSetCookie('  a=b; Path=/  ,   c=d  ');

      expect(values, [
        'a=b; Path=/',
        'c=d',
      ]);
    });

    test('should ignore redundant separators and trailing commas', () {
      final values = Cookie.splitSetCookie('a=b,, c=d, ');

      expect(values, [
        'a=b',
        'c=d',
      ]);
    });
  });
}
