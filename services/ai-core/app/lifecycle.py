import hashlib
import json
import logging
import sqlite3
import threading
import urllib.error
import urllib.request
from collections.abc import Callable
from pathlib import Path
from typing import Any


logger = logging.getLogger("matome.ai_core")
MAX_MEDIA_BYTES = 2_147_483_648


class JobFailure(Exception):
    def __init__(self, code: str, message: str, retryable: bool) -> None:
        super().__init__(message)
        self.code = code
        self.message = message
        self.retryable = retryable


MediaFetcher = Callable[[str, int], bytes]
Executor = Callable[[bytes, dict[str, Any]], list[dict[str, Any]]]
CallbackSender = Callable[[str, str, bytes], bool]


class JobService:
    def __init__(
        self,
        data_path: Path,
        *,
        media_fetcher: MediaFetcher | None = None,
        executor: Executor | None = None,
        callback_sender: CallbackSender | None = None,
        retry_delay: float = 1.0,
    ) -> None:
        data_path.parent.mkdir(parents=True, exist_ok=True)
        self._connection = sqlite3.connect(data_path, check_same_thread=False)
        self._connection.execute("PRAGMA journal_mode=WAL")
        self._connection.execute(
            """
            CREATE TABLE IF NOT EXISTS jobs (
                identity TEXT PRIMARY KEY,
                fingerprint TEXT NOT NULL,
                job_json TEXT NOT NULL,
                state TEXT NOT NULL CHECK (state IN ('accepted', 'terminal', 'delivered')),
                terminal_body BLOB,
                callback_attempts INTEGER NOT NULL DEFAULT 0
            )
            """
        )
        self._connection.commit()
        self._media_fetcher = media_fetcher or fetch_media
        self._executor = executor or unavailable_executor
        self._callback_sender = callback_sender or send_callback
        self._retry_delay = retry_delay
        self._lock = threading.RLock()
        self._scheduled: set[str] = set()
        self._timers: set[threading.Timer] = set()
        self._active = False

    def start(self) -> None:
        with self._lock:
            self._active = True
            identities = self._connection.execute(
                "SELECT identity FROM jobs WHERE state != 'delivered'"
            ).fetchall()
        for (identity,) in identities:
            self._schedule(identity, 0)

    def stop(self) -> None:
        with self._lock:
            self._active = False
            timers = list(self._timers)
            self._timers.clear()
        for timer in timers:
            timer.cancel()

    def close(self) -> None:
        self.stop()
        with self._lock:
            self._connection.close()

    def accept(self, job: dict[str, Any]) -> str:
        identity = identity_key(job)
        fingerprint = semantic_fingerprint(job)
        serialized = canonical_json(job)

        with self._lock:
            existing = self._connection.execute(
                "SELECT fingerprint, state FROM jobs WHERE identity = ?", (identity,)
            ).fetchone()
            if existing:
                if existing[0] != fingerprint:
                    return "conflict"
                if existing[1] == "accepted":
                    self._connection.execute(
                        "UPDATE jobs SET job_json = ? WHERE identity = ?",
                        (serialized, identity),
                    )
                    self._connection.commit()
                return "replay"

            self._connection.execute(
                """
                INSERT INTO jobs (identity, fingerprint, job_json, state)
                VALUES (?, ?, ?, 'accepted')
                """,
                (identity, fingerprint, serialized),
            )
            self._connection.commit()

        log_event(logging.INFO, "job.accepted", job)
        self._schedule(identity, 0)
        return "accepted"

    def _schedule(self, identity: str, delay: float) -> None:
        with self._lock:
            if not self._active or identity in self._scheduled:
                return
            self._scheduled.add(identity)
            timer = threading.Timer(delay, self._run, args=(identity,))
            timer.daemon = True
            self._timers.add(timer)
            timer.start()

    def _run(self, identity: str) -> None:
        with self._lock:
            self._scheduled.discard(identity)
            self._timers.discard(threading.current_thread())
            if not self._active:
                return
            row = self._connection.execute(
                "SELECT job_json, state, terminal_body FROM jobs WHERE identity = ?",
                (identity,),
            ).fetchone()
        if not row or row[1] == "delivered":
            return

        job = json.loads(row[0])
        body = row[2]
        if row[1] == "accepted":
            body = self._terminal_body(job)
            with self._lock:
                if not self._active:
                    return
                self._connection.execute(
                    "UPDATE jobs SET state = 'terminal', terminal_body = ? WHERE identity = ?",
                    (body, identity),
                )
                self._connection.commit()

        delivered = False
        try:
            delivered = self._callback_sender(
                job["callback"]["url"],
                job["callback"]["headers"]["authorization"],
                bytes(body),
            )
        except Exception:
            delivered = False

        with self._lock:
            if not self._active:
                return
            if delivered:
                self._connection.execute(
                    "UPDATE jobs SET state = 'delivered' WHERE identity = ?", (identity,)
                )
                event = "job.callback_delivered"
            else:
                self._connection.execute(
                    """
                    UPDATE jobs SET callback_attempts = callback_attempts + 1
                    WHERE identity = ?
                    """,
                    (identity,),
                )
                event = "job.callback_retry"
            self._connection.commit()

        log_event(
            logging.INFO if delivered else logging.ERROR,
            event,
            job,
            None if delivered else "callback_delivery_failed",
        )
        if not delivered:
            self._schedule(identity, self._retry_delay)

    def _terminal_body(self, job: dict[str, Any]) -> bytes:
        identity = {
            "contract_version": "1",
            "job_id": job["job_id"],
            "run_id": job["run_id"],
            "item_id": job["item_id"],
            "input_revision": job["input_revision"],
        }
        try:
            media = job["input"]["media"]
            try:
                content = self._media_fetcher(media["url"], MAX_MEDIA_BYTES)
            except JobFailure:
                raise
            except Exception as error:
                raise JobFailure(
                    "input_fetch_failed", "Input could not be fetched.", True
                ) from error
            verify_media(content, media)
            outputs = self._executor(content, job)
            terminal = {**identity, "status": "done", "outputs": outputs}
        except JobFailure as failure:
            terminal = {
                **identity,
                "status": "failed",
                "error": {
                    "code": failure.code,
                    "message": failure.message,
                    "retryable": failure.retryable,
                },
            }
        except Exception:
            terminal = {
                **identity,
                "status": "failed",
                "error": {
                    "code": "processor_unavailable",
                    "message": "Processor temporarily unavailable.",
                    "retryable": True,
                },
            }
        return canonical_json(terminal).encode()


def identity_key(job: dict[str, Any]) -> str:
    return canonical_json([job["job_id"], job["run_id"], job["input_revision"]])


def semantic_fingerprint(job: dict[str, Any]) -> str:
    semantic = json.loads(canonical_json(job))
    media = semantic.get("input", {}).get("media")
    if media:
        media.pop("url", None)
        media.pop("expires_at", None)
    return hashlib.sha256(canonical_json(semantic).encode()).hexdigest()


def canonical_json(value: object) -> str:
    return json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=True)


def verify_media(content: bytes, media: dict[str, Any]) -> None:
    if (
        len(content) != media["byte_size"]
        or hashlib.sha256(content).hexdigest() != media["checksum_sha256"]
    ):
        raise JobFailure(
            "input_integrity_mismatch",
            "Input bytes did not match the declared integrity metadata.",
            False,
        )


def fetch_media(url: str, limit: int) -> bytes:
    try:
        with urllib.request.urlopen(url, timeout=30) as response:
            content = response.read(limit + 1)
    except (OSError, urllib.error.HTTPError) as error:
        raise JobFailure("input_fetch_failed", "Input could not be fetched.", True) from error
    if len(content) > limit:
        raise JobFailure(
            "input_too_large", "Input exceeded the advertised byte limit.", False
        )
    return content


def send_callback(url: str, authorization: str, body: bytes) -> bool:
    request = urllib.request.Request(
        url,
        data=body,
        method="POST",
        headers={"Authorization": authorization, "Content-Type": "application/json"},
    )
    try:
        with urllib.request.urlopen(request, timeout=10) as response:
            return 200 <= response.status < 300
    except (OSError, urllib.error.HTTPError):
        return False


def unavailable_executor(
    _media: bytes, _job: dict[str, Any]
) -> list[dict[str, Any]]:
    raise JobFailure(
        "processor_unavailable", "Processor temporarily unavailable.", True
    )


def log_event(
    level: int, event: str, job: dict[str, Any], code: str | None = None
) -> None:
    fields = {
        "job_id": job["job_id"],
        "run_id": job["run_id"],
        "input_revision": job["input_revision"],
    }
    if code:
        fields["code"] = code
    logger.log(level, "%s %s", event, fields)
