/// HTTP cookie parsing, serialization, and jar utilities.
///
/// Import this library to parse `Cookie` request headers, parse or construct
/// `Set-Cookie` response values, normalize received cookies, and build
/// `Cookie` request headers for later requests.
library;

export 'src/cookie.dart';
export 'src/cookie_jar.dart';
export 'src/cookie_key.dart';
export 'src/stored_cookie.dart';
export 'src/types.dart';
