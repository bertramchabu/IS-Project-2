# Track 6 Evidence - Security and Test Hardening

## UTC
`2026-11-23`

## Files changed
- `lib/data/models/user_models.dart` - unknown role no longer maps to Network Administrator.
- `lib/core/router/app_router.dart` - unknown role routes to Contact Administrator.
- `model/main.py` - unknown role IDs receive explicit 403.
- `model/api/app.py` - CORS allowlist environment variable.
- `firestore.rules` - direct user MFA toggling is excluded; only system admins can update profile fields except mfaEnabled.
- `test/firestore_rules/rules_test_spec.json`
- `test/firestore_rules/rules_test.dart`
- `.github/workflows/rules-test.yml`
- `model/tests/test_security_hardening.py`

## Commands

```powershell
Set-Location 'C:\Users\Bertram Chabu\Videos\github\IS-Project-2\model'
& '.\.venv\Scripts\python.exe' -m unittest discover -s tests -p 'test_security_hardening.py' -v

Set-Location 'C:\Users\Bertram Chabu\Videos\github\IS-Project-2'
flutter test test/firestore_rules/rules_test.dart --reporter expanded
flutter analyze lib/data/models/user_models.dart lib/core/router/app_router.dart
```

## Raw stdout/stderr

Python security tests:

```text
test_allowlist_parser_shape (test_security_hardening.CorsTests.test_allowlist_parser_shape) ... ok
test_unknown_roles_are_rejected_with_explicit_403 (test_security_hardening.UnknownRoleTests.test_unknown_roles_are_rejected_with_explicit_403) ... ok

Ran 2 tests in 0.002s

OK
```

Rules specification:

```text
rules test specification contains required security cases
+1: All tests passed!
```

Dart analyzer:

```text
Analyzing 2 items...
No issues found!
```

## MFA boundary

The app stores `mfaEnabled`, but no Firebase Identity Platform MFA enrollment,
second-factor challenge or enforcement was executed. Therefore this track does
not claim MFA is complete. Direct Firestore writes to `mfaEnabled` are restricted.

## CORS boundary

FastAPI now reads `FASTAPI_ALLOWED_ORIGINS` comma-separated allowlist and defaults
to `http://localhost:8000`. It no longer uses `allow_origins=["*"]`.

## Claims unlocked
- Unknown-role fallback is removed.
- Unknown roles route to Contact Administrator in Flutter.
- Unknown role IDs are rejected by network, threat and system callable checks.
- CORS wildcard is removed from source.
- Rules specification test and workflow exist.

## Claims NOT unlocked
- Real Firebase emulator rules tests were not executed.
- Firebase MFA enrollment, TOTP/SMS configuration and login challenge are not verified.
- Firestore rules and callables were not deployed in this turn.
