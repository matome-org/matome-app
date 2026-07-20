import importlib
import os
import subprocess
import tempfile
import threading
from collections.abc import Callable, Mapping
from pathlib import Path
from typing import Any, Protocol

from app.lifecycle import JobFailure
from app.registry import TranscriptOutput


SUPPORTED_MEDIA_TYPES = {"audio/mpeg": ".mp3", "audio/wav": ".wav"}


class TranscriptionBackend(Protocol):
    def transcribe(self, wav_path: Path, *, language: str | None) -> str: ...


Transcoder = Callable[[bytes, str], bytes]
BackendFactory = Callable[[], TranscriptionBackend]


class AudioProcessor:
    def __init__(
        self,
        *,
        backend_factory: BackendFactory,
        transcoder: Transcoder | None = None,
        temporary_directory: Path | None = None,
    ) -> None:
        self._backend_factory = backend_factory
        self._transcoder = transcoder or transcode_to_wav
        self._temporary_directory = temporary_directory
        self._backend: TranscriptionBackend | None = None
        self._backend_lock = threading.Lock()

    def __call__(
        self, media: bytes, job: dict[str, Any]
    ) -> list[TranscriptOutput]:
        content_type = job["input"]["media"]["content_type"]
        if content_type not in SUPPORTED_MEDIA_TYPES:
            raise JobFailure(
                "unsupported_media_type",
                "Input media type is not supported.",
                False,
            )

        try:
            wav = self._transcoder(media, content_type)
        except JobFailure:
            raise
        except subprocess.TimeoutExpired as error:
            raise JobFailure(
                "media_conversion_failed",
                "Input audio conversion timed out.",
                True,
            ) from error
        except FileNotFoundError as error:
            raise JobFailure(
                "processor_unavailable",
                "Audio conversion is temporarily unavailable.",
                True,
            ) from error
        except (subprocess.CalledProcessError, OSError) as error:
            raise JobFailure(
                "media_conversion_failed",
                "Input audio could not be converted.",
                False,
            ) from error

        language = (job.get("metadata") or {}).get("locale")
        try:
            backend = self._get_backend()
            with tempfile.NamedTemporaryFile(
                suffix=".wav", dir=self._temporary_directory
            ) as wav_file:
                wav_file.write(wav)
                wav_file.flush()
                text = backend.transcribe(Path(wav_file.name), language=language).strip()
        except JobFailure:
            raise
        except Exception as error:
            raise JobFailure(
                "transcription_failed",
                "Audio transcription temporarily failed.",
                True,
            ) from error

        return [{"type": "transcript", "text": text}]

    def _get_backend(self) -> TranscriptionBackend:
        if self._backend is None:
            with self._backend_lock:
                if self._backend is None:
                    self._backend = self._backend_factory()
        return self._backend


def create_audio_processor(
    environ: Mapping[str, str] | None = None,
    *,
    transcoder: Transcoder | None = None,
    temporary_directory: Path | None = None,
) -> AudioProcessor:
    config = os.environ if environ is None else environ
    backend_name = config.get("WHISPER_BACKEND", "openai").lower()
    model_name = config.get("WHISPER_MODEL", "base")

    def load_backend() -> TranscriptionBackend:
        if backend_name == "openai":
            return OpenAIWhisperBackend(model_name)
        if backend_name == "whispercpp":
            return WhisperCppBackend(model_name)
        raise JobFailure(
            "processor_configuration_invalid",
            "Configured transcription backend is not supported.",
            False,
        )

    return AudioProcessor(
        backend_factory=load_backend,
        transcoder=transcoder,
        temporary_directory=temporary_directory,
    )


def transcode_to_wav(
    media: bytes,
    content_type: str,
    temporary_directory: Path | None = None,
) -> bytes:
    suffix = SUPPORTED_MEDIA_TYPES.get(content_type)
    if suffix is None:
        raise JobFailure(
            "unsupported_media_type", "Input media type is not supported.", False
        )

    with tempfile.TemporaryDirectory(dir=temporary_directory) as directory:
        input_path = Path(directory) / f"input{suffix}"
        output_path = Path(directory) / "output.wav"
        input_path.write_bytes(media)
        subprocess.run(
            [
                "ffmpeg",
                "-nostdin",
                "-hide_banner",
                "-loglevel",
                "error",
                "-y",
                "-i",
                str(input_path),
                "-ac",
                "1",
                "-ar",
                "16000",
                "-c:a",
                "pcm_s16le",
                str(output_path),
            ],
            check=True,
            stdin=subprocess.DEVNULL,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            timeout=300,
        )
        return output_path.read_bytes()


class OpenAIWhisperBackend:
    def __init__(self, model_name: str) -> None:
        whisper = importlib.import_module("whisper")
        self._model = whisper.load_model(model_name)

    def transcribe(self, wav_path: Path, *, language: str | None) -> str:
        options = {"language": language} if language else {}
        result = self._model.transcribe(str(wav_path), **options)
        return str(result["text"])


class WhisperCppBackend:
    def __init__(self, model_name: str) -> None:
        module = importlib.import_module("pywhispercpp.model")
        self._model = module.Model(model_name)

    def transcribe(self, wav_path: Path, *, language: str | None) -> str:
        options = {"language": language} if language else {}
        segments = self._model.transcribe(str(wav_path), **options)
        return "".join(segment.text for segment in segments)
