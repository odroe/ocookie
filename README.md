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

## Baisc Usage

```dart
final cookie = Cookie('name', 'value');
print(cookie.serialize()) // name=value
print(Cookie.parse('a=b;b=c')); // {a: b, b: c}
```

### Utils

- `Cookie.serialize` - Serialize a cookie instance to string.
- `Cookie.parse` - Parse client-side `cookie` header map.
- `Cookie.fromString` - Parse a set-cookie string to Cookie instance.
- `Cookie.splitSetCookie` - Split a string of multiple set-cookie values into a set-cookie string list.

# API Reference

See the [API documentation](https://pub.dev/documentation/ocookie) for detailed information about all available APIs.

## License

[MIT License](LICENSE)
