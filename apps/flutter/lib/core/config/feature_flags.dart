/// Build-time feature flags.
///
/// Values are supplied by the root `feature_flags.json`, consumed at build time
/// via `--dart-define-from-file=feature_flags.json` (already wired into the
/// `mise run flutter-web|linux|android` tasks). Edit that JSON to flip a screen
/// on or off, then rebuild.
///
/// Each flag is a `const bool.fromEnvironment`, so a disabled screen is *tree
/// shaken out of the binary* (its route branch sits behind a `const` `if`), not
/// merely hidden at runtime — which is the point of gating "na hora do build".
///
/// Precedence: an explicit `--dart-define=ff.screens.satori=false` overrides the
/// file, so a one-off build can flip a flag without editing JSON. Defaults are
/// ON, so a missing/empty file ships the full app.
///
/// To add a flag: add a key to `feature_flags.json`, a `const` here, and (for a
/// new screen) an entry in `ShellTab` (`lib/app/shell_tabs.dart`).
class FeatureFlags {
  const FeatureFlags._();

  static const bool calendar = bool.fromEnvironment(
    'ff.screens.calendar',
    defaultValue: true,
  );

  static const bool spaces = bool.fromEnvironment(
    'ff.screens.spaces',
    defaultValue: true,
  );

  static const bool satori = bool.fromEnvironment(
    'ff.screens.satori',
    defaultValue: true,
  );

  static const bool contacts = bool.fromEnvironment(
    'ff.screens.contacts',
    defaultValue: true,
  );

  /// Document import (#1449). Gates the generic "Add file" picker (pdf/docx/md/
  /// txt/…) on the Matome detail hub. Default OFF — v1 only STORES +
  /// stub-summarizes documents (no parsing/opening) and the Core size cap
  /// (#1448) must be deployed first, so the affordance ships dark. When OFF, the
  /// new picker config is the ONLY code that is gated out — every other path
  /// (Add photo, dynamic mediaType, the persisted extension column) is
  /// unconditional.
  static const bool documents = bool.fromEnvironment(
    'ff.documents',
    defaultValue: false,
  );

  /// Graduated navigation shell (DR-002, #1467/#1474). Default ON as of #1474
  /// (the cutover) — this is the highest regression surface in the migration, so
  /// rollback is deliberately a single flag flip: revert this `defaultValue` to
  /// `false` (or ship `--dart-define=ff.newNavShell=false`), no other code
  /// change. When OFF the shipped shell renders
  /// unchanged (notched `BottomAppBar` + center-docked mic FAB on mobile,
  /// Material `NavigationRail` on desktop). When ON the branded
  /// [MatomeBottomDock] (mobile) / [MatomeSidebar] (desktop) drive navigation,
  /// the destinations reorder to inbox · calendar · files · contacts · spaces,
  /// the Satori ROUTE is compiled out (not merely hidden — its shell branch sits
  /// behind a `const` `if (!newNavShell)`), and the `/files` destination becomes
  /// a shell branch. Rollback is a single flag flip back to OFF (revert this
  /// const / drop the `--dart-define`), no other code change.
  static const bool newNavShell = bool.fromEnvironment(
    'ff.newNavShell',
    defaultValue: true,
  );

  /// Local-first spaces (ADR-0006 / spec sync-gate-and-promotion, plan #102).
  /// Default OFF (dark) — this is the SINGLE-FLIP rollback switch for the whole
  /// item-organization-decoupled-from-sync behaviour. This ONE flag must drive
  /// every coupled piece together so a half-flipped state cannot occur:
  /// effective-space resolution (the #1493 resolver), loose capture, inbox
  /// behaviour, and sync gating (the operation-keyed drain/access gate). They
  /// flip as a unit, behind this const, or none of them do.
  ///
  /// W1 reality: nothing reads this yet — the #1493 resolver shipped DARK and
  /// the schema/behaviour land in later waves. The point of this task is that
  /// the single switch exists, is registered in the FeatureFlags registry the
  /// same way [newNavShell] / [documents] are, and has its dual-flag CI lane so
  /// both the OFF (shipped) and ON (future) realities stay green as later waves
  /// build behind it. Rollback is a single flag flip back to OFF (revert this
  /// const's `defaultValue`, or ship `--dart-define=ff.localFirstSpaces=false`),
  /// no other code change.
  static const bool localFirstSpaces = bool.fromEnvironment(
    'ff.localFirstSpaces',
    defaultValue: false,
  );
}
