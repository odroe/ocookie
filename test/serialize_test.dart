import 'package:ocookie/ocookie.dart';
import 'package:test/test.dart';

void main() {
  group('Cookie.validate', () {
    test('should return empty list for valid cookie', () {
      expect(
        Cookie(
          'sid',
          'abc',
          secure: true,
          sameSite: CookieSameSite.none,
          partitioned: true,
        ).validate(),
        isEmpty,
      );
    });

    test('should collect multiple validation errors', () {
      final errors = Cookie(
        'bad\nname',
        'value',
        path: '/bad\npath',
        domain: 'bad\ndomain',
        sameSite: CookieSameSite.none,
        partitioned: true,
      ).validate();

      expect(errors, contains('argument name is invalid'));
      expect(errors, contains('path is invalid'));
      expect(errors, contains('domain is invalid'));
      expect(
        errors,
        contains(
          'SameSite attribute is set to none, but the secure flag is not set to true.',
        ),
      );
      expect(
        errors,
        contains(
          'Partitioned attribute is set, but the secure flag is not set to true.',
        ),
      );
    });

    test('should return encode failures as validation errors', () {
      final errors = Cookie('a', 'b').validate(
        encode: (_) => throw StateError('boom'),
      );

      expect(errors, hasLength(1));
      expect(errors.first, startsWith('failed to encode value:'));
    });
  });

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

    test('should throw when Partitioned without Secure', () {
      expect(
        () => Cookie('foo', 'bar', partitioned: true).serialize(),
        throwsA(isA<StateError>()),
      );
    });

    test('should serialize Partitioned with Secure', () {
      expect(
        Cookie('foo', 'bar', partitioned: true, secure: true).serialize(),
        'foo=bar; Secure; Partitioned',
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
