import 'package:ocookie/ocookie.dart';
import 'package:test/test.dart';

void main() {
  group('CookieJar', () {
    test('stores cookies and serializes a request header by path length',
        () async {
      final jar = CookieJar();
      final now = DateTime.utc(2026, 1, 1, 0, 0);

      await jar.save(
        Uri.parse('https://example.com/login'),
        [
          'sid=root; Path=/; HttpOnly',
          'sid=app; Path=/app; HttpOnly',
        ],
        now: now,
      );

      expect(
        await jar.header(
          Uri.parse('https://example.com/app/page'),
          now: now,
        ),
        'sid=app; sid=root',
      );
      expect(
        await jar.load(Uri.parse('https://example.com/app/page'), now: now),
        hasLength(2),
      );
    });

    test('replaces cookies by name, domain, and path', () async {
      final jar = CookieJar();
      final uri = Uri.parse('https://example.com/login');
      final first = DateTime.utc(2026, 1, 1, 0, 0);
      final second = first.add(const Duration(minutes: 1));

      await jar.save(uri, ['sid=old; Path=/'], now: first);
      await jar.save(uri, ['sid=new; Path=/'], now: second);

      final cookies = await jar.loadStored(uri, now: second);
      expect(cookies, hasLength(1));
      expect(cookies.single.cookie.value, 'new');
      expect(cookies.single.creationTime, first);
      expect(cookies.single.lastAccessTime, second);
    });

    test('preserves duplicate names with different paths', () async {
      final jar = CookieJar();
      final now = DateTime.utc(2026, 1, 1, 0, 0);

      await jar.save(
        Uri.parse('https://example.com/'),
        ['sid=root; Path=/'],
        now: now,
      );
      await jar.save(
        Uri.parse('https://example.com/app/login'),
        ['sid=app; Path=/app'],
        now: now,
      );

      expect(
        await jar.header(
          Uri.parse('https://example.com/app/page'),
          now: now,
        ),
        'sid=app; sid=root',
      );
    });

    test('enforces host-only, domain, and secure matching', () async {
      final jar = CookieJar();
      final now = DateTime.utc(2026, 1, 1, 0, 0);
      final later = now.add(const Duration(seconds: 1));
      final latest = now.add(const Duration(seconds: 2));

      await jar.save(
        Uri.parse('https://example.com/login'),
        ['host=1; Path=/'],
        now: now,
      );
      await jar.save(
        Uri.parse('https://api.example.com/login'),
        ['wide=1; Domain=example.com; Path=/'],
        now: later,
      );
      await jar.save(
        Uri.parse('https://api.example.com/login'),
        ['secure=1; Secure; Path=/'],
        now: latest,
      );

      expect(
        await jar.header(Uri.parse('https://example.com/home'), now: latest),
        'host=1; wide=1',
      );
      expect(
        await jar.header(Uri.parse('https://sub.example.com/home'),
            now: latest),
        'wide=1',
      );
      expect(
        await jar.header(Uri.parse('http://api.example.com/home'), now: latest),
        'wide=1',
      );
      expect(
        await jar.header(Uri.parse('https://api.example.com/home'),
            now: latest),
        'wide=1; secure=1',
      );
    });

    test('evicts expired cookies and expired replacements', () async {
      final jar = CookieJar();
      final uri = Uri.parse('https://example.com/login');
      final now = DateTime.utc(2026, 1, 1, 0, 0);

      await jar.save(uri, ['sid=short; Max-Age=1; Path=/'], now: now);
      expect(await jar.header(uri, now: now), 'sid=short');
      expect(
        await jar.header(
          uri,
          now: now.add(const Duration(seconds: 1)),
        ),
        isNull,
      );

      await jar.save(uri, ['sid=live; Path=/'], now: now);
      await jar.save(
        uri,
        ['sid=gone; Max-Age=0; Path=/'],
        now: now.add(const Duration(seconds: 2)),
      );

      expect(
        await jar.header(
          uri,
          now: now.add(const Duration(seconds: 2)),
        ),
        isNull,
      );
    });

    test('serializes only name and value in request headers', () async {
      final jar = CookieJar();
      final uri = Uri.parse('https://example.com/login');
      final now = DateTime.utc(2026, 1, 1, 0, 0);

      await jar.save(
        uri,
        ['sid=a b; Path=/; HttpOnly; Secure; SameSite=None'],
        now: now,
      );

      expect(await jar.header(uri, now: now), 'sid=a%20b');
    });

    test('supports parsed cookies as input', () async {
      final jar = CookieJar();
      final uri = Uri.parse('https://example.com/login');
      final now = DateTime.utc(2026, 1, 1, 0, 0);

      await jar.saveCookies(
        uri,
        const [Cookie('sid', 'abc', path: '/')],
        now: now,
      );

      expect(await jar.header(uri, now: now), 'sid=abc');
    });

    test('uses the pluggable store boundary', () async {
      final store = _RecordingCookieStore();
      final jar = CookieJar(store: store);
      final uri = Uri.parse('https://example.com/login');
      final now = DateTime.utc(2026, 1, 1, 0, 0);

      await jar.save(uri, ['sid=abc; Path=/'], now: now);

      expect(store.upserts, hasLength(1));
      expect(store.upserts.single.cookie.name, 'sid');
      expect(await jar.header(uri, now: now), 'sid=abc');
      expect(store.loadCalls, greaterThanOrEqualTo(2));
    });
  });

  group('CookiePolicy', () {
    test('normalizes, matches, sorts, and serializes stored cookies', () {
      const policy = CookiePolicy();
      final now = DateTime.utc(2026, 1, 1, 0, 0);
      final root = policy.normalizeSetCookie(
        'sid=root; Path=/',
        requestUri: Uri.parse('https://example.com/login'),
        now: now,
      );
      final app = policy.normalizeSetCookie(
        'sid=app; Path=/app',
        requestUri: Uri.parse('https://example.com/app/login'),
        now: now.add(const Duration(seconds: 1)),
      );

      expect(
        policy.matches(
          app,
          Uri.parse('https://example.com/app/page'),
          now,
        ),
        isTrue,
      );
      expect(policy.toRequestHeaderValue([root, app]), 'sid=app; sid=root');
    });
  });
}

final class _RecordingCookieStore implements CookieStore {
  final Map<CookieKey, StoredCookie> _cookies = <CookieKey, StoredCookie>{};
  final List<StoredCookie> upserts = <StoredCookie>[];
  int loadCalls = 0;

  @override
  Future<void> clear() async {
    _cookies.clear();
  }

  @override
  Future<void> delete(CookieKey key) async {
    _cookies.remove(key);
  }

  @override
  Future<Iterable<StoredCookie>> loadCandidates(Uri uri) async {
    loadCalls += 1;
    return _cookies.values.toList(growable: false);
  }

  @override
  Future<void> upsert(StoredCookie cookie) async {
    upserts.add(cookie);
    _cookies[CookieKey.fromStoredCookie(cookie)] = cookie;
  }
}
