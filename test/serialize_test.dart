import 'package:ocookie/ocookie.dart';
import 'package:test/test.dart';

void main() {
  group('Cookie.serialize', () {
    test('should serialize name and value', () {
      expect(Cookie('foo', 'bar').serialize(), 'foo=bar');
    });

    test('should URL-encode value', () {
      expect(Cookie('foo', 'bar +baz').serialize(), 'foo=bar%20%2Bbaz');
    });

    test('should serialize empty value', () {
      expect(Cookie('foo', '').serialize(), 'foo=');
    });

    test('should allow SameSite=Strict without Secure', () {
      expect(
        Cookie('foo', 'bar', sameSite: CookieSameSite.strict).serialize(),
        'foo=bar; SameSite=Strict',
      );
    });

    test('should throw when SameSite=None without Secure', () {
      expect(
        () => Cookie('foo', 'bar', sameSite: CookieSameSite.none).serialize(),
        throwsA(isA<StateError>()),
      );
    });

    test('should serialize SameSite=None with Secure', () {
      expect(
        Cookie(
          'foo',
          'bar',
          sameSite: CookieSameSite.none,
          secure: true,
        ).serialize(),
        'foo=bar; Secure; SameSite=None',
      );
    });

    test('should throw for invalid name', () {
      expect(
        () => Cookie('name\n', 'value').serialize(),
        throwsA(isA<Error>()),
      );
      expect(
        () => Cookie('name\u{280a}', 'value').serialize(),
        throwsA(isA<Error>()),
      );
    });

    group('options', () {
      group('with domain', () {
        test('should serialize domain', () {
          expect(
            Cookie('a', 'b', domain: 'odroe.dev').serialize(),
            'a=b; Domain=odroe.dev',
          );
        });

        test('should throw for invalid value', () {
          expect(
            () => Cookie('a', 'b', domain: 'a.b\n').serialize(),
            throwsArgumentError,
          );
        });
      });

      group('with path', () {
        test('should serialize path', () {
          expect(
            Cookie('a', 'b', path: '/demo').serialize(),
            'a=b; Path=/demo',
          );
        });

        test('should allow legal special characters in path', () {
          expect(
            Cookie('a', 'b', path: '/v1:users?active=true').serialize(),
            'a=b; Path=/v1:users?active=true',
          );
        });

        test('should throw for invalid value', () {
          expect(
            () => Cookie('a', 'b', path: '/demo\n').serialize(),
            throwsArgumentError,
          );
        });
      });
    });
  });
}
