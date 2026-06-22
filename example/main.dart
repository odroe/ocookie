import 'package:ocookie/ocookie.dart';

Future<void> main() async {
  final requestCookies = Cookie.parse('sid=abc; theme=light');
  assert(requestCookies['sid'] == 'abc');
  assert(requestCookies['theme'] == 'light');

  final setCookie = Cookie(
    'sid',
    'abc',
    maxAge: const Duration(hours: 1),
    path: '/',
    httpOnly: true,
    secure: true,
    sameSite: CookieSameSite.lax,
  );
  assert(
    setCookie.serialize() ==
        'sid=abc; Max-Age=3600; Path=/; HttpOnly; Secure; SameSite=Lax',
  );

  final parsedSetCookie = Cookie.fromString(
    'theme=dark; Path=/account; HttpOnly',
  );
  assert(parsedSetCookie.name == 'theme');
  assert(parsedSetCookie.path == '/account');
  assert(parsedSetCookie.httpOnly);

  final jar = CookieJar();
  final receivedAt = DateTime.utc(2026, 1, 1);
  final setCookieValues = Cookie.splitSetCookie(
    'sid=abc; Path=/; HttpOnly, theme=dark; Path=/account',
  );

  await jar.save(
    Uri.parse('https://example.com/login'),
    setCookieValues,
    now: receivedAt,
  );

  final header = await jar.header(
    Uri.parse('https://example.com/account/settings'),
    now: receivedAt,
  );
  assert(header == 'theme=dark; sid=abc');
}
