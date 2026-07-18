# UC-10 — Read & play item

> Part of the [Matome use-case catalog](../use-cases.md). Foundations:
> [PRD](../internal/prd.md) · [Architecture](../internal/architecture.md) ·
> [Requirements](../internal/requirements.md).

## Summary
A User opens an item's detail screen, which routes by media type. For audio, the screen plays/pauses/seeks either a local file or a presigned Core download URL, exposing duration, bitrate and size; the User reads the machine-generated transcript (read-only) and edits user-owned notes behind an unsaved-changes leave guard. A standalone plain-text Item opens at `/items/text/:id`; its body can be edited or deleted offline, independently of its machine summary and AI status, while durable sync work reconciles later. Failed processing can be retried as a new Core run while prior successful output remains visible; the client observes only that run through bounded polling. The item can be deleted or moved to a Space. Image and document Items render their typed outputs when available. Documents have no in-app preview: approved types open externally, while active or unknown content remains download-only.

## Actors
- **Primary:** User reading or playing back a captured item.
- **Secondary:** Core API (issues the presigned download URL, re-enqueues processing, deletes the Core row); Object Storage (serves the media via the presigned URL).

## Preconditions
- User is signed in.
- An item exists (reached from Matome UC-04 or Files UC-08).
- For cloud playback the item has a Core row.

## Main flow
1. User taps an item and the app routes by media type: `/items/audio/:id` for audio, `/items/image/:id` for image, `/items/document/:id` for document, or `/items/text/:id` for plain text.
2. For audio, the screen plays a local file when present, otherwise fetches a presigned download URL from Core and streams it; it shows duration, bitrate and size.
3. For documents, desktop opens an approved existing local PDF/plain-text/Office file through `Uri.file`; all other supported paths request a fresh owner-scoped HTTPS descriptor and hand it to the platform.
4. User reads the read-only machine-generated transcript or extracted document text and edits the user-owned notes.
5. User retries failed processing; Core creates a new run and the client observes that run through bounded owner-scoped polling.
6. For text, an edit commits the body to Drift and durable queue work before any network request. Core reconciliation uses `PATCH /api/items/:id/text` with `expected_source_revision`; AI summary and processing status remain separate from body and sync status.
7. User deletes the item or moves it to a Space. Text deletion first persists a local tombstone and durable work, then uses revision-guarded `DELETE /api/items/:id/text`; files additionally remove on-disk bytes.

## Alternate & exception flows
- Editing notes and leaving with unsaved changes triggers a leave guard before navigating away.
- A failed transcription surfaces the failure and offers the retry path; the client never processes media locally.
- Image items open in a fullscreen viewer. Documents show metadata plus external action state, never an internal preview.
- HTML/SVG/XML is attachment-only with an active-content warning; unknown types are download-only.
- Executables and scripts are rejected on import and are never handed to a launcher.
- A stale text edit/delete receives `409 version_conflict`; the app preserves the
  local body or deletion intent and shows an explicit sync conflict. It does not
  relabel the conflict as processing failure or silently overwrite newer Core data.

## Sequence
```mermaid
sequenceDiagram
  participant User
  participant Screen as FileDetailScreen
  participant Drift
  participant Core as Core API
  participant Storage as Object Storage
  User->>Screen: open audio item
  Screen->>Core: GET download-url
  Core-->>Screen: presigned url
  Screen->>Storage: stream media
  Storage-->>Screen: audio bytes
  User->>Screen: open document externally
  Screen->>Core: GET download-url
  Core-->>Screen: fresh policy + expiring signed HTTPS descriptor
  Screen->>Storage: external open/download
  User->>Screen: edit notes
  Screen->>Drift: save notes
  User->>Screen: retry transcription
  Screen->>Core: POST process
  Core-->>Screen: queued + new run id
  loop bounded current-run observation
    Screen->>Core: GET /api/items/:id
    Core-->>Screen: explicit state + typed outputs
  end
  User->>Screen: delete item
  Screen->>Drift: delete row and file
  Screen->>Core: DELETE recording
```

## Requirements satisfied
| Requirement | What it covers |
|---|---|
| **FR-ITM-1** | Open an audio item and play/pause/seek a local file or presigned URL, with duration/bitrate/size. |
| **FR-ITM-2** | Read the machine-generated transcript (read-only). |
| **FR-ITM-3** | Edit the item's user-owned notes behind a leave guard. |
| **FR-ITM-4** | Retry failed processing as a new run and observe it through bounded current-run polling. |
| **FR-ITM-5** | View an image item inline and fullscreen. |
| **FR-ITM-6** | View document metadata and safely open/download it externally without an internal renderer. |
| **FR-ITM-7** | Delete an item (on-disk file + Drift row + Core row) and move an item to a Space. |
| **FR-ITM-8** | Edit/delete standalone text locally first, then reconcile durable revision-guarded work with explicit conflicts. |
| **FR-ING-7** | Terminal status is observed through bounded owner-scoped polling; client timeout is non-authoritative. |
| **FR-ING-8** | Retry re-enqueues server-side; the client never processes media locally. |
| **NFR-SEC-2** | Object storage is reached only via short-lived presigned URLs. |
| **NFR-SYNC-1** | The UI watches the local DB; edits succeed offline and sync in the background. |

## Code anchors
- `apps/flutter/lib/features/details/file_detail_screen.dart` — `FileDetailScreen`: the media-typed detail host (playback, transcript, notes, leave guard, retry/delete/move).
- `apps/flutter/lib/features/details/details_controller.dart` — `delete`: removes the Drift row and, when present, the Core row.
- `apps/flutter/lib/app/router.dart` — routes `/items/audio/:id`, `/items/image/:id`, `/items/document/:id`, `/items/text/:id`.
- `apps/flutter/lib/features/items/text_item_host.dart` — standalone body editing/deletion, durable sync state, separate AI retry/status/summary rendering.
- `apps/flutter/lib/features/documents/document_open_service.dart` — local/remote fallback, HTTPS/expiry checks, and popup-safe external launch orchestration.
- `services/api/lib/matome_api/content/document_open_policy.ex` — filename/MIME classification and signed response override policy.
- `services/api/lib/matome_api_web/router.ex` — owner-scoped Item download, process, show, and delete routes.
