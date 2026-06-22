import 'cookie.dart';
import 'cookie_key.dart';
import 'stored_cookie.dart';
import 'types.dart';

/// Stateless policy operations used by [CookieJar].
///
/// The policy knows how to normalize `Set-Cookie` values, test request matches,
/// sort cookies for a request header, and serialize stored cookies. It does not
/// own persistence; [CookieStore] is responsible for loading and saving
/// [StoredCookie] objects.
final class CookiePolicy {
  /// Creates a stateless cookie policy.
  const CookiePolicy();

  /// Parses and normalizes a `Set-Cookie` value received for [requestUri].
  ///
  /// This is the policy-level entry point used by [CookieJar.save]. It applies
  /// the request-scoped checks from [StoredCookie.fromSetCookie].
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
  ///
  /// This is useful when callers already have parsed [Cookie] objects and want
  /// the same matching state that would have been produced from a `Set-Cookie`
  /// header.
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
  ///
  /// This delegates to [StoredCookie.matches] and therefore applies expiry,
  /// host-only/domain, path, and secure matching.
  bool matches(StoredCookie cookie, Uri uri, DateTime now) {
    return cookie.matches(uri, now: now);
  }

  /// Sorts cookies for a `Cookie` request header.
  ///
  /// Longer paths are ordered first. Cookies with the same path length are
  /// ordered by earlier [StoredCookie.creationTime]. This matches the ordering
  /// used by [CookieJar.header].
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

  /// Serializes one stored cookie as a request `Cookie` header pair.
  ///
  /// Only the name and value are included. `Set-Cookie` attributes are storage
  /// metadata and are not emitted in request headers.
  String toRequestCookie(StoredCookie cookie, {CookieCodec? encode}) {
    return cookie.toRequestCookie(encode: encode);
  }

  /// Serializes stored cookies as a single `Cookie` request header value.
  ///
  /// Set [sort] to false when [cookies] are already in header order. The result
  /// is an empty string when [cookies] is empty; [CookieJar.header] wraps this
  /// behavior and returns null for the no-match case.
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

/// Pluggable persistence boundary for [CookieJar].
///
/// A store does not need to implement matching rules. It should return cookies
/// that may match or may be replaced for a URI, and let [CookieJar] apply
/// expiry, domain, path, secure, and sorting policy.
abstract interface class CookieStore {
  /// Loads cookies that may match [uri] or may be replaced by cookies from it.
  ///
  /// Implementations may return a broad candidate set. [CookieJar] filters the
  /// result before sending a request header.
  Future<Iterable<StoredCookie>> loadCandidates(Uri uri);

  /// Inserts or replaces [cookie] by name, domain, path, and host-only state.
  ///
  /// [CookieKey.fromStoredCookie] defines the identity used by the default
  /// store.
  Future<void> upsert(StoredCookie cookie);

  /// Deletes the cookie identified by [key].
  Future<void> delete(CookieKey key);

  /// Removes every cookie held by this store.
  Future<void> clear();
}

/// Dependency-light in-memory cookie storage.
///
/// This store is suitable for tests, command-line tools, and short-lived
/// clients. It does not persist across process restarts.
final class MemoryCookieStore implements CookieStore {
  /// Creates an empty in-memory cookie store.
  MemoryCookieStore();

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

/// Client-side cookie jar with pluggable persistence.
///
/// A [CookieJar] accepts `Set-Cookie` values received from response URIs and
/// later builds the `Cookie` request header for another URI. It combines
/// [CookiePolicy] with a [CookieStore] so that matching rules stay independent
/// from storage.
///
/// The jar removes expired cookies as they are encountered, preserves creation
/// time when a cookie is replaced, and ignores insecure attempts to overwrite an
/// existing secure cookie when the domains and paths overlap.
///
/// ```dart
/// final jar = CookieJar();
/// await jar.save(
///   Uri.parse('https://example.com/login'),
///   ['sid=abc; Path=/; HttpOnly'],
/// );
///
/// final header = await jar.header(
///   Uri.parse('https://example.com/profile'),
/// );
/// ```
final class CookieJar {
  /// Creates a cookie jar backed by [store] and [policy].
  ///
  /// When [store] is omitted, a new [MemoryCookieStore] is used.
  CookieJar({
    CookieStore? store,
    this.policy = const CookiePolicy(),
  }) : store = store ?? MemoryCookieStore();

  /// Cookie persistence boundary used by this jar.
  final CookieStore store;

  /// Policy used for normalization, matching, sorting, and serialization.
  final CookiePolicy policy;

  /// Saves received `Set-Cookie` header values for [uri].
  ///
  /// Each value is parsed, normalized against [uri], and inserted into [store].
  /// A cookie with the same name, domain, path, and host-only state replaces the
  /// previous value while preserving its creation time.
  ///
  /// Expired cookies are deleted instead of stored. Invalid domain, secure, or
  /// prefix constraints throw [ArgumentError] through [policy].
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
  ///
  /// This is the parsed-object equivalent of [save]. It is useful when a caller
  /// has already constructed [Cookie] instances but still wants jar policy for
  /// normalization, replacement, expiry, and secure-overlay checks.
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
  ///
  /// Expired cookies found in [store] are deleted. Matching cookies have their
  /// [StoredCookie.lastAccessTime] updated to [now] and are returned in request
  /// header order.
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
  ///
  /// This is a convenience wrapper around [loadStored] for callers that do not
  /// need storage metadata such as domain, path, or expiry.
  Future<List<Cookie>> load(Uri uri, {DateTime? now}) async {
    return [
      for (final stored in await loadStored(uri, now: now)) stored.cookie,
    ];
  }

  /// Builds the `Cookie` request header value for [uri].
  ///
  /// Returns null when no stored cookie matches. The returned string is already
  /// sorted using [CookiePolicy.sortForHeader] and can be assigned directly to a
  /// request's `Cookie` header.
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
