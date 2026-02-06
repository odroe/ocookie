import 'package:http_parser/http_parser.dart'
    show formatHttpDate, parseHttpDate;

import '_utils.dart';
import 'types.dart';

/// Enum representing the priority levels for a cookie.
enum CookiePriority {
  /// Low priority.
  low,

  /// Medium priority.
  medium,

  /// High priority.
  high
}

/// Enum representing the SameSite attribute for a cookie.
enum CookieSameSite {
  /// Lax same site enforcement.
  lax,

  /// Strict same site enforcement.
  strict,

  /// No same site enforcement.
  none
}

/// Nullable fields supported by [Cookie.copyWith.clear].
enum CookieNullableField {
  expires,
  domain,
  httpOnly,
  maxAge,
  path,
  priority,
  sameSite,
  secure,
  partitioned,
}

class Cookie {
  static const Set<CookieNullableField> _noClearedFields = {};

  const Cookie(
    this.name,
    this.value, {
    this.expires,
    this.domain,
    this.httpOnly,
    this.maxAge,
    this.path,
    this.priority,
    this.sameSite,
    this.secure,
    this.partitioned,
  });

  final String name;
  final String value;
  final DateTime? expires;
  final String? domain;
  final bool? httpOnly;
  final Duration? maxAge;
  final String? path;
  final CookiePriority? priority;
  final CookieSameSite? sameSite;
  final bool? secure;
  final bool? partitioned;

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
    assertNoConflict(CookieNullableField.httpOnly, httpOnly, 'httpOnly');
    assertNoConflict(CookieNullableField.maxAge, maxAge, 'maxAge');
    assertNoConflict(CookieNullableField.path, path, 'path');
    assertNoConflict(CookieNullableField.priority, priority, 'priority');
    assertNoConflict(CookieNullableField.sameSite, sameSite, 'sameSite');
    assertNoConflict(CookieNullableField.secure, secure, 'secure');
    assertNoConflict(
      CookieNullableField.partitioned,
      partitioned,
      'partitioned',
    );

    return Cookie(
      name ?? this.name,
      value ?? this.value,
      expires: clear.contains(CookieNullableField.expires)
          ? null
          : expires ?? this.expires,
      domain: clear.contains(CookieNullableField.domain)
          ? null
          : domain ?? this.domain,
      httpOnly: clear.contains(CookieNullableField.httpOnly)
          ? null
          : httpOnly ?? this.httpOnly,
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
      secure: clear.contains(CookieNullableField.secure)
          ? null
          : secure ?? this.secure,
      partitioned: clear.contains(CookieNullableField.partitioned)
          ? null
          : partitioned ?? this.partitioned,
    );
  }

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
    if (sameSite == CookieSameSite.none && secure != true) {
      throw StateError(
          'SameSite attribute is set to none, but the secure flag is not set to true.');
    }

    final parts = <String>[
      '$name=$encodedValue',
      if (maxAge != null) 'Max-Age=${maxAge!.inSeconds}',
      if (domain?.isNotEmpty == true) 'Domain=$domain',
      if (path?.isNotEmpty == true) 'Path=$path',
      if (expires != null) 'Expires=${formatHttpDate(expires!)}',
      if (httpOnly == true) 'HttpOnly',
      if (secure == true) 'Secure',
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
      if (partitioned == true) 'Partitioned',
    ];

    return parts.join('; ');
  }

  @override
  String toString() => serialize();

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
        'secure' => cookie.copyWith(secure: true),
        'httponly' => cookie.copyWith(httpOnly: true),
        'partitioned' => cookie.copyWith(partitioned: true),
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
          final value = cookies.substring(start, lastComma).trim();
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
        final value = cookies.substring(start).trim();
        if (value.isNotEmpty) {
          result.add(value);
        }
      }
    }

    return result;
  }
}
