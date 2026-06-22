/// @docImport 'cookie_jar.dart';
library;

import 'stored_cookie.dart';

/// Identity used to replace and delete stored cookies.
///
/// A cookie is not identified by name alone. User agents can store multiple
/// cookies with the same name when they differ by domain, path, or host-only
/// state. [CookieStore] implementations should use this key, or an equivalent
/// tuple, when replacing and deleting cookies.
final class CookieKey {
  /// Creates a cookie identity from normalized cookie fields.
  ///
  /// The values are expected to match the corresponding fields on a
  /// [StoredCookie].
  const CookieKey({
    required this.name,
    required this.domain,
    required this.path,
    required this.hostOnly,
  });

  /// The cookie name.
  final String name;

  /// The normalized domain used for matching.
  final String domain;

  /// The effective path used for matching.
  final String path;

  /// Whether the cookie is scoped to one host.
  final bool hostOnly;

  /// Creates a key for [cookie].
  ///
  /// This is the identity used by [MemoryCookieStore] and by [CookieJar] when
  /// deciding whether a new cookie replaces an existing one.
  factory CookieKey.fromStoredCookie(StoredCookie cookie) {
    return CookieKey(
      name: cookie.cookie.name,
      domain: cookie.domain,
      path: cookie.path,
      hostOnly: cookie.hostOnly,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CookieKey &&
          name == other.name &&
          domain == other.domain &&
          path == other.path &&
          hostOnly == other.hostOnly;

  @override
  int get hashCode => Object.hash(name, domain, path, hostOnly);

  @override
  String toString() => '$name;$domain;$path;$hostOnly';
}
