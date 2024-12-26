/// Parse an HTTP Cookie header string and returning
/// an object of all cookie name-value pairs.
Map<String, String> parseCookie(
  String cookie, {
  String Function(String value)? decode,
  bool Function(String key)? filter,
}) {
  final result = <String, String>{};
  decode ??= _decode;
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
    if ((filter != null && !filter(key))) {
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
