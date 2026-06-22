/// Function used to encode or decode cookie values.
///
/// The default encoder uses [Uri.encodeComponent], and the default decoder uses
/// [Uri.decodeComponent] when the value contains a percent escape. Custom
/// codecs are useful for applications that already store cookie-safe values or
/// that use a different escaping scheme.
typedef CookieCodec = String Function(String value);
