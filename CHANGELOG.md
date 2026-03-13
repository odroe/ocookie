## 0.2.0

### Breaking Changes

- `Cookie.httpOnly`, `Cookie.secure`, and `Cookie.partitioned` are now two-state flags with `false` defaults.
- Omitting those flags is now equivalent to setting them to `false`.
- Removed `CookieNullableField.httpOnly`, `CookieNullableField.secure`, and `CookieNullableField.partitioned`.
- Migrate `copyWith(clear: {...})` call sites by removing those deleted enum values and using omitted flags or explicit `false` instead.

### Parser Behavior

- `Cookie.fromString` now treats explicit `Secure=false`, `HttpOnly=false`, and `Partitioned=false` as disabled flags.
- Expanded `Set-Cookie` compatibility coverage for repeated attributes, quoted values containing `=`, unknown attributes, and combined header splitting around quoted commas and `Expires` dates.

### Tooling

- Updated `lints` to `6.1.0`.
- Updated `actions/checkout` to `v6`.

## 0.1.0

- add `Cookie.validate` for explicit pre-serialization checks
- add `Cookie` value equality (`==` and `hashCode`)
- add `copyWith(clear: {...})` to explicitly clear nullable fields
- harden `Cookie.fromString` validation and malformed-attribute handling
- improve `splitSetCookie` robustness with extra separators and whitespace
- enforce `Secure` requirements for `SameSite=None` and `Partitioned`
- expand tests with regression and deterministic fuzz coverage
- improve README usage docs for validation and `copyWith` clearing

## 0.0.1

- first publish
