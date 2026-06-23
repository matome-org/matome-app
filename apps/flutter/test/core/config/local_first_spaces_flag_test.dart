import 'package:flutter_test/flutter_test.dart';
import 'package:matome_flutter/core/config/feature_flags.dart';

/// Dual-flag lane for the `localFirstSpaces` single-flip rollback switch
/// (ADR-0006 / spec sync-gate-and-promotion, plan #102 W1).
///
/// `FeatureFlags.localFirstSpaces` is a `const bool.fromEnvironment`, so it
/// cannot be flipped at runtime — its value is baked in at build time by the
/// `ff.localFirstSpaces` dart-define. This file is therefore run TWICE by the
/// `flutter-design-system-check` gate, once with the define forced ON and once
/// forced OFF (mirroring the `ff.newNavShell` nav cutover lane). Each group
/// self-skips under the wrong build so each invocation proves exactly its
/// reality — and so the OFF (shipped) and ON (future-wave) states both stay
/// green as later waves wire behaviour behind this single flag.
const _flagDefine = bool.fromEnvironment(
  'ff.localFirstSpaces',
  defaultValue: false,
);

void main() {
  test('default is OFF / dark (no --dart-define)', () {
    // Guards the rollback contract: with no override the flag MUST ship dark, so
    // a build that forgets the define gets the safe (current) behaviour. Only
    // assert this in the no-override reality — the ON/OFF lanes below set it.
    if (const bool.hasEnvironment('ff.localFirstSpaces')) {
      return; // a dart-define is present → this is the ON or OFF lane, not the
      // default reality. The lane-specific groups assert that case.
    }
    expect(
      FeatureFlags.localFirstSpaces,
      isFalse,
      reason: 'localFirstSpaces must default OFF (single-flip rollback dark)',
    );
  });

  group('lane: ff.localFirstSpaces=false (OFF / shipped reality)', () {
    test(
      'flag resolves OFF',
      () {
        expect(
          FeatureFlags.localFirstSpaces,
          isFalse,
          reason: 'forced-OFF build must read the flag as OFF',
        );
      },
      skip: _flagDefine
          ? 'OFF-only: this build forced ff.localFirstSpaces=true'
          : false,
    );
  });

  group('lane: ff.localFirstSpaces=true (ON / future-wave reality)', () {
    test(
      'flag resolves ON',
      () {
        expect(
          FeatureFlags.localFirstSpaces,
          isTrue,
          reason: 'forced-ON build must read the flag as ON',
        );
      },
      skip: _flagDefine
          ? false
          : 'ON-only: this build did not force ff.localFirstSpaces=true',
    );
  });
}
