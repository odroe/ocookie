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
