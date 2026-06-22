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

  /// Graduated navigation shell (DR-002, #1467). Default OFF — the highest
  /// regression surface in the migration. When OFF the shipped shell renders
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
    defaultValue: false,
  );
}
