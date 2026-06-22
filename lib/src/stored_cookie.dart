/// @docImport 'cookie_jar.dart';
/// @docImport 'cookie_key.dart';
library;

import 'cookie.dart';
import 'types.dart';

/// A normalized cookie entry for client-side request matching.
///
/// [Cookie] stores the name, value, and optional `Set-Cookie` attributes as
/// they appear on the wire. [StoredCookie] adds the user-agent state needed to
/// decide whether the cookie should be sent with a later request: normalized
/// domain and path values, host-only state, expiry, creation time, and last
/// access time.
///
/// Most callers should use [CookieJar] instead of constructing this class
/// directly. Use [StoredCookie] when implementing custom storage or when a
/// lower-level policy decision needs to be tested explicitly.
///
/// ```dart
/// final stored = StoredCookie.fromSetCookie(
///   'sid=abc; Path=/; HttpOnly',
///   requestUri: Uri.parse('https://example.com/login'),
/// );
///
/// final matches = stored.matches(
///   Uri.parse('https://example.com/profile'),
/// );
/// ```
///
/// See also:
///
///  * [CookieJar], which stores and matches cookies for request URIs.
///  * [CookiePolicy], which exposes normalization and matching operations
///    without owning storage.
final class StoredCookie {
  /// Creates normalized cookie state for request matching.
  ///
  /// The constructor trusts that [domain], [path], [hostOnly], and [expiresAt]
  /// have already been normalized consistently with [cookie]. Prefer
  /// [StoredCookie.fromCookie] or [StoredCookie.fromSetCookie] when accepting
  /// data from HTTP headers.
  const StoredCookie({
    required this.cookie,
    required this.domain,
    required this.path,
    required this.hostOnly,
    required this.expiresAt,
    required this.creationTime,
    required this.lastAccessTime,
  });

  /// The parsed cookie with normalized `Domain` and `Path` attributes.
  ///
  /// For host-only cookies, [Cookie.domain] is cleared and the effective host is
  /// stored in [domain]. For domain cookies, [Cookie.domain] is normalized to the
  /// same value as [domain].
  final Cookie cookie;

  /// The normalized domain used for request matching.
  ///
  /// This is lowercased and has any trailing dot removed from the request host.
  /// Domain attributes also have a leading dot removed.
  final String domain;

  /// The effective path used for request matching.
  ///
  /// If the source cookie omits `Path`, uses an empty path, or uses a value that
  /// does not start with `/`, [StoredCookie.fromCookie] derives the default path
  /// from the request URI.
  final String path;

  /// Whether the cookie omitted a `Domain` attribute and is bound to one host.
  ///
  /// Host-only cookies match exactly [domain] and do not match subdomains.
  final bool hostOnly;

  /// The absolute expiry time after applying `Max-Age` precedence.
  ///
  /// A null value represents a session cookie. A zero or negative `Max-Age`
  /// value produces an expiry time at or before [creationTime].
  final DateTime? expiresAt;

  /// When this cookie was first created in the store.
  ///
  /// [CookieJar] preserves this value when a cookie is replaced by another
  /// cookie with the same [CookieKey].
  final DateTime creationTime;

  /// When this cookie was last selected for a request.
  ///
  /// [CookieJar.loadStored] updates this value for cookies that match the
  /// requested URI.
  final DateTime lastAccessTime;

  /// Parses and normalizes a `Set-Cookie` value received for [requestUri].
  ///
  /// The [requestUri] must include a host. Secure cookies must be received from
  /// an `https` URI. Domain attributes must domain-match the request host, and
  /// `__Secure-` or `__Host-` prefixes are validated while normalizing.
  ///
  /// Throws an [ArgumentError] when the header cannot be parsed or when the
  /// cookie is not valid for [requestUri].
  factory StoredCookie.fromSetCookie(
    String setCookie, {
    required Uri requestUri,
    DateTime? now,
    CookieCodec? decode,
  }) {
    return StoredCookie.fromCookie(
      Cookie.fromString(setCookie, decode: decode),
      requestUri: requestUri,
      now: now,
    );
  }

  /// Normalizes [cookie] as if it was received for [requestUri].
  ///
  /// This applies the same request-scoped rules as [StoredCookie.fromSetCookie],
  /// but starts from an already parsed [Cookie]. The returned cookie has an
  /// effective domain, path, expiry, creation time, and last access time.
  factory StoredCookie.fromCookie(
    Cookie cookie, {
    required Uri requestUri,
    DateTime? now,
  }) {
    final receivedAt = (now ?? DateTime.now()).toUtc();
    final requestHost = _requestHost(requestUri);
    final rawDomain = cookie.domain?.trim();
    final hasDomainAttribute = rawDomain != null && rawDomain.isNotEmpty;

    final hostOnly = !hasDomainAttribute;
    final domain = hostOnly ? requestHost : _normalizeDomain(rawDomain);
    if (cookie.secure && requestUri.scheme != 'https') {
      throw ArgumentError.value(
        requestUri,
        'requestUri',
        'Secure cookies can only be stored from secure request URIs.',
      );
    }
    _validateCookieNamePrefix(cookie, requestUri, hostOnly);
    if (!hostOnly && !_isValidCookieDomain(requestHost, domain)) {
      throw ArgumentError.value(
        cookie.domain,
        'cookie.domain',
        'Cookie domain does not match request host.',
      );
    }

    final path = _effectivePath(cookie.path, requestUri.path);
    final expiresAt = _expiresAt(cookie, receivedAt);
    final normalizedCookie = hostOnly
        ? cookie.copyWith(
            path: path,
            clear: const <CookieNullableField>{CookieNullableField.domain},
          )
        : cookie.copyWith(domain: domain, path: path);

    return StoredCookie(
      cookie: normalizedCookie,
      domain: domain,
      path: path,
      hostOnly: hostOnly,
      expiresAt: expiresAt,
      creationTime: receivedAt,
      lastAccessTime: receivedAt,
    );
  }

  /// Creates a copy with selected fields replaced.
  ///
  /// Omitted parameters keep their current value. Set [clearExpiresAt] to true
  /// to turn the copy into a session cookie. Passing both [expiresAt] and
  /// [clearExpiresAt] is an [ArgumentError].
  StoredCookie copyWith({
    Cookie? cookie,
    String? domain,
    String? path,
    bool? hostOnly,
    DateTime? expiresAt,
    bool clearExpiresAt = false,
    DateTime? creationTime,
    DateTime? lastAccessTime,
  }) {
    if (clearExpiresAt && expiresAt != null) {
      throw ArgumentError.value(
        expiresAt,
        'expiresAt',
        'cannot set and clear expiresAt',
      );
    }

    return StoredCookie(
      cookie: cookie ?? this.cookie,
      domain: domain ?? this.domain,
      path: path ?? this.path,
      hostOnly: hostOnly ?? this.hostOnly,
      expiresAt: clearExpiresAt ? null : expiresAt ?? this.expiresAt,
      creationTime: creationTime ?? this.creationTime,
      lastAccessTime: lastAccessTime ?? this.lastAccessTime,
    );
  }

  /// Whether this cookie is expired at [now].
  ///
  /// The comparison uses UTC. Session cookies, represented by a null
  /// [expiresAt], are never expired by this method.
  bool isExpired(DateTime now) {
    final expiresAt = this.expiresAt;
    return expiresAt != null && !expiresAt.isAfter(now.toUtc());
  }

  /// Whether this cookie should be sent with a request to [uri].
  ///
  /// The URI must include a host. Host-only cookies require an exact host
  /// match. Domain cookies also match subdomains, except for IP-address hosts.
  /// The request path must path-match [path], and secure cookies only match
  /// `https` URIs.
  ///
  /// If [now] is supplied, expired cookies do not match.
  bool matches(Uri uri, {DateTime? now}) {
    if (now != null && isExpired(now)) {
      return false;
    }

    final requestHost = _requestHost(uri);
    if (hostOnly) {
      if (requestHost != domain) {
        return false;
      }
    } else if (!_domainMatches(requestHost, domain)) {
      return false;
    }

    final requestPath = uri.path.isEmpty ? '/' : uri.path;
    if (!_pathMatches(requestPath, path)) {
      return false;
    }

    if (cookie.secure && uri.scheme != 'https') {
      return false;
    }

    return true;
  }

  /// Serializes the cookie as a `Cookie` request header pair.
  ///
  /// Only the cookie [Cookie.name] and [Cookie.value] are included. Attributes
  /// such as `Path`, `Domain`, `HttpOnly`, and `Secure` are never written to a
  /// request `Cookie` header.
  String toRequestCookie({CookieCodec? encode}) {
    return Cookie(cookie.name, cookie.value).serialize(encode: encode);
  }
}

String _requestHost(Uri uri) {
  if (uri.host.isEmpty) {
    throw ArgumentError.value(uri, 'uri', 'URI must include a host.');
  }

  return _stripTrailingDot(uri.host.toLowerCase());
}

String _normalizeDomain(String value) {
  final normalized = value.trim().toLowerCase();
  return normalized.startsWith('.') ? normalized.substring(1) : normalized;
}

String _stripTrailingDot(String value) {
  return value.endsWith('.') ? value.substring(0, value.length - 1) : value;
}

void _validateCookieNamePrefix(Cookie cookie, Uri requestUri, bool hostOnly) {
  if (cookie.name.startsWith('__Secure-') &&
      (!cookie.secure || requestUri.scheme != 'https')) {
    throw ArgumentError.value(
      cookie.name,
      'cookie.name',
      '__Secure- cookies require Secure and a secure request URI.',
    );
  }

  if (cookie.name.startsWith('__Host-') &&
      (!cookie.secure ||
          requestUri.scheme != 'https' ||
          !hostOnly ||
          cookie.path != '/')) {
    throw ArgumentError.value(
      cookie.name,
      'cookie.name',
      '__Host- cookies require Secure, Path=/, no Domain, and a secure request URI.',
    );
  }
}

bool _isValidCookieDomain(String requestHost, String domain) {
  return domain.contains('.') &&
      !_isIpAddress(domain) &&
      _domainMatches(requestHost, domain);
}

bool _domainMatches(String requestHost, String domain) {
  if (requestHost == domain) {
    return true;
  }
  if (_isIpAddress(requestHost)) {
    return false;
  }

  return requestHost.endsWith('.$domain');
}

bool _isIpAddress(String host) {
  return _ipv4AddressPattern.hasMatch(host) || host.contains(':');
}

String _effectivePath(String? cookiePath, String requestPath) {
  if (cookiePath == null || cookiePath.isEmpty || !cookiePath.startsWith('/')) {
    return _defaultPath(requestPath);
  }

  return cookiePath;
}

String _defaultPath(String requestPath) {
  if (requestPath.isEmpty || !requestPath.startsWith('/')) {
    return '/';
  }

  final slashIndex = requestPath.lastIndexOf('/');
  if (slashIndex <= 0) {
    return '/';
  }

  return requestPath.substring(0, slashIndex);
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

DateTime? _expiresAt(Cookie cookie, DateTime now) {
  final maxAge = cookie.maxAge;
  if (maxAge != null) {
    if (maxAge.inSeconds <= 0) {
      return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    }

    return now.toUtc().add(maxAge);
  }

  return cookie.expires?.toUtc();
}

final _ipv4AddressPattern = RegExp(r'^\d{1,3}(?:\.\d{1,3}){3}$');
