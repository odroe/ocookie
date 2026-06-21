import 'stored_cookie.dart';

/// Identity used to replace and delete cookies in a store.
final class CookieKey {
  const CookieKey({
    required this.name,
    required this.domain,
    required this.path,
    required this.hostOnly,
  });

  /// Cookie name.
  final String name;

  /// Normalized domain used for matching.
  final String domain;

  /// Effective path used for matching.
  final String path;

  /// Whether the cookie is scoped to one host.
  final bool hostOnly;

  /// Creates a key for [cookie].
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
