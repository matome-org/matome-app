# MEC1 compatibility

`matome_vault` preserves the format implemented by
`apps/flutter/lib/core/crypto/media_cipher.dart`; that app implementation is
not moved or wired to this package in W2.

## Frozen bytes

- Header: ASCII `MEC1`, version `0x01`, then a 4-byte random nonce prefix.
- Plaintext chunks: 64 KiB, except a non-empty final short chunk. Empty input is
  represented by the header alone.
- Frame: big-endian uint32 ciphertext length, ciphertext, 16-byte GCM tag.
- Cipher: AES-256-GCM under a fresh random 32-byte FEK per blob.
- Nonce: 4-byte file prefix followed by the 8-byte big-endian chunk index.
- AAD: the same 8-byte big-endian chunk index.
- Wrapped FEK: the existing 64-byte envelope `[01 02 00 01] || nonce(12) ||
  ciphertext(32) || tag(16)`, with its four-byte header as AES-GCM AAD. The
  Account DEK is the wrapping key.

The shared deterministic vector is:

| field | value |
| --- | --- |
| Account DEK | bytes `00` through `1f` |
| FEK | bytes `00` through `1f` |
| nonce prefix | `20 21 22 23` |
| envelope nonce | bytes `24` through `2f` |
| plaintext UTF-8 | `Matome MEC1 vector` |
| MEC1 blob base64 | `TUVDMQEgISIjAAAAEtV/WSDTQ7xsr0MhU60umHU97vs4deUYxZrFo/i9j2Txuzk=` |

`test/mec1_test.dart` freezes this blob and the envelope header; the public API
smoke carries a second compact deterministic vector so VM execution and Web
compilation exercise the same API. Randomness is injectable only to make
vectors repeatable; production callers use the default CSPRNG.

## Streaming and ranges

`Mec1CiphertextSource` is immutable and reopenable with half-open physical byte
bounds. A range read validates the header, computes the first frame offset as
`9 + chunkIndex * (4 + 65536 + 16)`, and reads only touched frames. Every
touched complete chunk is authenticated before any bytes from it are emitted.
The source's physical length determines and validates the final frame shape.

The core retains at most one 64 KiB plaintext chunk, one 64 KiB ciphertext
chunk, and the current source event. Oversized input stream events are consumed
incrementally without first copying the entire event. Output writes and stream
iteration are awaited, providing backpressure; cancelling a decrypt stream
cancels its active source iterator. Callers must avoid producing unbounded
single stream events because the producer already owns that event's memory.
