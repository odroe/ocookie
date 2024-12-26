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

/// Additional serialization options
class CookieSerializeOptions {
  const CookieSerializeOptions({
    this.encode,
    this.domain,
    this.expires,
    this.httpOnly,
    this.maxAge,
    this.partitioned,
    this.path,
    this.priority,
    this.sameSite,
    this.secure,
  });

  /// Specifies the value for the {@link https://tools.ietf.org/html/rfc6265#section-5.2.3|Domain Set-Cookie attribute}. By default, no
  /// domain is set, and most clients will consider the cookie to apply to only
  /// the current domain.
  final String? domain;

  /// Specifies a function that will be used to encode a cookie's value. Since
  /// value of a cookie has a limited character set (and must be a simple
  /// string), this function can be used to encode a value into a string suited
  /// for a cookie's value.
  final String Function(String value)? encode;

  /// Specifies the `Date` object to be the value for the {@link https://tools.ietf.org/html/rfc6265#section-5.2.1|`Expires` `Set-Cookie` attribute}. By default,
  /// no expiration is set, and most clients will consider this a "non-persistent cookie" and will delete
  /// it on a condition like exiting a web browser application.
  ///
  /// *Note* the {@link https://tools.ietf.org/html/rfc6265#section-5.3|cookie storage model specification}
  /// states that if both `expires` and `maxAge` are set, then `maxAge` takes precedence, but it is
  /// possible not all clients by obey this, so if both are set, they should
  /// point to the same date and time.
  final DateTime? expires;

  /// Specifies the boolean value for the {@link https://tools.ietf.org/html/rfc6265#section-5.2.6|`HttpOnly` `Set-Cookie` attribute}.
  /// When truthy, the `HttpOnly` attribute is set, otherwise it is not. By
  /// default, the `HttpOnly` attribute is not set.
  final bool? httpOnly;

  /// Specifies the [Duration] to be the value for the `Max-Age`
  /// `Set-Cookie` attribute. The given number will be converted to an integer
  /// by rounding down. By default, no maximum age is set.
  ///
  /// *Note* the {@link https://tools.ietf.org/html/rfc6265#section-5.3|cookie storage model specification}
  /// states that if both `expires` and `maxAge` are set, then `maxAge` takes precedence, but it is
  /// possible not all clients by obey this, so if both are set, they should
  /// point to the same date and time.
  final Duration? maxAge;

  /// Specifies the value for the {@link https://tools.ietf.org/html/rfc6265#section-5.2.4|`Path` `Set-Cookie` attribute}.
  /// By default, the path is considered the "default path".
  final String? path;

  /// Specifies the `string` to be the value for the [`Priority` `Set-Cookie` attribute][https://tools.ietf.org/html/rfc6265#rfc-west-cookie-priority-00-4.1].
  ///
  /// - `'low'` will set the `Priority` attribute to `Low`.
  /// - `'medium'` will set the `Priority` attribute to `Medium`, the default priority when not set.
  /// - `'high'` will set the `Priority` attribute to `High`.
  ///
  /// More information about the different priority levels can be found in
  /// [the specification][https://tools.ietf.org/html/rfc6265#rfc-west-cookie-priority-00-4.1].
  ///
  /// **note** This is an attribute that has not yet been fully standardized, and may change in the future.
  /// This also means many clients may ignore this attribute until they understand it.
  final CookiePriority? priority;

  /// Specifies the boolean or string to be the value for the {@link https://tools.ietf.org/html/draft-ietf-httpbis-rfc6265bis-03#section-4.1.2.7|`SameSite` `Set-Cookie` attribute}.
  ///
  /// - `'lax'` will set the `SameSite` attribute to Lax for lax same site
  /// enforcement.
  /// - `'strict'` will set the `SameSite` attribute to Strict for strict same
  /// site enforcement.
  ///  - `'none'` will set the SameSite attribute to None for an explicit
  ///  cross-site cookie.
  ///
  /// More information about the different enforcement levels can be found in {@link https://tools.ietf.org/html/draft-ietf-httpbis-rfc6265bis-03#section-4.1.2.7|the specification}.
  ///
  /// *note* This is an attribute that has not yet been fully standardized, and may change in the future. This also means many clients may ignore this attribute until they understand it.
  final CookieSameSite? sameSite;

  /// Specifies the boolean value for the {@link https://tools.ietf.org/html/rfc6265#section-5.2.5|`Secure` `Set-Cookie` attribute}. When truthy, the
  /// `Secure` attribute is set, otherwise it is not. By default, the `Secure` attribute is not set.
  ///
  /// *Note* be careful when setting this to `true`, as compliant clients will
  /// not send the cookie back to the server in the future if the browser does
  /// not have an HTTPS connection.
  final bool? secure;

  /// Specifies the [bool] value for the [`Partitioned` `Set-Cookie`](https://datatracker.ietf.org/doc/html/draft-cutler-httpbis-partitioned-cookies#section-2.1)
  /// attribute. When truthy, the `Partitioned` attribute is set, otherwise it is not. By default, the
  /// `Partitioned` attribute is not set.
  ///
  /// **note** This is an attribute that has not yet been fully standardized, and may change in the future.
  /// This also means many clients may ignore this attribute until they understand it.
  ///
  /// More information can be found in the [proposal](https://github.com/privacycg/CHIPS).
  final bool? partitioned;
}
