import hashlib
import json
import logging
import sqlite3
import threading
from pathlib import Path

import pytest
from fastapi.testclient import TestClient

from app.main import create_app
from app.processor import AudioProcessor


TOKEN = "test-dispatch-token"
AUTHORIZATION = {"Authorization": f"Bearer {TOKEN}"}
FIXTURE_PATH = (
    Path(__file__).parents[3] / "contracts" / "v1" / "fixtures" / "canonical.json"
)
MEDIA = b"fixture audio bytes"


def audio_job() -> dict[str, object]:
    job = json.loads(FIXTURE_PATH.read_text())["ai"]["jobs"]["audio"]
    job["requested_outputs"] = ["transcript"]
    job["input"]["media"].update(
        {
            "url": "https://storage.invalid/audio?signature=media-secret",
            "byte_size": len(MEDIA),
            "checksum_sha256": hashlib.sha256(MEDIA).hexdigest(),
        }
    )
    job["callback"].update(
        {
            "url": "https://core.invalid/result?signature=callback-secret",
            "headers": {"authorization": "Bearer callback-secret"},
        }
    )
    return job


def client_for(tmp_path: Path, **options: object) -> TestClient:
    return TestClient(
        create_app(
            data_path=tmp_path / "jobs.sqlite3",
            dispatch_token=TOKEN,
            retry_delay=0.01,
            **options,
        )
    )


def wait_for(event: threading.Event) -> None:
    assert event.wait(2), "timed out waiting for lifecycle worker"


def test_acceptance_is_durable_before_202_and_executor_runs(tmp_path: Path) -> None:
    executed = threading.Event()

    def executor(media: bytes, _job: dict[str, object]) -> list[dict[str, object]]:
        assert media == MEDIA
        with sqlite3.connect(tmp_path / "jobs.sqlite3") as connection:
            assert connection.execute("SELECT count(*) FROM jobs").fetchone() == (1,)
        executed.set()
        return [{"type": "transcript", "text": "placeholder transcript"}]

    delivered = threading.Event()

    def callback_sender(_url: str, _authorization: str, _body: bytes) -> bool:
        delivered.set()
        return True

    with client_for(
        tmp_path,
        media_fetcher=lambda _url, _limit: MEDIA,
        executor=executor,
        callback_sender=callback_sender,
    ) as client:
        job = audio_job()
        response = client.post("/v1/jobs", headers=AUTHORIZATION, json=job)

        assert response.status_code == 202
        assert response.json() == {
            "accepted": True,
            "contract_version": "1",
            "job_id": job["job_id"],
            "run_id": job["run_id"],
        }
        wait_for(executed)
        wait_for(delivered)


def test_verified_audio_runs_through_processor_and_delivers_transcript(
    tmp_path: Path,
) -> None:
    delivered = threading.Event()
    callbacks: list[dict[str, object]] = []

    class Backend:
        def transcribe(self, wav_path: Path, *, language: str | None) -> str:
            assert wav_path.read_bytes() == b"converted wav"
            return "integration transcript"

    processor = AudioProcessor(
        backend_factory=lambda: Backend(),
        transcoder=lambda media, content_type: (
            b"converted wav"
            if (media, content_type) == (MEDIA, "audio/wav")
            else pytest.fail("processor did not receive verified lifecycle input")
        ),
        temporary_directory=tmp_path,
    )

    def callback_sender(_url: str, _authorization: str, body: bytes) -> bool:
        callbacks.append(json.loads(body))
        delivered.set()
        return True

    with client_for(
        tmp_path,
        media_fetcher=lambda _url, _limit: MEDIA,
        executor=processor,
        callback_sender=callback_sender,
    ) as client:
        assert client.post(
            "/v1/jobs", headers=AUTHORIZATION, json=audio_job()
        ).status_code == 202
        wait_for(delivered)

    assert callbacks[0]["status"] == "done"
    assert callbacks[0]["outputs"] == [
        {"type": "transcript", "text": "integration transcript"}
    ]


def test_accepted_work_resumes_from_durable_storage_after_restart(tmp_path: Path) -> None:
    fetch_started = threading.Event()
    release_first_worker = threading.Event()
    delivered = threading.Event()

    def blocked_fetcher(_url: str, _limit: int) -> bytes:
        fetch_started.set()
        release_first_worker.wait()
        return MEDIA

    with client_for(
        tmp_path,
        media_fetcher=blocked_fetcher,
        callback_sender=lambda _url, _authorization, _body: True,
    ) as first:
        response = first.post("/v1/jobs", headers=AUTHORIZATION, json=audio_job())
        assert response.status_code == 202
        wait_for(fetch_started)

    def callback_sender(_url: str, _authorization: str, _body: bytes) -> bool:
        delivered.set()
        return True

    with client_for(
        tmp_path,
        media_fetcher=lambda _url, _limit: MEDIA,
        executor=lambda _media, _job: [
            {"type": "transcript", "text": "placeholder transcript"}
        ],
        callback_sender=callback_sender,
    ):
        wait_for(delivered)

    release_first_worker.set()


def test_semantic_replay_is_idempotent_and_changed_input_conflicts(tmp_path: Path) -> None:
    blocker = threading.Event()
    with client_for(
        tmp_path,
        media_fetcher=lambda _url, _limit: blocker.wait(1) or MEDIA,
        callback_sender=lambda _url, _authorization, _body: True,
    ) as client:
        job = audio_job()
        first = client.post("/v1/jobs", headers=AUTHORIZATION, json=job)

        replay = json.loads(json.dumps(job))
        replay["input"]["media"]["url"] = "https://storage.invalid/audio?signature=renewed"
        replay["input"]["media"]["expires_at"] = "2026-07-15T12:45:00Z"
        second = client.post("/v1/jobs", headers=AUTHORIZATION, json=replay)

        changed = json.loads(json.dumps(job))
        changed["metadata"] = {"locale": "ja"}
        conflict = client.post("/v1/jobs", headers=AUTHORIZATION, json=changed)
        blocker.set()

        assert first.status_code == second.status_code == 202
        assert first.json() == second.json()
        assert conflict.status_code == 409
        assert conflict.json()["detail"]["code"] == "idempotency_conflict"


@pytest.mark.parametrize(
    ("fetcher", "expected_code"),
    [
        (lambda _url, _limit: (_ for _ in ()).throw(OSError("private URL")), "input_fetch_failed"),
        (lambda _url, _limit: MEDIA + b"too long", "input_integrity_mismatch"),
        (lambda _url, _limit: b"wrong checksum bytes", "input_integrity_mismatch"),
    ],
)
def test_media_failures_create_terminal_failed_envelopes(
    tmp_path: Path, fetcher: object, expected_code: str
) -> None:
    delivered = threading.Event()
    callbacks: list[dict[str, object]] = []

    def callback_sender(_url: str, _authorization: str, body: bytes) -> bool:
        callbacks.append(json.loads(body))
        delivered.set()
        return True

    with client_for(
        tmp_path,
        media_fetcher=fetcher,
        callback_sender=callback_sender,
    ) as client:
        response = client.post("/v1/jobs", headers=AUTHORIZATION, json=audio_job())
        assert response.status_code == 202
        wait_for(delivered)

    assert callbacks[0]["status"] == "failed"
    assert callbacks[0]["error"]["code"] == expected_code
    assert set(callbacks[0]) == {
        "contract_version",
        "job_id",
        "run_id",
        "item_id",
        "input_revision",
        "status",
        "error",
    }


def test_callback_retry_reuses_persisted_bytes_and_job_authorization(tmp_path: Path) -> None:
    delivered = threading.Event()
    attempts: list[tuple[str, str, bytes]] = []

    def callback_sender(url: str, authorization: str, body: bytes) -> bool:
        attempts.append((url, authorization, body))
        if len(attempts) == 2:
            delivered.set()
            return True
        return False

    with client_for(
        tmp_path,
        media_fetcher=lambda _url, _limit: MEDIA,
        executor=lambda _media, _job: [
            {"type": "transcript", "text": "placeholder transcript"}
        ],
        callback_sender=callback_sender,
    ) as client:
        response = client.post("/v1/jobs", headers=AUTHORIZATION, json=audio_job())
        assert response.status_code == 202
        wait_for(delivered)

    assert attempts[0][0] == "https://core.invalid/result?signature=callback-secret"
    assert attempts[0][1] == "Bearer callback-secret"
    assert attempts[0][2] == attempts[1][2]
    terminal = json.loads(attempts[0][2])
    assert terminal["status"] == "done"
    assert terminal["outputs"] == [
        {"type": "transcript", "text": "placeholder transcript"}
    ]


def test_logs_exclude_urls_credentials_and_user_content(
    tmp_path: Path, caplog: pytest.LogCaptureFixture
) -> None:
    retried = threading.Event()

    def callback_sender(_url: str, _authorization: str, _body: bytes) -> bool:
        retried.set()
        return False

    caplog.set_level(logging.INFO, logger="matome.ai_core")
    with client_for(
        tmp_path,
        media_fetcher=lambda _url, _limit: MEDIA,
        executor=lambda _media, _job: [
            {"type": "transcript", "text": "private transcript text"}
        ],
        callback_sender=callback_sender,
    ) as client:
        response = client.post("/v1/jobs", headers=AUTHORIZATION, json=audio_job())
        assert response.status_code == 202
        wait_for(retried)

    logs = caplog.text
    assert "media-secret" not in logs
    assert "callback-secret" not in logs
    assert "private transcript text" not in logs
    assert TOKEN not in logs
    assert "standup.wav" not in logs
