class CookieParser {
  const CookieParser({this.decode, this.filter});

  /// Specifies a function that will be used to decode a cookie's value. Since
  /// the value of a cookie has a limited character set (and must be a simple
  /// string), this function can be used to decode a previously-encoded cookie
  /// value into a JavaScript string or other object.
  ///
  /// *Note* if an error is thrown from this function, the original, non-decoded
  /// cookie value will be returned as the cookie's value.
  final String Function(String value)? decode;

  /// Custom function to filter parsing specific keys.
  final bool Function(String key)? filter;

  /// Parse an HTTP Cookie header string and returning an object of all cookie
  /// name-value pairs.
  Map<String, String> parse(String cookie) {
    final result = <String, String>{};
    final decode = this.decode ?? _decode;

    int index = 0;
    while (index < cookie.length) {
      final eq = cookie.indexOf('=', index);
      if (eq == -1) break;

      final end = switch (cookie.indexOf(';', index)) {
        -1 => cookie.length,
        int value => value,
      };

      if (end < eq) {
        index = cookie.lastIndexOf(';', eq - 1) + 1;
        continue;
      }

      final key = cookie.substring(index, eq).trim();
      if ((filter != null && !filter!(key))) {
        index = end + 1;
        continue;
      }

      if (!result.containsKey(key)) {
        String value = cookie.substring(eq + 1, end);
        if (value.startsWith('"')) {
          value = value.substring(1, value.length - 1);
        }

        result[key] = _tryDecode(decode, value);
      }

      index = end + 1;
    }

    return result;
  }
}

/// Default decode.
String _decode(String value) {
  if (value.contains('%')) {
    return Uri.decodeComponent(value);
  }

  return value;
}

/// Try decode
String _tryDecode(String Function(String) decode, String value) {
  try {
    return decode(value);
  } catch (_) {
    return value;
  }
}
