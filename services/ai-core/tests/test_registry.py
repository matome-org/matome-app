from pathlib import Path
from typing import get_type_hints

import pytest

from app.lifecycle import JobFailure
from app.processor import AudioProcessor
from app.registry import (
    ProcessorCapability,
    ProcessorRegistration,
    ProcessorRegistry,
    TranscriptOutput,
)


def test_current_processor_exposes_a_typed_v1_output() -> None:
    assert get_type_hints(AudioProcessor.__call__)["return"] == list[TranscriptOutput]


def test_registry_derives_capabilities_and_dispatches_supported_output() -> None:
    calls: list[tuple[bytes, dict[str, object]]] = []

    def processor(media: bytes, job: dict[str, object]) -> list[dict[str, object]]:
        calls.append((media, job))
        return [{"type": "transcript", "text": "kept behavior"}]

    registry = ProcessorRegistry(
        [
            ProcessorRegistration(
                capability=ProcessorCapability(
                    input_kind="audio",
                    outputs=("transcript",),
                    max_bytes=2_147_483_648,
                    content_types=("audio/wav", "audio/mpeg"),
                ),
                processor=processor,
            )
        ]
    )
    job = {"input": {"kind": "audio"}, "requested_outputs": ["transcript"]}

    assert registry.capabilities() == {
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
    assert registry(b"verified audio", job) == [
        {"type": "transcript", "text": "kept behavior"}
    ]
    assert calls == [(b"verified audio", job)]


def test_registry_rejects_unadvertised_outputs_before_processor_runs() -> None:
    called = False

    def processor(_media: bytes, _job: dict[str, object]) -> list[dict[str, object]]:
        nonlocal called
        called = True
        return []

    registry = ProcessorRegistry(
        [
            ProcessorRegistration(
                capability=ProcessorCapability(
                    input_kind="audio",
                    outputs=("transcript",),
                    max_bytes=100,
                    content_types=("audio/wav",),
                ),
                processor=processor,
            )
        ]
    )

    with pytest.raises(JobFailure) as failure:
        registry(
            b"audio",
            {"input": {"kind": "audio"}, "requested_outputs": ["summary"]},
        )

    assert failure.value.code == "unsupported_requested_output"
    assert failure.value.retryable is False
    assert not called


def test_extension_guide_pins_future_processors_and_security_boundaries() -> None:
    readme = (Path(__file__).parents[1] / "README.md").read_text()

    for term in (
        "summary",
        "title",
        "OCR",
        "document extraction",
        "embeddings",
        "classification",
        "typed v1 outputs",
        "runtime environment",
        "internal-only",
        "Core dispatch",
    ):
        assert term in readme
