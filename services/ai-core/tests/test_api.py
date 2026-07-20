import json
from pathlib import Path

import pytest
from fastapi.testclient import TestClient

from app.main import app, create_app


TOKEN = "test-dispatch-token-at-least-32-bytes"
AUTHORIZATION = {"Authorization": f"Bearer {TOKEN}"}
FIXTURE_PATH = (
    Path(__file__).parents[3] / "contracts" / "v1" / "fixtures" / "canonical.json"
)


@pytest.fixture(autouse=True)
def dispatch_token(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("AI_ENGINE_DISPATCH_TOKEN", TOKEN)


@pytest.fixture
def client() -> TestClient:
    return TestClient(app)


def test_health_is_public(client: TestClient) -> None:
    response = client.get("/health")

    assert response.status_code == 200
    assert response.json() == {"status": "ok"}


@pytest.mark.parametrize(
    "headers",
    [
        {},
        {"Authorization": "Bearer wrong-token"},
        {"Authorization": TOKEN},
        {"Authorization": f"Basic {TOKEN}"},
    ],
)
@pytest.mark.parametrize("method,path", [("get", "/v1/capabilities"), ("post", "/v1/jobs")])
def test_contract_routes_reject_missing_or_invalid_bearer(
    client: TestClient, method: str, path: str, headers: dict[str, str]
) -> None:
    response = client.request(method, path, headers=headers)

    assert response.status_code == 401
    assert response.headers["www-authenticate"] == "Bearer"


def test_capabilities_advertise_only_audio_transcription(client: TestClient) -> None:
    response = client.get("/v1/capabilities", headers=AUTHORIZATION)

    assert response.status_code == 200
    assert response.json() == {
        "contract_version": "1",
        "service": "matome-ai-core",
        "inputs": {
            "audio": {
                "enabled": True,
                "max_bytes": 2_147_483_648,
                "content_types": ["audio/wav", "audio/mpeg"],
                "outputs": ["transcript"],
            }
        },
    }


def test_job_skeleton_accepts_v1_audio_transcript_request(client: TestClient) -> None:
    fixture = json.loads(FIXTURE_PATH.read_text())["ai"]["jobs"]["audio"]
    fixture["requested_outputs"] = ["transcript"]

    response = client.post("/v1/jobs", headers=AUTHORIZATION, json=fixture)

    assert response.status_code == 202
    assert response.json() == {
        "accepted": True,
        "contract_version": "1",
        "job_id": fixture["job_id"],
        "run_id": fixture["run_id"],
    }


@pytest.mark.parametrize("url_field", ["media", "callback"])
def test_production_url_policy_rejects_insecure_job_urls(
    tmp_path: Path, url_field: str
) -> None:
    fixture = json.loads(FIXTURE_PATH.read_text())["ai"]["jobs"]["audio"]
    fixture["requested_outputs"] = ["transcript"]
    fixture["input"]["media"]["url"] = "https://media.example.test/audio.wav"
    fixture["callback"]["url"] = "https://core.example.test/api/v1/callback"
    if url_field == "media":
        fixture["input"]["media"]["url"] = "http://media.example.test/audio.wav"
    else:
        fixture["callback"]["url"] = "http://core.example.test/api/v1/callback"

    production_app = create_app(
        data_path=tmp_path / "jobs.sqlite3",
        dispatch_token=TOKEN,
        require_https_urls=True,
    )
    with TestClient(production_app) as production_client:
        response = production_client.post(
            "/v1/jobs", headers=AUTHORIZATION, json=fixture
        )

    assert response.status_code == 422
    assert response.json() == {"detail": "media and callback URLs must use HTTPS"}


@pytest.mark.parametrize(
    "token",
    ["too-short", "CHANGE_ME_GENERATE_RANDOM_DISPATCH_TOKEN_AT_LEAST_32_BYTES"],
)
def test_production_mode_rejects_weak_dispatch_credentials(
    tmp_path: Path, token: str
) -> None:
    with pytest.raises(
        RuntimeError,
        match="production dispatch token must be a non-placeholder value of at least 32 bytes",
    ):
        create_app(
            data_path=tmp_path / "jobs.sqlite3",
            dispatch_token=token,
            require_https_urls=True,
        )
