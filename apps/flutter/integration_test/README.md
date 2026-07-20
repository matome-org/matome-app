# integration_test — E2E flows (H1)

End-to-end flows that mirror the RN `apps/mobile/.maestro/*` flows. The product
suite runs against real Android, Linux desktop, and Chromium targets with
in-memory IO boundaries. Live capture tests remain separate because they need
host hardware and permissions.

## Product E2E matrix

These boot the real router, guard, screens, controllers, Drift schema, and upload
pipeline with platform-appropriate in-memory boundaries. Invoke one file per
Flutter command; the checked-in runners do this automatically.

```bash
# Linux desktop application target
./tool/run_e2e_linux.sh

# Chromium web target; requires chromedriver and Chromium
./tool/run_e2e_web.sh
```

The web runner passes `--no-web-resources-cdn` because the app CSP intentionally
blocks CDN scripts. Omitting it leaves CanvasKit blocked before tests start.

| File | Mirrors (maestro) | Covers |
| --- | --- | --- |
| `e2e_smoke_test.dart` | `smoke.yaml`, `auth-deeplink-guard.yaml` | cold boot → Welcome; Welcome → Login; unauth deep-link `/inbox` → Welcome |
| `e2e_auth_guard_test.dart` | `smoke.yaml` (login), `auth-deeplink-guard.yaml` | seeded and locked Vault sessions; logout; login; signup; forgot/reset password |
| `e2e_recording_flows_test.dart` | `record-pause-resume-finish.yaml`, `record-kill-recover.yaml`, `discard-cleanup.yaml`, `back-to-back-discard.yaml` | Native/Linux filesystem recording contract and upload pipeline |
| `e2e_recording_flows_web_test.dart` | same four recording flows | Browser-equivalent in-memory artifact contract and the real Inbox/Vault upload pipeline |
| `e2e_notes_transcript_test.dart` | notes/transcript regression | sync → edit notes → resync without transcript loss |
| `e2e_matome_overflow_sheet_test.dart` | Matome item actions | modal and detail routes survive router rebuilds |
| `e2e_matome_image_open_test.dart` | Matome image navigation | image open, auth tick, and back navigation |
| `e2e_image_detail_desktop_test.dart` | wide image detail | desktop/web-wide detail dispatch and slow Core behavior |
| `e2e_use_case_surfaces_test.dart` | UC-06 through UC-12 | Spaces, Contacts, Calendar, Files, typed Items, Settings, and Satori redirect |

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
