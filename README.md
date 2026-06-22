# Ocookie

Ocookie is a dependency-light HTTP cookie toolkit for Dart and Flutter. It
parses `Cookie` request headers, parses and serializes `Set-Cookie` response
values, splits combined `Set-Cookie` headers, and provides a small client-side
cookie jar with pluggable storage.

## What It Covers

- Request cookies: parse a `Cookie` header into name-value pairs.
- Response cookies: parse and serialize individual `Set-Cookie` values.
- Header compatibility: split combined `Set-Cookie` strings without breaking
  `Expires` dates or quoted commas.
- Client storage: normalize received cookies and build request `Cookie` headers
  for later URIs.
- Extension points: customize value encoding and plug in your own
  `CookieStore`.

## Install

```bash
dart pub add ocookie
```

```dart
import 'package:ocookie/ocookie.dart';
```

## Choose the API

| Task | API |
| --- | --- |
| Parse a request `Cookie` header | `Cookie.parse` |
| Parse one response `Set-Cookie` value | `Cookie.fromString` |
| Construct a `Set-Cookie` value | `Cookie(...).serialize()` |
| Check serialization errors without throwing | `Cookie.validate` |
| Split a combined `Set-Cookie` string | `Cookie.splitSetCookie` |
| Normalize one received cookie for matching | `StoredCookie.fromSetCookie` |
| Store response cookies and build request headers | `CookieJar` |
| Persist cookies outside memory | `CookieStore` |

## Parse Request Cookies

Use `Cookie.parse` for the `Cookie` header sent from a client to a server.

```dart
final cookies = Cookie.parse('sid=abc; theme=light');

print(cookies['sid']); // abc
print(cookies['theme']); // light
```

Malformed segments and empty names are ignored. If the same name appears more
than once, the first parsed value is kept.

## Work With Set-Cookie

Use `Cookie.fromString` when you receive one `Set-Cookie` value.

```dart
final cookie = Cookie.fromString(
  'sid=abc; Path=/; HttpOnly; Secure; SameSite=None',
);

print(cookie.name); // sid
print(cookie.value); // abc
print(cookie.path); // /
print(cookie.httpOnly); // true
```

Use `Cookie` and `serialize` when you need to create a `Set-Cookie` value.

```dart
final cookie = Cookie(
  'sid',
  'abc',
  maxAge: const Duration(hours: 1),
  path: '/',
  httpOnly: true,
  secure: true,
  sameSite: CookieSameSite.lax,
);

final headerValue = cookie.serialize();
print(headerValue);
// sid=abc; Max-Age=3600; Path=/; HttpOnly; Secure; SameSite=Lax
```

Supported attributes include `Expires`, `Max-Age`, `Domain`, `Path`,
`HttpOnly`, `Secure`, `Priority`, `SameSite`, and `Partitioned`.

`serialize` validates cookie-safe characters and security constraints. For
example, `SameSite=None` and `Partitioned` both require `Secure`.

## Split Combined Set-Cookie Values

Some HTTP clients expose multiple `Set-Cookie` headers as one string. Splitting
on every comma is incorrect because `Expires` dates and quoted values can also
contain commas.

```dart
final values = Cookie.splitSetCookie(
  'a=b; Expires=Wed, 21 Oct 2015 07:28:00 GMT, c=d; Path=/',
);

print(values.length); // 2
print(values.first); // a=b; Expires=Wed, 21 Oct 2015 07:28:00 GMT
print(values.last); // c=d; Path=/
```

## Store and Send Cookies

`CookieJar` is the high-level client API. Save response cookies with the URI
that produced them, then ask the jar for the `Cookie` request header for a later
URI.

```dart
final jar = CookieJar();
final now = DateTime.utc(2026, 1, 1);

await jar.save(
  Uri.parse('https://example.com/login'),
  [
    'sid=abc; Path=/; HttpOnly',
    'theme=dark; Path=/account',
  ],
  now: now,
);

final header = await jar.header(
  Uri.parse('https://example.com/account/settings'),
  now: now,
);

print(header); // theme=dark; sid=abc
```

The jar applies host-only and domain matching, path matching, expiry handling,
secure-cookie matching, `__Secure-` and `__Host-` prefix constraints, and
request-header ordering by path length and creation time.

The default store is `MemoryCookieStore`. Provide a custom `CookieStore` when
cookies need to live in a database, file, secure storage, or another process.

## Validate Before Serializing

Use `validate` when you want all serialization problems at once instead of the
first exception from `serialize`.

```dart
final cookie = Cookie(
  'sid',
  'abc',
  sameSite: CookieSameSite.none,
);

final errors = cookie.validate();
if (errors.isNotEmpty) {
  print(errors);
}
```

## Update Cookies

Use `copyWith` to adjust a cookie while preserving the rest of its attributes.
Nullable attributes can be removed explicitly with `clear`.

```dart
final original = Cookie(
  'sid',
  'abc',
  path: '/demo',
  secure: true,
);

final moved = original.copyWith(path: '/next');
final withoutPath = original.copyWith(
  clear: {CookieNullableField.path},
);
```

## Custom Encoding

Cookie values are URI component encoded by default. Pass custom codecs when an
application already stores cookie-safe values or uses a different escaping
scheme.

```dart
final serialized = Cookie(
  'token',
  'abc',
).serialize(encode: (value) => value.toUpperCase());

final parsed = Cookie.parse(
  'token=ABC',
  decode: (value) => value.toLowerCase(),
);

print(serialized); // token=ABC
print(parsed['token']); // abc
```

## Example

The runnable package example is in [`example/main.dart`](example/main.dart).

## API Reference

See the [API documentation](https://pub.dev/documentation/ocookie) for the full
public API.

## License

[MIT License](LICENSE)
