import 'package:flutter_test/flutter_test.dart';
import 'package:matome_flutter/core/logging/log_redaction.dart';

// ---------------------------------------------------------------------------
// Socket log-redaction guard (SEC audit-fix #815). Proves the Guardian JWT in
// the phoenix_socket connect URL is stripped from log messages.
// ---------------------------------------------------------------------------

void main() {
  group('redactSensitiveQueryParams', () {
    test('redacts the token from a phoenix_socket connect log line', () {
      const jwt = 'eyJhbGciOiJIUzI1NiJ9.payload.signature-AbC_123';
      final line =
          'Attempting to connect to '
          'wss://api.example.com/socket/websocket?vsn=2.0.0&token=$jwt';

      final out = redactSensitiveQueryParams(line);

      expect(out, isNot(contains(jwt)));
      expect(out, contains('token=[REDACTED]'));
      // Non-sensitive params are preserved.
      expect(out, contains('vsn=2.0.0'));
      expect(out, contains('wss://api.example.com/socket/websocket'));
    });

    test('redacts a planned ticket param too', () {
      final out = redactSensitiveQueryParams(
        'connect ...?ticket=abc123def&vsn=2.0.0',
      );
      expect(out, contains('ticket=[REDACTED]'));
      expect(out, isNot(contains('abc123def')));
    });

    test('leaves messages without sensitive params untouched', () {
      const msg = 'Socket open';
      expect(redactSensitiveQueryParams(msg), msg);
    });

    test('redacts token at end of string (no trailing &)', () {
      final out = redactSensitiveQueryParams('url?token=tail.jwt.value');
      expect(out, 'url?token=[REDACTED]');
    });

    test('redacts OTP, bearer, refresh/reset tokens, and auth secrets', () {
      const secrets = [
        '123456',
        'bearer-secret',
        'refresh-secret',
        'reset-secret',
        'client-secret',
      ];
      final out = redactSensitiveLogData(
        'code=123456 Authorization: Bearer bearer-secret '
        'refresh_token=refresh-secret reset_token=reset-secret '
        'client_secret=client-secret',
      );

      for (final secret in secrets) {
        expect(out, isNot(contains(secret)));
      }
    });

    test('redacts content fields, local paths, and presigned credentials', () {
      final out = redactSensitiveLogData(
        'body="private words" notes=private-note '
        'path=/home/alice/Matome/audio.wav '
        'url=https://storage.test/object?X-Amz-Credential=credential&'
        'X-Amz-Signature=signature&X-Amz-Security-Token=session',
      );

      for (final secret in [
        'private words',
        'private-note',
        'alice',
        'audio.wav',
        'credential',
        'signature',
        'session',
      ]) {
        expect(out, isNot(contains(secret)));
      }
    });

    test('redacts Android private paths and ephemeral Vault URLs', () {
      final out = redactSensitiveLogData(
        'FileSystemException: /data/user/0/com.matome/files/audio.lease '
        'preview=blob:https://matome.test/private-object-id '
        'file=file:///private/var/mobile/document.lease',
      );

      expect(out, isNot(contains('/data/user')));
      expect(out, isNot(contains('private-object-id')));
      expect(out, isNot(contains('/private/var/mobile')));
      expect(out, contains('[REDACTED_PATH]'));
      expect(out, contains('[REDACTED_URI]'));
    });
  });
}
