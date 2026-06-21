import 'cookie.dart';
import 'cookie_key.dart';
import 'stored_cookie.dart';
import 'types.dart';

/// RFC cookie-store policy that is independent from storage.
final class CookiePolicy {
  const CookiePolicy();

  /// Parses and normalizes a Set-Cookie value received for [requestUri].
  StoredCookie normalizeSetCookie(
    String setCookie, {
    required Uri requestUri,
    DateTime? now,
    CookieCodec? decode,
  }) {
    return StoredCookie.fromSetCookie(
      setCookie,
      requestUri: requestUri,
      now: now,
      decode: decode,
    );
  }

  /// Normalizes [cookie] as if it was received for [requestUri].
  StoredCookie normalizeCookie(
    Cookie cookie, {
    required Uri requestUri,
    DateTime? now,
  }) {
    return StoredCookie.fromCookie(
      cookie,
      requestUri: requestUri,
      now: now,
    );
  }

  /// Whether [cookie] should be sent to [uri] at [now].
  bool matches(StoredCookie cookie, Uri uri, DateTime now) {
    return cookie.matches(uri, now: now);
  }

  /// Sorts cookies for a Cookie request header.
  ///
  /// Longer paths are ordered first. Cookies with the same path length are
  /// ordered by earlier creation time.
  List<StoredCookie> sortForHeader(Iterable<StoredCookie> cookies) {
    return cookies.toList()
      ..sort((a, b) {
        final pathOrder = b.path.length.compareTo(a.path.length);
        if (pathOrder != 0) {
          return pathOrder;
        }

        return a.creationTime.compareTo(b.creationTime);
      });
  }

  /// Serializes one stored cookie as a request Cookie header pair.
  String toRequestCookie(StoredCookie cookie, {CookieCodec? encode}) {
    return cookie.toRequestCookie(encode: encode);
  }

  /// Serializes stored cookies as a single Cookie request header value.
  ///
  /// Set [sort] to false when [cookies] are already in header order.
  String toRequestHeaderValue(
    Iterable<StoredCookie> cookies, {
    CookieCodec? encode,
    bool sort = true,
  }) {
    final headerCookies = sort ? sortForHeader(cookies) : cookies;
    return headerCookies
        .map((cookie) => toRequestCookie(cookie, encode: encode))
        .join('; ');
  }
}

/// Pluggable persistence boundary for stored cookies.
abstract interface class CookieStore {
  /// Loads cookies that may match or be replaced by cookies from [uri].
  Future<Iterable<StoredCookie>> loadCandidates(Uri uri);

  /// Inserts or replaces [cookie] by name, domain, path, and host-only state.
  Future<void> upsert(StoredCookie cookie);

  /// Deletes the cookie identified by [key].
  Future<void> delete(CookieKey key);

  /// Removes every cookie.
  Future<void> clear();
}

/// Dependency-light in-memory cookie storage.
final class MemoryCookieStore implements CookieStore {
  final Map<CookieKey, StoredCookie> _cookies = <CookieKey, StoredCookie>{};

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
    return _cookies.values.toList(growable: false);
  }

  @override
  Future<void> upsert(StoredCookie cookie) async {
    _cookies[CookieKey.fromStoredCookie(cookie)] = cookie;
  }
}

/// Cookie jar that combines RFC policy with a pluggable store.
final class CookieJar {
  CookieJar({
    CookieStore? store,
    this.policy = const CookiePolicy(),
  }) : store = store ?? MemoryCookieStore();

  /// Cookie persistence boundary used by this jar.
  final CookieStore store;

  /// Policy used for normalization, matching, sorting, and serialization.
  final CookiePolicy policy;

  /// Saves received Set-Cookie header values for [uri].
  Future<void> save(
    Uri uri,
    Iterable<String> setCookieValues, {
    DateTime? now,
    CookieCodec? decode,
  }) async {
    final nowUtc = (now ?? DateTime.now()).toUtc();
    final existing = await _loadByKey(uri, nowUtc);

    for (final setCookie in setCookieValues) {
      final cookie = policy.normalizeSetCookie(
        setCookie,
        requestUri: uri,
        now: nowUtc,
        decode: decode,
      );

      await _storeNormalized(cookie, existing, nowUtc, uri);
    }
  }

  /// Saves parsed cookies as if they were received for [uri].
  Future<void> saveCookies(
    Uri uri,
    Iterable<Cookie> cookies, {
    DateTime? now,
  }) async {
    final nowUtc = (now ?? DateTime.now()).toUtc();
    final existing = await _loadByKey(uri, nowUtc);

    for (final cookie in cookies) {
      final stored = policy.normalizeCookie(
        cookie,
        requestUri: uri,
        now: nowUtc,
      );

      await _storeNormalized(stored, existing, nowUtc, uri);
    }
  }

  /// Loads stored cookies that match [uri].
  Future<List<StoredCookie>> loadStored(Uri uri, {DateTime? now}) async {
    final nowUtc = (now ?? DateTime.now()).toUtc();
    final matched = <StoredCookie>[];

    for (final cookie in await store.loadCandidates(uri)) {
      final key = CookieKey.fromStoredCookie(cookie);
      if (cookie.isExpired(nowUtc)) {
        await store.delete(key);
        continue;
      }

      if (policy.matches(cookie, uri, nowUtc)) {
        final accessed = cookie.copyWith(lastAccessTime: nowUtc);
        await store.upsert(accessed);
        matched.add(accessed);
      }
    }

    return policy.sortForHeader(matched);
  }

  /// Loads parsed cookies that match [uri].
  Future<List<Cookie>> load(Uri uri, {DateTime? now}) async {
    return [
      for (final stored in await loadStored(uri, now: now)) stored.cookie,
    ];
  }

  /// Builds the Cookie request header value for [uri].
  ///
  /// Returns null when no stored cookie matches.
  Future<String?> header(
    Uri uri, {
    DateTime? now,
    CookieCodec? encode,
  }) async {
    final cookies = await loadStored(uri, now: now);
    if (cookies.isEmpty) {
      return null;
    }

    return policy.toRequestHeaderValue(cookies, encode: encode, sort: false);
  }

  /// Removes every cookie from the underlying store.
  Future<void> clear() {
    return store.clear();
  }

  Future<Map<CookieKey, StoredCookie>> _loadByKey(
    Uri uri,
    DateTime now,
  ) async {
    final result = <CookieKey, StoredCookie>{};
    for (final cookie in await store.loadCandidates(uri)) {
      final key = CookieKey.fromStoredCookie(cookie);
      if (cookie.isExpired(now)) {
        await store.delete(key);
      } else {
        result[key] = cookie;
      }
    }

    return result;
  }

  Future<void> _storeNormalized(
    StoredCookie cookie,
    Map<CookieKey, StoredCookie> existing,
    DateTime now,
    Uri uri,
  ) async {
    final key = CookieKey.fromStoredCookie(cookie);
    final previous = existing[key];
    if (_wouldOverlaySecureCookie(cookie, existing.values, uri)) {
      return;
    }

    if (cookie.isExpired(now)) {
      await store.delete(key);
      existing.remove(key);
      return;
    }

    final normalized = previous == null
        ? cookie
        : cookie.copyWith(creationTime: previous.creationTime);
    await store.upsert(normalized);
    existing[key] = normalized;
  }

  bool _wouldOverlaySecureCookie(
    StoredCookie cookie,
    Iterable<StoredCookie> existing,
    Uri uri,
  ) {
    if (cookie.cookie.secure || uri.scheme == 'https') {
      return false;
    }

    return existing.any((stored) {
      return stored.cookie.secure &&
          stored.cookie.name == cookie.cookie.name &&
          _domainsOverlap(stored, cookie) &&
          _pathMatches(cookie.path, stored.path);
    });
  }

  bool _domainsOverlap(StoredCookie a, StoredCookie b) {
    if (a.hostOnly && b.hostOnly) {
      return a.domain == b.domain;
    }
    if (a.hostOnly) {
      return _domainMatches(a.domain, b.domain);
    }
    if (b.hostOnly) {
      return _domainMatches(b.domain, a.domain);
    }

    return _domainMatches(a.domain, b.domain) ||
        _domainMatches(b.domain, a.domain);
  }

  bool _domainMatches(String host, String domain) {
    return host == domain || host.endsWith('.$domain');
  }

  bool _pathMatches(String requestPath, String cookiePath) {
    if (requestPath == cookiePath) {
      return true;
    }
    if (!requestPath.startsWith(cookiePath)) {
      return false;
    }
    if (cookiePath.endsWith('/')) {
      return true;
    }

    return requestPath[cookiePath.length] == '/';
  }
}
