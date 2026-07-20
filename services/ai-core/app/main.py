import os
import secrets
import tempfile
from contextlib import asynccontextmanager
from datetime import datetime
from pathlib import Path
from typing import Annotated, Literal

from fastapi import Depends, FastAPI, Header, HTTPException, status
from pydantic import BaseModel, ConfigDict, Field, HttpUrl

from app.lifecycle import (
    MAX_MEDIA_BYTES,
    CallbackSender,
    Executor,
    JobService,
    MediaFetcher,
)
from app.processor import create_audio_processor
from app.registry import (
    ProcessorCapability,
    ProcessorRegistration,
    ProcessorRegistry,
)


class ContractModel(BaseModel):
    model_config = ConfigDict(extra="forbid")


class MediaDescriptor(ContractModel):
    method: Literal["GET"]
    url: HttpUrl
    expires_at: datetime
    filename: str = Field(min_length=1, max_length=255)
    content_type: Literal["audio/wav", "audio/mpeg"]
    byte_size: int = Field(gt=0, le=2_147_483_648)
    checksum_sha256: str = Field(pattern=r"^[0-9a-f]{64}$")


class AudioInput(ContractModel):
    kind: Literal["audio"]
    media: MediaDescriptor


class CallbackHeaders(ContractModel):
    authorization: str = Field(min_length=1)


class CallbackDescriptor(ContractModel):
    method: Literal["POST"]
    url: HttpUrl
    deadline_at: datetime
    headers: CallbackHeaders


class JobMetadata(ContractModel):
    locale: str = Field(min_length=1, max_length=255)


class AudioTranscriptJob(ContractModel):
    contract_version: Literal["1"]
    job_id: str = Field(min_length=1, max_length=255)
    run_id: str = Field(min_length=1, max_length=255)
    item_id: int = Field(gt=0)
    input_revision: int = Field(gt=0)
    input: AudioInput
    requested_outputs: tuple[Literal["transcript"]]
    callback: CallbackDescriptor
    metadata: JobMetadata | None = None


class DispatchAcknowledgement(ContractModel):
    accepted: Literal[True] = True
    contract_version: Literal["1"] = "1"
    job_id: str
    run_id: str


def create_app(
    *,
    data_path: Path | None = None,
    dispatch_token: str | None = None,
    media_fetcher: MediaFetcher | None = None,
    executor: Executor | None = None,
    callback_sender: CallbackSender | None = None,
    retry_delay: float = 1.0,
    require_https_urls: bool | None = None,
) -> FastAPI:
    configured_path = data_path or Path(
        os.environ.get(
            "AI_JOB_DATA_PATH",
            Path(tempfile.gettempdir()) / "matome-ai-core" / "jobs.sqlite3",
        )
    )
    enforce_https = require_https_urls
    if enforce_https is None:
        enforce_https = os.environ.get("AI_REQUIRE_HTTPS_URLS", "").lower() in {
            "1",
            "true",
        }
    configured_token = dispatch_token or os.environ.get(
        "AI_ENGINE_DISPATCH_TOKEN", ""
    )
    if enforce_https and (
        len(configured_token.encode()) < 32 or configured_token.startswith("CHANGE_ME")
    ):
        raise RuntimeError(
            "production dispatch token must be a non-placeholder value of at least 32 bytes"
        )
    registry = ProcessorRegistry(
        [
            ProcessorRegistration(
                capability=ProcessorCapability(
                    input_kind="audio",
                    outputs=("transcript",),
                    max_bytes=MAX_MEDIA_BYTES,
                    content_types=("audio/wav", "audio/mpeg"),
                ),
                processor=executor or create_audio_processor(),
            )
        ]
    )
    service = JobService(
        configured_path,
        media_fetcher=media_fetcher,
        executor=registry,
        callback_sender=callback_sender,
        retry_delay=retry_delay,
    )

    @asynccontextmanager
    async def lifespan(_app: FastAPI):
        service.start()
        try:
            yield
        finally:
            service.close()

    application = FastAPI(
        title="Matome AI Core",
        docs_url=None,
        redoc_url=None,
        openapi_url=None,
        lifespan=lifespan,
    )

    def require_dispatch_token(
        authorization: Annotated[str | None, Header()] = None,
    ) -> None:
        expected = dispatch_token
        if expected is None:
            expected = os.environ.get("AI_ENGINE_DISPATCH_TOKEN", "")
        scheme, separator, presented = (authorization or "").partition(" ")
        valid = (
            bool(expected)
            and separator == " "
            and scheme.lower() == "bearer"
            and bool(presented)
            and secrets.compare_digest(presented, expected)
        )
        if not valid:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="invalid service credential",
                headers={"WWW-Authenticate": "Bearer"},
            )

    @application.get("/health")
    def health() -> dict[str, str]:
        return {"status": "ok"}

    @application.get(
        "/v1/capabilities", dependencies=[Depends(require_dispatch_token)]
    )
    def capabilities() -> dict[str, object]:
        return registry.capabilities()

    @application.post(
        "/v1/jobs",
        status_code=status.HTTP_202_ACCEPTED,
        response_model=DispatchAcknowledgement,
        dependencies=[Depends(require_dispatch_token)],
    )
    def accept_job(job: AudioTranscriptJob) -> DispatchAcknowledgement:
        payload = job.model_dump(mode="json")
        if enforce_https and (
            job.input.media.url.scheme != "https" or job.callback.url.scheme != "https"
        ):
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
                detail="media and callback URLs must use HTTPS",
            )
        if service.accept(payload) == "conflict":
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail={
                    "code": "idempotency_conflict",
                    "message": (
                        "The idempotency identity was already accepted with different input."
                    ),
                    "retryable": False,
                },
            )
        return DispatchAcknowledgement(job_id=job.job_id, run_id=job.run_id)

    return application


app = create_app()
