import 'package:flutter_test/flutter_test.dart';
import 'package:matome_flutter/features/auth/auth_controller.dart';

/// SECURITY invariant: auth breadcrumbs must reveal only the email *domain* —
/// never the local-part (the user identity) and never a credential. This test
/// is the guardrail so a future refactor of [emailDomainForLog] cannot silently
/// start leaking PII into `app.log`.
void main() {
  group('emailDomainForLog redaction', () {
    test('returns only the domain for a normal address', () {
      expect(emailDomainForLog('alice@example.com'), 'example.com');
    });

    test('never includes the local-part (the user identity)', () {
      const email = 'secret.user.name@corp.example.org';
      final out = emailDomainForLog(email);
      expect(out, 'corp.example.org');
      expect(out, isNot(contains('secret')));
      expect(out, isNot(contains('user')));
      expect(out, isNot(contains('@')));
    });

    test('uses the LAST @ so a quoted local-part cannot smuggle text out', () {
      // A pathological address with multiple @; only the final domain leaks.
      expect(emailDomainForLog('a@b@evil.test'), 'evil.test');
    });

    test('collapses to "unknown" when there is no domain', () {
      expect(emailDomainForLog('not-an-email'), 'unknown');
      expect(emailDomainForLog(''), 'unknown');
      expect(emailDomainForLog('trailing@'), 'unknown');
      expect(emailDomainForLog('@'), 'unknown');
    });

    test('a raw credential-looking string never round-trips its secret', () {
      // Defensive: even if a password were mistakenly passed, no '@' means the
      // whole thing is dropped to 'unknown' rather than echoed.
      const password = 'hunter2-SUPERSECRET';
      expect(emailDomainForLog(password), 'unknown');
      expect(emailDomainForLog(password), isNot(contains('hunter2')));
    });
  });
}
