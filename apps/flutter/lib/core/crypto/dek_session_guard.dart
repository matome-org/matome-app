// Minimizes how long the decrypted DEK sits live in the JS heap — task
// #1861, plan #131 (web wave), the hardening pass on top of #1860's OPFS
// persistence.
//
// WHY THIS EXISTS: before #1860, a page reload dropped the in-memory sqlite3
// store and its DEK for free (the store was never persisted). Now that the
// encrypted DB image survives across reloads (`web_opfs_blob_store.dart`),
// the DEK the cold-start unwrap produces (`web_store_opener.dart`'s
// `WebColdStartResult.dek`) is held in memory for the *entire* session —
// exactly the object `Timer.periodic` in `connection_web.dart` keeps calling
// `WebStoreOpener.persist(dek: ...)` with. A same-origin XSS that reads that
// live reference gets the key that opens every persisted byte, for as long
// as the tab stays open. This class bounds that window: explicit lock,
// explicit logout, and an idle timeout all zero the key (`Dek.wipe()`,
// `key_material.dart`) and require a full re-unlock (a fresh `adopt()`,
// which in the real flow means re-running the password → KEK → unwrap →
// `WebStoreOpener.open` core) before the store can be used again.
//
// HONEST LIMIT (do not overclaim): this narrows the window, it does not
// close it. While the guard reports `isUnlocked == true`, the DEK is live in
// the heap and a compromised *running* tab (active XSS, malicious
// extension, browser 0-day) still reads it — see
// `.docs/internal/at-rest-key-flow.md` §6 item 5. Encryption defends data
// AT REST; it cannot defend a live, compromised session holding the key
// that opens it.
import 'dart:async';

import 'key_material.dart' show Dek;

/// Why a wipe happened — surfaced to callers/tests so UI can react
/// differently (e.g. "re-enter your password" for [lock]/[idleTimeout] vs.
/// dropping straight to the signed-out/welcome screen for [logout]).
enum DekWipeReason { lock, logout, idleTimeout }

/// Holds the single live DEK for a web session and enforces that it is
/// wiped — not just dereferenced, but its bytes zeroed via [Dek.wipe] — on
/// [lock], [logout], and an inactivity timeout.
///
/// This class owns no I/O of its own (no OPFS, no network): callers wire
/// [adopt] to the moment a cold-start/login unwrap succeeds
/// (`WebColdStartResult.dek`), call [noteActivity] on user interaction /
/// successful API calls, and call [lock]/[logout] from the corresponding UI
/// actions. After any wipe, [current] is `null` and stays `null` until
/// [adopt] is called again with a freshly re-unwrapped key — there is no
/// path in this class that resurrects a wiped key.
class DekSessionGuard {
  DekSessionGuard({
    this.idleTimeout = const Duration(minutes: 15),
    this.onWipe,
    Timer Function(Duration duration, void Function() callback)? timerFactory,
  }) : _timerFactory = timerFactory ?? Timer.new;

  /// How long the DEK may sit idle (no [noteActivity] call) before it is
  /// automatically wiped. Default: 15 minutes — long enough not to nag a
  /// user mid-task, short enough to bound a forgotten unattended tab.
  final Duration idleTimeout;

  /// Optional hook invoked with the reason every time a wipe happens (lock,
  /// logout, or idle timeout). Wiring point for UI (e.g. show a "session
  /// locked, please sign in again" prompt) and for tests.
  final void Function(DekWipeReason reason)? onWipe;

  final Timer Function(Duration duration, void Function() callback)
  _timerFactory;

  Dek? _dek;
  Timer? _idleTimer;

  /// The live DEK, or `null` if locked/logged-out/idle-timed-out/never
  /// adopted. Callers must treat a `null` here as "the store is locked" —
  /// re-open requires the real unlock flow (password → KEK → unwrap), not
  /// re-reading this field.
  Dek? get current => _dek;

  /// `true` exactly when [current] is non-null.
  bool get isUnlocked => _dek != null;

  /// Adopts [dek] as the live session key (e.g. the result of a successful
  /// cold-start/login unwrap) and (re)starts the idle-timeout clock.
  ///
  /// If a DEK is already live (e.g. a re-unlock/re-login flow adopts a new
  /// key without an intervening [lock]/[logout]), the previous DEK's bytes
  /// are wiped in place before the reference is replaced (okt-audit B3
  /// info follow-up) — otherwise the old plaintext key would keep sitting
  /// live in the heap with no reachable reference to ever wipe it.
  void adopt(Dek dek) {
    final previous = _dek;
    if (previous != null && !identical(previous, dek)) {
      previous.wipe();
    }
    _dek = dek;
    _restartIdleTimer();
  }

  /// Call on every sign of live user/session activity (keystroke, pointer
  /// event, successful API call, ...) to push the idle timeout back out.
  /// A no-op when nothing is currently unlocked.
  void noteActivity() {
    if (_dek == null) return;
    _restartIdleTimer();
  }

  void _restartIdleTimer() {
    _idleTimer?.cancel();
    _idleTimer = _timerFactory(
      idleTimeout,
      () => _wipe(DekWipeReason.idleTimeout),
    );
  }

  /// Explicit lock (e.g. a "lock now" affordance, or the app losing focus
  /// under a stricter policy). Wipes the DEK; re-opening requires the full
  /// unlock flow again. A no-op (does not throw) if already locked.
  void lock() => _wipe(DekWipeReason.lock);

  /// Explicit logout. Wipes the DEK; re-opening requires signing in again.
  /// A no-op (does not throw) if already locked.
  void logout() => _wipe(DekWipeReason.logout);

  void _wipe(DekWipeReason reason) {
    _idleTimer?.cancel();
    _idleTimer = null;
    final dek = _dek;
    if (dek == null) return; // nothing to wipe — already locked
    _dek = null;
    dek.wipe();
    onWipe?.call(reason);
  }

  /// Cancels any pending idle timer WITHOUT wiping the current key.
  /// Deliberately distinct from [lock]/[logout] — this is teardown for the
  /// guard object itself (e.g. a widget/provider disposing), not a security
  /// action. Callers that also want the key wiped on dispose should call
  /// [lock] or [logout] first.
  void dispose() {
    _idleTimer?.cancel();
    _idleTimer = null;
  }
}
