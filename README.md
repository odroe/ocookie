# 🍪 Ocookie

Cookie and Set-Cookie parser and serializer.

## Installation

To install `ocookie` add the following to your `pubspec.yaml`
```yaml
dependencies:
  ocookie: latest
```

Alternatively, you can run the following command:
```bash
dart pub add ocookie
```

## Basic Usage

```dart
final cookie = Cookie('name', 'value');
print(cookie.serialize()); // name=value
print(Cookie.parse('a=b;b=c')); // {a: b, b: c}

final setCookie = Cookie.fromString(
  'sid=abc; Path=/; HttpOnly; Secure; SameSite=None',
);
print(setCookie.path); // /

final values = Cookie.splitSetCookie(
  'a=b; Expires=Wed, 21 Oct 2015 07:28:00 GMT, c=d; Path=/',
);
print(values); // [a=b; Expires=Wed, 21 Oct 2015 07:28:00 GMT, c=d; Path=/]
```

### Utils

- `Cookie.serialize` - Serialize a cookie instance to string.
- `Cookie.validate` - Validate a cookie and return all errors.
- `Cookie.parse` - Parse client-side `cookie` header map.
- `Cookie.fromString` - Parse a set-cookie string to Cookie instance.
- `Cookie.splitSetCookie` - Split a string of multiple set-cookie values into a set-cookie string list.

## CopyWith And Clear

```dart
final original = Cookie(
  'sid',
  'abc',
  path: '/demo',
  secure: true,
  sameSite: CookieSameSite.none,
);

final updated = original.copyWith(path: '/next');
final cleared = original.copyWith(
  clear: {CookieNullableField.path},
);
```

## Validation

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

## Security Constraints

- `SameSite=None` requires `Secure=true`.
- `Partitioned=true` requires `Secure=true`.

# API Reference

See the [API documentation](https://pub.dev/documentation/ocookie) for detailed information about all available APIs.

## License

[MIT License](LICENSE)
