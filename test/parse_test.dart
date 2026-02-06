import 'dart:convert';

import 'package:ocookie/ocookie.dart';
import 'package:test/test.dart';

void main() {
  group('Cookie.parse', () {
    test('should parse cookie string to object', () {
      expect(Cookie.parse('foo=bar'), {'foo': 'bar'});
      expect(Cookie.parse('bar=124'), {'bar': '124'});
    });

    test('should ignore OWS', () {
      expect(Cookie.parse('FOO    = bar;   baz  =   raz'), {
        'FOO': 'bar',
        'baz': 'raz',
      });
    });

    test('should parse cookie with empty value', () {
      expect(Cookie.parse('foo= ; bar='), {'foo': '', 'bar': ''});
    });

    test('should URL-decode values', () {
      expect(Cookie.parse('email=%20%22%2c%3b%2f'), {'email': ' ",;/'});
    });

    test('should return original value on escape error', () {
      expect(Cookie.parse('foo=%1;bar=bar'), {'foo': '%1', 'bar': 'bar'});
    });

    test('should ignore cookies without value', () {
      expect(Cookie.parse('foo=bar;fizz  ;  buzz'), {'foo': 'bar'});
    });

    test('should ignore duplicate cookies', () {
      expect(
        Cookie.parse('foo=%1;bar=bar;foo=boo'),
        {'foo': '%1', 'bar': 'bar'},
      );
      expect(
        Cookie.parse('foo=false;bar=bar;foo=true'),
        {'foo': 'false', 'bar': 'bar'},
      );
      expect(
        Cookie.parse('foo=;bar=bar;foo=boo'),
        {'foo': '', 'bar': 'bar'},
      );
    });

    test('should ignore cookies with empty names', () {
      expect(Cookie.parse('=bar;foo=baz'), {'foo': 'baz'});
    });

    test('should only unquote fully quoted values', () {
      expect(
        Cookie.parse('foo="bar";baz=1'),
        {'foo': 'bar', 'baz': '1'},
      );
      expect(
        Cookie.parse('foo="bar;baz=1'),
        {'foo': '"bar', 'baz': '1'},
      );
    });

    test('should not throw on malformed opening quote only', () {
      expect(
        Cookie.parse('foo=";bar=2'),
        {'foo': '"', 'bar': '2'},
      );
    });
  });

  group('Cookie.parse with options', () {
    test('decode', () {
      expect(
        Cookie.parse(
          'foo="YmFy"',
          decode: (value) => utf8.decode(base64.decode(value)),
        ),
        {'foo': 'bar'},
      );
    });

    test('filter', () {
      expect(
        Cookie.parse(
          'a=1;b=2',
          filter: (key) => key == 'a',
        ),
        {'a': '1'},
      );
    });
  });
}
