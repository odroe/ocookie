/// @docImport 'cookie_jar.dart';
/// @docImport 'stored_cookie.dart';
library;

import 'package:http_parser/http_parser.dart'
    show formatHttpDate, parseHttpDate;

import '_utils.dart';
import 'types.dart';

/// Priority hints that can be attached to a `Set-Cookie` value.
///
/// Cookie priority is a non-standard but widely implemented attribute used by
/// some user agents when deciding which cookies to evict first under storage
/// pressure.
enum CookiePriority {
  /// A low-priority cookie.
  low,

  /// A medium-priority cookie.
  medium,

  /// A high-priority cookie.
  high
}

/// Cross-site availability for a cookie.
///
/// The value maps to the `SameSite` attribute on a `Set-Cookie` header. A
/// [none] value can only be serialized when [Cookie.secure] is true.
enum CookieSameSite {
  /// Sends the cookie on same-site requests and top-level cross-site
  /// navigations.
  lax,

  /// Sends the cookie only on same-site requests.
  strict,

  /// Sends the cookie on same-site and cross-site requests.
  ///
  /// Cookies using this value must also set [Cookie.secure].
  none
}

/// Nullable `Set-Cookie` attributes supported by [Cookie.copyWith].
///
/// These values are used with the `clear` argument to remove an attribute from
/// a copied [Cookie]. Boolean flags such as [Cookie.httpOnly] are not nullable;
/// set them to false instead of clearing them.
enum CookieNullableField {
  /// Clears [Cookie.expires].
  expires,

  /// Clears [Cookie.domain].
  domain,

  /// Clears [Cookie.maxAge].
  maxAge,

  /// Clears [Cookie.path].
  path,

  /// Clears [Cookie.priority].
  priority,

  /// Clears [Cookie.sameSite].
  sameSite,
}

/// Representation of one HTTP cookie.
///
/// A `Cookie` request header only carries name-value pairs. A `Set-Cookie`
/// response header can also carry attributes such as `Path`, `Domain`,
/// `HttpOnly`, `Secure`, and `SameSite`. This class stores both forms: use
/// [parse] for a request header, [fromString] for a single `Set-Cookie` value,
/// and [serialize] when constructing a response header value.
///
/// The constructor does not validate [name], [value], or attributes. Validation
/// happens in [validate] and [serialize], after the value has been passed
/// through the selected [CookieCodec].
///
/// ```dart
/// final headerValue = Cookie(
///   'sid',
///   'abc',
///   path: '/',
///   httpOnly: true,
///   secure: true,
/// ).serialize();
/// ```
///
/// This class does not decide whether a cookie should be sent to a later
/// request. Use [StoredCookie] or [CookieJar] for domain, path, secure, expiry,
/// and prefix matching.
class Cookie {
  static const Set<CookieNullableField> _noClearedFields = {};

  /// Creates a cookie with [name], [value], and optional `Set-Cookie`
  /// attributes.
  ///
  /// The [httpOnly], [secure], and [partitioned] flags default to false. This
  /// means that omitted flags and explicitly false flags have the same
  /// serialized behavior.
  const Cookie(
    this.name,
    this.value, {
    this.expires,
    this.domain,
    this.httpOnly = false,
    this.maxAge,
    this.path,
    this.priority,
    this.sameSite,
    this.secure = false,
    this.partitioned = false,
  });

  /// The cookie name.
  ///
  /// When serialized, this must be a valid RFC 6265 token. Empty names and
  /// names containing separators such as `;`, `,`, or `=` are rejected by
  /// [serialize].
  final String name;

  /// The cookie value before serialization encoding.
  ///
  /// By default, [serialize] applies [Uri.encodeComponent] to this value and
  /// [parse] or [fromString] applies [Uri.decodeComponent] when a percent escape
  /// is present. Pass a custom [CookieCodec] to those methods to use a different
  /// wire encoding.
  final String value;

  /// The absolute expiration time for the `Expires` attribute.
  ///
  /// This value is serialized as an HTTP date. When a cookie also has [maxAge],
  /// [StoredCookie] gives `Max-Age` precedence while computing [StoredCookie.expiresAt].
  final DateTime? expires;

  /// The raw `Domain` attribute value.
  ///
  /// This value is not normalized by [Cookie]. [StoredCookie.fromCookie]
  /// lowercases it, removes a leading dot, and validates it against the request
  /// host.
  final String? domain;

  /// Whether the `HttpOnly` flag is present.
  ///
  /// A cookie with this flag is intended for HTTP request handling and not for
  /// client-side scripts. The flag only affects serialization; enforcement is a
  /// user-agent concern.
  final bool httpOnly;

  /// The relative expiration duration for the `Max-Age` attribute.
  ///
  /// The value is serialized in whole seconds using [Duration.inSeconds].
  /// [StoredCookie] treats zero or negative durations as already expired.
  final Duration? maxAge;

  /// The raw `Path` attribute value.
  ///
  /// [serialize] rejects non-empty path values that contain control characters
  /// or `;`. [StoredCookie.fromCookie] computes a default path when the value is
  /// omitted, empty, or does not start with `/`.
  final String? path;

  /// The `Priority` attribute value.
  final CookiePriority? priority;

  /// The `SameSite` attribute value.
  ///
  /// [CookieSameSite.none] requires [secure] to be true when the cookie is
  /// serialized.
  final CookieSameSite? sameSite;

  /// Whether the `Secure` flag is present.
  ///
  /// [StoredCookie] only sends secure cookies to `https` URIs and rejects secure
  /// cookies received from non-HTTPS request URIs.
  final bool secure;

  /// Whether the `Partitioned` flag is present.
  ///
  /// Partitioned cookies must also be [secure] when serialized.
  final bool partitioned;

  /// Creates a copy with selected fields replaced.
  ///
  /// Omitted parameters keep their current value. Nullable `Set-Cookie`
  /// attributes can be removed by including the matching [CookieNullableField]
  /// in [clear].
  ///
  /// It is an error to set and clear the same nullable field in a single call.
  /// For example, passing both `path: '/'` and
  /// `clear: {CookieNullableField.path}` throws an [ArgumentError].
  Cookie copyWith({
    String? name,
    String? value,
    DateTime? expires,
    String? domain,
    bool? httpOnly,
    Duration? maxAge,
    String? path,
    CookiePriority? priority,
    CookieSameSite? sameSite,
    bool? secure,
    bool? partitioned,
    Set<CookieNullableField> clear = _noClearedFields,
  }) {
    void assertNoConflict(
      CookieNullableField field,
      Object? value,
      String paramName,
    ) {
      if (clear.contains(field) && value != null) {
        throw ArgumentError.value(
          value,
          paramName,
          'cannot set and clear the same field',
        );
      }
    }

    assertNoConflict(CookieNullableField.expires, expires, 'expires');
    assertNoConflict(CookieNullableField.domain, domain, 'domain');
    assertNoConflict(CookieNullableField.maxAge, maxAge, 'maxAge');
    assertNoConflict(CookieNullableField.path, path, 'path');
    assertNoConflict(CookieNullableField.priority, priority, 'priority');
    assertNoConflict(CookieNullableField.sameSite, sameSite, 'sameSite');

    return Cookie(
      name ?? this.name,
      value ?? this.value,
      expires: clear.contains(CookieNullableField.expires)
          ? null
          : expires ?? this.expires,
      domain: clear.contains(CookieNullableField.domain)
          ? null
          : domain ?? this.domain,
      httpOnly: httpOnly ?? this.httpOnly,
      maxAge: clear.contains(CookieNullableField.maxAge)
          ? null
          : maxAge ?? this.maxAge,
      path: clear.contains(CookieNullableField.path) ? null : path ?? this.path,
      priority: clear.contains(CookieNullableField.priority)
          ? null
          : priority ?? this.priority,
      sameSite: clear.contains(CookieNullableField.sameSite)
          ? null
          : sameSite ?? this.sameSite,
      secure: secure ?? this.secure,
      partitioned: partitioned ?? this.partitioned,
    );
  }

  /// Validates this cookie and returns every serialization problem found.
  ///
  /// The returned list is empty when [serialize] should be able to produce a
  /// header value using the same [encode] function. If [encode] throws, the
  /// error is captured as a validation message and no further value validation
  /// is attempted.
  ///
  /// This method is useful for form-like flows where callers want to report all
  /// problems at once instead of handling the first exception thrown by
  /// [serialize].
  List<String> validate({CookieCodec? encode}) {
    final errors = <String>[];
    encode ??= defaultEncode;

    if (!cookieAllowPattern.hasMatch(name)) {
      errors.add('argument name is invalid');
    }

    String encodedValue;
    try {
      encodedValue = encode(value);
    } catch (error) {
      errors.add('failed to encode value: $error');
      return errors;
    }

    if (encodedValue.isNotEmpty && !cookieAllowPattern.hasMatch(encodedValue)) {
      errors.add('encoded value is invalid');
    }
    if (path?.isNotEmpty == true && !isPathValueValid(path!)) {
      errors.add('path is invalid');
    }
    if (domain?.isNotEmpty == true && !cookieAllowPattern.hasMatch(domain!)) {
      errors.add('domain is invalid');
    }
    if (sameSite == CookieSameSite.none && !secure) {
      errors.add(
        'SameSite attribute is set to none, but the secure flag is not set to true.',
      );
    }
    if (partitioned && !secure) {
      errors.add(
        'Partitioned attribute is set, but the secure flag is not set to true.',
      );
    }

    return errors;
  }

  /// Serializes this cookie as a `Set-Cookie` header value.
  ///
  /// The [value] is encoded before it is written. The default encoder is
  /// [Uri.encodeComponent].
  ///
  /// Throws an [ArgumentError] when [name], [path], or [domain] contains
  /// characters that cannot be serialized. Throws a [StateError] when the
  /// encoded value is invalid, when [sameSite] is [CookieSameSite.none] without
  /// [secure], or when [partitioned] is true without [secure].
  ///
  /// See also:
  ///
  ///  * [validate], which reports serialization problems without throwing.
  String serialize({CookieCodec? encode}) {
    encode ??= defaultEncode;

    if (!cookieAllowPattern.hasMatch(name)) {
      throw ArgumentError.value(name, 'name', 'argument name is invalid');
    }

    final encodedValue = encode(value);
    if (encodedValue.isNotEmpty && !cookieAllowPattern.hasMatch(encodedValue)) {
      throw StateError('encoded value is invalid');
    }
    if (path?.isNotEmpty == true && !isPathValueValid(path!)) {
      throw ArgumentError.value(path, 'path', 'path is invalid');
    }
    if (domain?.isNotEmpty == true && !cookieAllowPattern.hasMatch(domain!)) {
      throw ArgumentError.value(domain, 'domain', 'domain is invalid');
    }
    if (sameSite == CookieSameSite.none && !secure) {
      throw StateError(
          'SameSite attribute is set to none, but the secure flag is not set to true.');
    }
    if (partitioned && !secure) {
      throw StateError(
          'Partitioned attribute is set, but the secure flag is not set to true.');
    }

    final parts = <String>[
      '$name=$encodedValue',
      if (maxAge != null) 'Max-Age=${maxAge!.inSeconds}',
      if (domain?.isNotEmpty == true) 'Domain=$domain',
      if (path?.isNotEmpty == true) 'Path=$path',
      if (expires != null) 'Expires=${formatHttpDate(expires!)}',
      if (httpOnly) 'HttpOnly',
      if (secure) 'Secure',
      if (priority != null)
        'Priority=${switch (priority!) {
          CookiePriority.low => 'Low',
          CookiePriority.medium => 'Medium',
          CookiePriority.high => 'High',
        }}',
      if (sameSite != null)
        'SameSite=${switch (sameSite!) {
          CookieSameSite.strict => 'Strict',
          CookieSameSite.lax => 'Lax',
          CookieSameSite.none => 'None',
        }}',
      if (partitioned) 'Partitioned',
    ];

    return parts.join('; ');
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Cookie &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          value == other.value &&
          expires == other.expires &&
          domain == other.domain &&
          httpOnly == other.httpOnly &&
          maxAge == other.maxAge &&
          path == other.path &&
          priority == other.priority &&
          sameSite == other.sameSite &&
          secure == other.secure &&
          partitioned == other.partitioned;

  @override
  int get hashCode => Object.hash(
        name,
        value,
        expires,
        domain,
        httpOnly,
        maxAge,
        path,
        priority,
        sameSite,
        secure,
        partitioned,
      );

  @override
  String toString() => serialize();

  /// Parses a single `Set-Cookie` header value.
  ///
  /// The header must start with a `name=value` pair. Recognized attributes are
  /// applied to the returned [Cookie], and unknown attributes are ignored.
  /// Invalid `Expires`, `Max-Age`, `SameSite`, and `Priority` values are ignored
  /// rather than causing the entire parse to fail.
  ///
  /// Explicit false-like flag values (`false`, `0`, and `?0`) disable
  /// `Secure`, `HttpOnly`, and `Partitioned`; any other flag value enables the
  /// flag. Quoted cookie values are unwrapped before [decode] is applied.
  ///
  /// Throws an [ArgumentError] if [setCookie] is empty, does not start with a
  /// `name=value` pair, or has an empty cookie name.
  factory Cookie.fromString(String setCookie, {CookieCodec? decode}) {
    decode = (decode ?? defaultDecode).tryRun;
    final parts = setCookie
        .split(';')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList(growable: false);
    if (parts.isEmpty) {
      throw ArgumentError.value(setCookie, 'setCookie', 'set-cookie is empty');
    }

    DateTime? parseExpiresValue(String value) {
      try {
        return parseHttpDate(value);
      } catch (_) {
        return null;
      }
    }

    Duration? parseMaxAgeValue(String value) {
      final seconds = int.tryParse(value);
      if (seconds == null) return null;
      return Duration(seconds: seconds);
    }

    String unwrapQuotedValue(String value) {
      if (value.length >= 2 && value.startsWith('"') && value.endsWith('"')) {
        return value.substring(1, value.length - 1);
      }

      return value;
    }

    bool parseFlagValue(String value) {
      final normalized = value.trim().toLowerCase();
      return switch (normalized) {
        'false' || '0' || '?0' => false,
        _ => true,
      };
    }

    final firstPair = parts.first;
    if (!firstPair.contains('=')) {
      throw ArgumentError.value(
        setCookie,
        'setCookie',
        'set-cookie must start with a name=value pair',
      );
    }

    final (name, rawValue) = parseCookieNameValue(firstPair);
    if (name.isEmpty) {
      throw ArgumentError.value(
        setCookie,
        'setCookie',
        'cookie name is empty',
      );
    }

    var cookie = Cookie(name, decode(unwrapQuotedValue(rawValue)));
    for (final pair in parts.skip(1)) {
      final [name, ...values] = pair.split('=');
      final value = values.join('=').trim();
      cookie = switch (name.trim().toLowerCase()) {
        'expires' => cookie.copyWith(expires: parseExpiresValue(value)),
        'max-age' => cookie.copyWith(maxAge: parseMaxAgeValue(value)),
        'secure' => cookie.copyWith(secure: parseFlagValue(value)),
        'httponly' => cookie.copyWith(httpOnly: parseFlagValue(value)),
        'partitioned' => cookie.copyWith(partitioned: parseFlagValue(value)),
        'path' => cookie.copyWith(path: value),
        'domain' => cookie.copyWith(domain: value),
        'samesite' => cookie.copyWith(
            sameSite: switch (value.toLowerCase()) {
              'lax' => CookieSameSite.lax,
              'strict' => CookieSameSite.strict,
              'none' => CookieSameSite.none,
              _ => null,
            },
          ),
        'priority' => cookie.copyWith(
            priority: switch (value.toLowerCase()) {
              'low' => CookiePriority.low,
              'medium' => CookiePriority.medium,
              'high' => CookiePriority.high,
              _ => null,
            },
          ),
        _ => cookie,
      };
    }

    return cookie;
  }

  /// Parses a `Cookie` request header into name-value pairs.
  ///
  /// Malformed segments and empty names are ignored. If a name appears more
  /// than once, the first parsed value is kept, matching the usual server-side
  /// behavior for duplicate cookie names.
  ///
  /// The optional [filter] is evaluated after the name has been trimmed and
  /// before the value is decoded. If [decode] throws for a value, the original
  /// value is kept.
  static Map<String, String> parse(
    String cookies, {
    CookieCodec? decode,
    bool Function(String key)? filter,
  }) {
    final result = <String, String>{};
    decode = (decode ?? defaultDecode).tryRun;
    int index = 0;

    while (index < cookies.length) {
      final eq = cookies.indexOf('=', index);
      if (eq == -1) break;

      final end = switch (cookies.indexOf(';', index)) {
        -1 => cookies.length,
        int value => value,
      };

      if (end < eq) {
        index = cookies.lastIndexOf(';', eq - 1) + 1;
        continue;
      }

      final key = cookies.substring(index, eq).trim();
      if (key.isEmpty) {
        index = end + 1;
        continue;
      }

      if (!result.containsKey(key) && (filter == null || filter(key))) {
        String value = cookies.substring(eq + 1, end).trim();
        if (value.length >= 2 && value.startsWith('"') && value.endsWith('"')) {
          value = value.substring(1, value.length - 1);
        }

        result[key] = decode(value);
      }

      index = end + 1;
    }

    return result;
  }

  /// Splits a combined `Set-Cookie` header value into individual values.
  ///
  /// HTTP clients and proxies sometimes expose multiple `Set-Cookie` headers as
  /// one comma-separated string. A plain `split(',')` is incorrect because
  /// `Expires` dates and quoted values may contain commas. This method only
  /// treats a comma as a separator when it is followed by the start of another
  /// cookie pair.
  static List<String> splitSetCookie(String cookies) {
    final result = <String>[];
    int pos = 0;
    int start;
    String ch;
    int lastComma;
    int nextStart;
    bool cookiesSeparatorFound;

    bool skipWhitespace() {
      while (pos < cookies.length && whitespacePattern.hasMatch(cookies[pos])) {
        pos += 1;
      }

      return pos < cookies.length;
    }

    bool notSpecialChar() {
      ch = cookies[pos];
      return ch != '=' && ch != ';' && ch != ',';
    }

    String sanitizeCookiePart(String value) {
      var sanitized = value.trim();
      while (sanitized.isNotEmpty &&
          (sanitized.endsWith(',') ||
              whitespacePattern.hasMatch(
                sanitized[sanitized.length - 1],
              ))) {
        sanitized = sanitized.substring(0, sanitized.length - 1).trimRight();
      }

      return sanitized;
    }

    while (pos < cookies.length) {
      start = pos;
      cookiesSeparatorFound = false;
      while (skipWhitespace()) {
        ch = cookies[pos];
        if (ch != ',') {
          pos += 1;
          continue;
        }

        lastComma = pos;
        pos += 1;

        skipWhitespace();
        nextStart = pos;

        while (pos < cookies.length && notSpecialChar()) {
          pos += 1;
        }

        if (pos < cookies.length && cookies[pos] == '=') {
          final value = sanitizeCookiePart(cookies.substring(start, lastComma));
          if (value.isNotEmpty) {
            result.add(value);
          }
          start = pos = nextStart;
          cookiesSeparatorFound = true;
        } else {
          pos = lastComma + 1;
        }
      }

      if (!cookiesSeparatorFound || pos >= cookies.length) {
        final value = sanitizeCookiePart(cookies.substring(start));
        if (value.isNotEmpty) {
          result.add(value);
        }
      }
    }

    return result;
  }
}
