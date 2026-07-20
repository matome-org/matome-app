from collections.abc import Iterable
from dataclasses import dataclass
from typing import Any, Literal, TypedDict

from app.lifecycle import Executor, JobFailure


class TranscriptOutput(TypedDict):
    type: Literal["transcript"]
    text: str


@dataclass(frozen=True)
class ProcessorCapability:
    input_kind: str
    outputs: tuple[str, ...]
    max_bytes: int
    content_types: tuple[str, ...] = ()


@dataclass(frozen=True)
class ProcessorRegistration:
    capability: ProcessorCapability
    processor: Executor


class ProcessorRegistry:
    def __init__(self, registrations: Iterable[ProcessorRegistration]) -> None:
        self._registrations: dict[str, ProcessorRegistration] = {}
        for registration in registrations:
            kind = registration.capability.input_kind
            if kind in self._registrations:
                raise ValueError(f"processor already registered for input kind: {kind}")
            self._registrations[kind] = registration

    def capabilities(self) -> dict[str, object]:
        inputs = {
            kind: {
                "enabled": True,
                "max_bytes": registration.capability.max_bytes,
                "content_types": list(registration.capability.content_types),
                "outputs": list(registration.capability.outputs),
            }
            for kind, registration in self._registrations.items()
        }
        return {
            "contract_version": "1",
            "service": "matome-ai-core",
            "inputs": inputs,
        }

    def __call__(
        self, media: bytes, job: dict[str, Any]
    ) -> list[dict[str, Any]]:
        input_kind = job["input"]["kind"]
        registration = self._registrations.get(input_kind)
        if registration is None:
            raise JobFailure(
                "unsupported_input_kind", "Input kind is not supported.", False
            )

        requested = set(job["requested_outputs"])
        if not requested.issubset(registration.capability.outputs):
            raise JobFailure(
                "unsupported_requested_output",
                "A requested output is not supported for this input.",
                False,
            )
        return registration.processor(media, job)
