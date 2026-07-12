# integration_test — E2E flows (H1)

End-to-end flows that mirror the RN `apps/mobile/.maestro/*` flows. Split into
**headless** (CI-friendly, no device) and **live** (needs an Android
emulator/device with a mic).

## Headless E2E (CI — web / linux / android)

These boot the real router/guard/screens (or the real recording providers)
with in-memory fakes (in-memory Drift, in-memory token store, a fake auth repo,
and the injectable `FakeRecorderBackend`). They run under the normal flutter
test VM — **invoke one file per `flutter test` call** so Flutter does not try to
launch them on a desktop device:

```bash
flutter test integration_test/e2e_smoke_test.dart
flutter test integration_test/e2e_auth_guard_test.dart
flutter test integration_test/e2e_recording_flows_test.dart
```

| File | Mirrors (maestro) | Covers |
| --- | --- | --- |
| `e2e_smoke_test.dart` | `smoke.yaml`, `auth-deeplink-guard.yaml` | cold boot → Welcome; Welcome → Login; unauth deep-link `/inbox` → Welcome |
| `e2e_auth_guard_test.dart` | `smoke.yaml` (login), `auth-deeplink-guard.yaml` | seeded session → tabs; logout → Welcome; login from Welcome → tabs |
| `e2e_recording_flows_test.dart` | `record-pause-resume-finish.yaml`, `record-kill-recover.yaml`, `discard-cleanup.yaml`, `back-to-back-discard.yaml` | record→pause→resume→finish (full upload pipeline → Inbox done); kill→recover (draft); discard cleanup; back-to-back discard |

## Live E2E (Android emulator/device only)

`audio_recording_live_test.dart` drives the **real** native `record` recorder
(no fake) to de-risk the single-file pause/resume model on hardware. It cannot
run headless (needs a mic + a debug connection on a device):

```bash
# Android AVD `pixel7` available; grant RECORD_AUDIO first.
flutter test integration_test/audio_recording_live_test.dart -d <device>
```

## Notes

- `test/live_socket_derisk_test.dart` is a separate `live`-tagged unit test that
  needs the Core API on `:7001` + `LIVE_TOKEN` (`flutter test --tags live`). It
  is **not** an integration_test; it lives under `test/` and is skipped by
  default via `dart_test.yaml`.
