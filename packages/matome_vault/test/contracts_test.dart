import 'package:matome_vault/matome_vault.dart';
import 'package:test/test.dart';

void main() {
  group('opaque identifiers', () {
    test('reject blank values and compare by value', () {
      expect(() => VaultBlobId('  '), throwsArgumentError);
      expect(() => VaultBlobId('../other-account'), throwsArgumentError);
      expect(() => VaultBlobId('folder/blob'), throwsArgumentError);
      expect(VaultBlobId('blob-1'), VaultBlobId('blob-1'));
      expect(VaultAccountId('account-1'), VaultAccountId('account-1'));
    });
  });

  group('PlaintextRange', () {
    test('uses half-open bounds', () {
      final range = PlaintextRange(start: 4, endExclusive: 11);
      expect(range.length, 7);
    });

    test('rejects empty, reversed and negative ranges', () {
      expect(
        () => PlaintextRange(start: -1, endExclusive: 1),
        throwsRangeError,
      );
      expect(() => PlaintextRange(start: 2, endExclusive: 2), throwsRangeError);
      expect(() => PlaintextRange(start: 3, endExclusive: 2), throwsRangeError);
    });
  });

  group('VaultBlobStat', () {
    test('requires plaintext size for ready blobs', () {
      expect(
        () => VaultBlobStat(
          id: VaultBlobId('blob-1'),
          state: VaultBlobState.ready,
        ),
        throwsArgumentError,
      );
    });

    test('keeps logical and physical sizes distinct', () {
      final stat = VaultBlobStat(
        id: VaultBlobId('blob-1'),
        state: VaultBlobState.ready,
        plaintextLength: 8,
        physicalLength: 37,
        plaintextSha256: 'a' * 64,
      );

      expect(stat.plaintextLength, 8);
      expect(stat.physicalLength, 37);
      expect(stat.cipherFormat, VaultCipherFormat.mec1);
      expect(stat.cipherVersion, 1);
    });

    test('allows missing blobs to report unknown physical size', () {
      final stat = VaultBlobStat(
        id: VaultBlobId('blob-1'),
        state: VaultBlobState.missing,
      );

      expect(stat.physicalLength, isNull);
      expect(stat.plaintextLength, isNull);
    });

    test('rejects malformed plaintext digests', () {
      expect(
        () => VaultBlobStat(
          id: VaultBlobId('blob-1'),
          state: VaultBlobState.staging,
          physicalLength: 10,
          plaintextSha256: 'not-a-digest',
        ),
        throwsArgumentError,
      );
    });
  });

  test('reconciliation reports are immutable', () {
    final source = <VaultReconciliationRecord>[];
    final report = VaultReconciliationReport(source);
    source.add(
      VaultReconciliationRecord(
        blobId: VaultBlobId('blob-1'),
        issue: VaultReconciliationIssue.expiredLease,
        action: VaultReconciliationAction.revokedLease,
      ),
    );

    expect(report.records, isEmpty);
    expect(() => report.records.clear(), throwsUnsupportedError);
  });
}
