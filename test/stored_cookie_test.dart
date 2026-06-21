import 'package:ocookie/ocookie.dart';
import 'package:test/test.dart';

void main() {
  group('StoredCookie.fromSetCookie', () {
    test('normalizes host-only cookies against the request host', () {
      final stored = StoredCookie.fromSetCookie(
        'sid=abc; HttpOnly',
        requestUri: Uri.parse('https://example.com/login'),
      );

      expect(stored.cookie.name, 'sid');
      expect(stored.cookie.value, 'abc');
      expect(stored.cookie.domain, isNull);
      expect(stored.domain, 'example.com');
      expect(stored.path, '/');
      expect(stored.hostOnly, isTrue);
      expect(stored.expiresAt, isNull);
      expect(stored.creationTime, stored.lastAccessTime);
      expect(stored.matches(Uri.parse('https://example.com/profile')), isTrue);
      expect(
        stored.matches(Uri.parse('https://sub.example.com/profile')),
        isFalse,
      );
    });

    test('normalizes domain attributes and matches subdomains', () {
      final stored = StoredCookie.fromSetCookie(
        'sid=abc; Domain=.Example.COM; Path=/; Secure',
        requestUri: Uri.parse('https://api.example.com./login'),
      );

      expect(stored.cookie.domain, 'example.com');
      expect(stored.domain, 'example.com');
      expect(stored.hostOnly, isFalse);
      expect(stored.matches(Uri.parse('https://example.com/profile')), isTrue);
      expect(
        stored.matches(Uri.parse('https://sub.example.com/profile')),
        isTrue,
      );
      expect(
        stored.matches(Uri.parse('https://other.example/profile')),
        isFalse,
      );
      expect(
        stored.matches(Uri.parse('http://example.com/profile')),
        isFalse,
      );
    });

    test('rejects domain attributes with trailing dots', () {
      expect(
        () => StoredCookie.fromSetCookie(
          'sid=abc; Domain=example.com.',
          requestUri: Uri.parse('https://example.com/login'),
        ),
        throwsArgumentError,
      );
    });

    test('rejects secure cookies from insecure request URIs', () {
      expect(
        () => StoredCookie.fromSetCookie(
          'sid=abc; Secure',
          requestUri: Uri.parse('http://example.com/login'),
        ),
        throwsArgumentError,
      );
    });

    test('enforces __Secure- cookie-name prefix constraints', () {
      expect(
        () => StoredCookie.fromSetCookie(
          '__Secure-sid=abc',
          requestUri: Uri.parse('https://example.com/login'),
        ),
        throwsArgumentError,
      );
      expect(
        () => StoredCookie.fromSetCookie(
          '__Secure-sid=abc; Secure',
          requestUri: Uri.parse('http://example.com/login'),
        ),
        throwsArgumentError,
      );

      final stored = StoredCookie.fromSetCookie(
        '__Secure-sid=abc; Secure',
        requestUri: Uri.parse('https://example.com/login'),
      );
      expect(stored.cookie.name, '__Secure-sid');
    });

    test('enforces __Host- cookie-name prefix constraints', () {
      final valid = StoredCookie.fromSetCookie(
        '__Host-sid=abc; Secure; Path=/',
        requestUri: Uri.parse('https://example.com/login'),
      );
      expect(valid.hostOnly, isTrue);
      expect(valid.path, '/');

      for (final value in [
        '__Host-sid=abc; Path=/',
        '__Host-sid=abc; Secure',
        '__Host-sid=abc; Secure; Path=/app',
        '__Host-sid=abc; Secure; Path=/; Domain=example.com',
      ]) {
        expect(
          () => StoredCookie.fromSetCookie(
            value,
            requestUri: Uri.parse('https://example.com/login'),
          ),
          throwsArgumentError,
        );
      }
    });

    test('rejects domain attributes outside the request host', () {
      expect(
        () => StoredCookie.fromSetCookie(
          'sid=abc; Domain=victim.example',
          requestUri: Uri.parse('https://evil.example/login'),
        ),
        throwsArgumentError,
      );
    });

    test('rejects single-label and IP address domain attributes', () {
      expect(
        () => StoredCookie.fromSetCookie(
          'sid=abc; Domain=com',
          requestUri: Uri.parse('https://api.example.com/login'),
        ),
        throwsArgumentError,
      );
      expect(
        () => StoredCookie.fromSetCookie(
          'sid=abc; Domain=127.0.0.1',
          requestUri: Uri.parse('http://127.0.0.1/login'),
        ),
        throwsArgumentError,
      );
    });

    test('calculates the default path when Path is missing or invalid', () {
      final missingPath = StoredCookie.fromSetCookie(
        'sid=abc',
        requestUri: Uri.parse('https://example.com/docs/index.html'),
      );
      final invalidPath = StoredCookie.fromSetCookie(
        'sid=abc; Path=docs',
        requestUri: Uri.parse('https://example.com/docs/index.html'),
      );

      expect(missingPath.path, '/docs');
      expect(missingPath.cookie.path, '/docs');
      expect(invalidPath.path, '/docs');
      expect(invalidPath.cookie.path, '/docs');
    });

    test('applies path-match semantics', () {
      final stored = StoredCookie.fromSetCookie(
        'sid=abc; Path=/docs',
        requestUri: Uri.parse('https://example.com/docs/index.html'),
      );

      expect(stored.matches(Uri.parse('https://example.com/docs')), isTrue);
      expect(stored.matches(Uri.parse('https://example.com/docs/1')), isTrue);
      expect(stored.matches(Uri.parse('https://example.com/docs2')), isFalse);
    });

    test('applies Max-Age precedence over Expires', () {
      final now = DateTime.utc(2026, 1, 1, 0, 0);
      final stored = StoredCookie.fromSetCookie(
        'sid=abc; Max-Age=60; Expires=Wed, 21 Oct 2015 07:28:00 GMT',
        requestUri: Uri.parse('https://example.com/login'),
        now: now,
      );

      expect(stored.expiresAt, now.add(const Duration(seconds: 60)));
      expect(stored.isExpired(now.add(const Duration(seconds: 59))), isFalse);
      expect(stored.isExpired(now.add(const Duration(seconds: 60))), isTrue);
    });

    test('treats Max-Age less than or equal to zero as immediately expired',
        () {
      final now = DateTime.utc(2026, 1, 1, 0, 0);
      final stored = StoredCookie.fromSetCookie(
        'sid=abc; Max-Age=0',
        requestUri: Uri.parse('https://example.com/login'),
        now: now,
      );

      expect(stored.isExpired(now), isTrue);
      expect(
        stored.matches(Uri.parse('https://example.com/profile'), now: now),
        isFalse,
      );
    });

    test('serializes only the request cookie pair', () {
      final stored = StoredCookie.fromSetCookie(
        'sid=a b; Path=/; HttpOnly; Secure',
        requestUri: Uri.parse('https://example.com/login'),
      );

      expect(stored.toRequestCookie(), 'sid=a%20b');
    });

    test('copies stored metadata', () {
      final now = DateTime.utc(2026, 1, 1, 0, 0);
      final stored = StoredCookie.fromSetCookie(
        'sid=abc; Max-Age=60',
        requestUri: Uri.parse('https://example.com/login'),
        now: now,
      );
      final accessed = now.add(const Duration(seconds: 10));

      final copy = stored.copyWith(
        expiresAt: now.add(const Duration(minutes: 2)),
        lastAccessTime: accessed,
      );
      expect(copy.creationTime, now);
      expect(copy.lastAccessTime, accessed);
      expect(copy.expiresAt, now.add(const Duration(minutes: 2)));

      expect(copy.copyWith(clearExpiresAt: true).expiresAt, isNull);
      expect(
        () => copy.copyWith(
          expiresAt: now,
          clearExpiresAt: true,
        ),
        throwsArgumentError,
      );
    });
  });
}
