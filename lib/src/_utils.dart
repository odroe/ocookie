import 'types.dart';

String defaultEncode(String value) => Uri.encodeComponent(value);
String defaultDecode(String value) {
  if (value.contains('%')) {
    return Uri.decodeComponent(value);
  }

  return value;
}

extension TryRunCookieCodec on CookieCodec {
  String tryRun(String value) {
    try {
      return this(value);
    } catch (_) {
      return value;
    }
  }
}

final cookieAllowPattern = RegExp(r"^[!#\$%&'\*\+\-\.0-9A-Za-z\^_\`\|~]+$");

(String, String) parseCookieNameValue(String pair) {
  final [name, ...values] = pair.split('=');
  final value = values.join('=');
  return (name.trim(), value.trim());
}

final whitespacePattern = RegExp(r'\s');
