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
      expect(cookie.httpOnly, isFalse);
      expect(cookie.secure, isFalse);
      expect(cookie.partitioned, isFalse);
    });

    test('should preserve quoted values containing equals signs', () {
      final cookie = Cookie.fromString('session="a=b=c%202"');

      expect(cookie.value, 'a=b=c 2');
    });

    test('should ignore unknown attributes from real-world headers', () {
      final cookie = Cookie.fromString(
        'sid=abc123; Path=/; HttpOnly; Secure; SameSite=None; Foo=bar; Version=1',
      );

      expect(cookie.name, 'sid');
      expect(cookie.value, 'abc123');
      expect(cookie.path, '/');
      expect(cookie.httpOnly, isTrue);
      expect(cookie.secure, isTrue);
      expect(cookie.sameSite, CookieSameSite.none);
      expect(cookie.priority, isNull);
    });

    test('should keep the last repeated recognized attribute', () {
      final cookie = Cookie.fromString(
        'sid=abc; Path=/one; Path=/two; SameSite=Lax; SameSite=None; Secure',
      );

      expect(cookie.path, '/two');
      expect(cookie.sameSite, CookieSameSite.none);
      expect(cookie.secure, isTrue);
    });

    test('should treat valueless flags with non-standard values as enabled',
        () {
      final cookie = Cookie.fromString(
        'sid=abc; Secure=1; HttpOnly=true; Partitioned=?1',
      );

      expect(cookie.secure, isTrue);
      expect(cookie.httpOnly, isTrue);
      expect(cookie.partitioned, isTrue);
    });

    test('should ignore invalid recognized attribute values without failing',
        () {
      final cookie = Cookie.fromString(
        'sid=abc; SameSite=invalid; Priority=urgent; Secure',
      );

      expect(cookie.sameSite, isNull);
      expect(cookie.priority, isNull);
      expect(cookie.secure, isTrue);
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

    test('should split combined headers with quoted commas and expires dates',
        () {
      final values = Cookie.splitSetCookie(
        'a="b,c"; Path=/, sid=1; Expires=Wed, 21 Oct 2015 07:28:00 GMT; HttpOnly, theme=light',
      );

      expect(values, [
        'a="b,c"; Path=/',
        'sid=1; Expires=Wed, 21 Oct 2015 07:28:00 GMT; HttpOnly',
        'theme=light',
      ]);
    });
  });
}
