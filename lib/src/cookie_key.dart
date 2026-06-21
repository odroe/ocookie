import 'stored_cookie.dart';

/// Identity used to replace and delete cookies in a store.
final class CookieKey {
  const CookieKey({
    required this.name,
    required this.domain,
    required this.path,
  });

  /// Cookie name.
  final String name;

  /// Normalized domain used for matching.
  final String domain;

  /// Effective path used for matching.
  final String path;

  /// Creates a key for [cookie].
  factory CookieKey.fromStoredCookie(StoredCookie cookie) {
    return CookieKey(
      name: cookie.cookie.name,
      domain: cookie.domain,
      path: cookie.path,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CookieKey &&
          name == other.name &&
          domain == other.domain &&
          path == other.path;

  @override
  int get hashCode => Object.hash(name, domain, path);

  @override
  String toString() => '$name;$domain;$path';
}
