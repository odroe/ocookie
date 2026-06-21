import 'cookie.dart';
import 'types.dart';

/// A normalized cookie entry for client-side request matching.
///
/// [Cookie] represents the parsed Set-Cookie value. [StoredCookie] adds the
/// user-agent state needed to decide whether that cookie should be sent with a
/// later request.
final class StoredCookie {
  const StoredCookie._({
    required this.cookie,
    required this.domain,
    required this.path,
    required this.hostOnly,
    required this.expiresAt,
  });

  /// The parsed cookie with normalized Domain and Path attributes.
  final Cookie cookie;

  /// The normalized domain used for request matching.
  final String domain;

  /// The effective path used for request matching.
  final String path;

  /// Whether the cookie omitted a Domain attribute and is bound to one host.
  final bool hostOnly;

  /// The absolute expiry time after applying Max-Age precedence.
  ///
  /// A null value represents a session cookie.
  final DateTime? expiresAt;

  /// Parses and normalizes a Set-Cookie value received for [requestUri].
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
  factory StoredCookie.fromCookie(
    Cookie cookie, {
    required Uri requestUri,
    DateTime? now,
  }) {
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
    if (!hostOnly && !_isValidCookieDomain(requestHost, domain)) {
      throw ArgumentError.value(
        cookie.domain,
        'cookie.domain',
        'Cookie domain does not match request host.',
      );
    }

    final path = _effectivePath(cookie.path, requestUri.path);
    final expiresAt = _expiresAt(cookie, now ?? DateTime.now().toUtc());
    final normalizedCookie = hostOnly
        ? cookie.copyWith(
            path: path,
            clear: const <CookieNullableField>{CookieNullableField.domain},
          )
        : cookie.copyWith(domain: domain, path: path);

    return StoredCookie._(
      cookie: normalizedCookie,
      domain: domain,
      path: path,
      hostOnly: hostOnly,
      expiresAt: expiresAt,
    );
  }

  /// Whether this cookie is expired at [now].
  bool isExpired(DateTime now) {
    final expiresAt = this.expiresAt;
    return expiresAt != null && !expiresAt.isAfter(now.toUtc());
  }

  /// Whether this cookie should be sent with a request to [uri].
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

  /// Serializes the cookie as a Cookie request header pair.
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
  final normalized = _stripTrailingDot(value.trim().toLowerCase());
  return normalized.startsWith('.') ? normalized.substring(1) : normalized;
}

String _stripTrailingDot(String value) {
  return value.endsWith('.') ? value.substring(0, value.length - 1) : value;
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
