import subprocess
from types import SimpleNamespace
from pathlib import Path

import pytest

from app.lifecycle import JobFailure
from app.processor import AudioProcessor, create_audio_processor, transcode_to_wav


def audio_job(content_type: str = "audio/mpeg") -> dict[str, object]:
    return {
        "input": {"kind": "audio", "media": {"content_type": content_type}},
        "requested_outputs": ["transcript"],
        "metadata": {"locale": "ja"},
    }


def test_processor_transcodes_verified_bytes_and_emits_only_v1_transcript(
    tmp_path: Path,
) -> None:
    calls: list[tuple[bytes, str]] = []

    def transcode(media: bytes, content_type: str) -> bytes:
        calls.append((media, content_type))
        return b"16khz mono wav"

    class Backend:
        def transcribe(self, wav_path: Path, *, language: str | None) -> str:
            assert wav_path.read_bytes() == b"16khz mono wav"
            assert language == "ja"
            return "  verified transcript  "

    processor = AudioProcessor(
        backend_factory=lambda: Backend(),
        transcoder=transcode,
        temporary_directory=tmp_path,
    )

    assert processor(b"verified source bytes", audio_job()) == [
        {"type": "transcript", "text": "verified transcript"}
    ]
    assert calls == [(b"verified source bytes", "audio/mpeg")]


def test_processor_loads_backend_lazily_and_reuses_it(tmp_path: Path) -> None:
    loaded = 0

    class Backend:
        def transcribe(self, _wav_path: Path, *, language: str | None) -> str:
            return "text"

    def load_backend() -> Backend:
        nonlocal loaded
        loaded += 1
        return Backend()

    processor = AudioProcessor(
        backend_factory=load_backend,
        transcoder=lambda _media, _content_type: b"wav",
        temporary_directory=tmp_path,
    )
    assert loaded == 0

    processor(b"first", audio_job())
    processor(b"second", audio_job("audio/wav"))

    assert loaded == 1


def test_environment_selects_backend_and_model_without_eager_import(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    imports: list[str] = []
    models: list[str] = []

    class Model:
        def __init__(self, model_name: str) -> None:
            models.append(model_name)

        def transcribe(self, _path: str, **_options: object) -> list[object]:
            return [SimpleNamespace(text="configured transcript")]

    def import_module(name: str) -> object:
        imports.append(name)
        return SimpleNamespace(Model=Model)

    monkeypatch.setattr("app.processor.importlib.import_module", import_module)
    processor = create_audio_processor(
        {"WHISPER_BACKEND": "whispercpp", "WHISPER_MODEL": "tiny.en"},
        transcoder=lambda _media, _content_type: b"wav",
        temporary_directory=tmp_path,
    )

    assert imports == []
    assert processor(b"source", audio_job()) == [
        {"type": "transcript", "text": "configured transcript"}
    ]
    assert imports == ["pywhispercpp.model"]
    assert models == ["tiny.en"]


def test_processor_rejects_unsupported_media_before_conversion(tmp_path: Path) -> None:
    converted = False

    def transcode(_media: bytes, _content_type: str) -> bytes:
        nonlocal converted
        converted = True
        return b"wav"

    processor = AudioProcessor(
        backend_factory=lambda: object(),
        transcoder=transcode,
        temporary_directory=tmp_path,
    )

    with pytest.raises(JobFailure) as failure:
        processor(b"image", audio_job("image/png"))

    assert (failure.value.code, failure.value.retryable) == (
        "unsupported_media_type",
        False,
    )
    assert not converted


@pytest.mark.parametrize(
    ("boundary", "expected_code", "retryable"),
    [
        ("ffmpeg", "media_conversion_failed", False),
        ("whisper", "transcription_failed", True),
    ],
)
def test_processor_converts_boundary_errors_to_stable_job_failures(
    tmp_path: Path, boundary: str, expected_code: str, retryable: bool
) -> None:
    class Backend:
        def transcribe(self, _wav_path: Path, *, language: str | None) -> str:
            if boundary == "whisper":
                raise RuntimeError("private backend detail")
            return "text"

    def transcode(_media: bytes, _content_type: str) -> bytes:
        if boundary == "ffmpeg":
            raise subprocess.CalledProcessError(1, ["ffmpeg"], stderr=b"private input")
        return b"wav"

    processor = AudioProcessor(
        backend_factory=lambda: Backend(),
        transcoder=transcode,
        temporary_directory=tmp_path,
    )

    with pytest.raises(JobFailure) as failure:
        processor(b"source", audio_job())

    assert (failure.value.code, failure.value.retryable) == (expected_code, retryable)
    assert "private" not in failure.value.message


def test_ffmpeg_conversion_uses_argument_vector_and_16khz_mono_pcm(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    invocation: dict[str, object] = {}

    def run(command: list[str], **options: object) -> subprocess.CompletedProcess[bytes]:
        invocation.update(command=command, options=options)
        Path(command[-1]).write_bytes(b"converted wav")
        return subprocess.CompletedProcess(command, 0, b"", b"")

    monkeypatch.setattr(subprocess, "run", run)

    assert transcode_to_wav(b"source;$(unsafe)", "audio/mpeg", tmp_path) == b"converted wav"
    command = invocation["command"]
    assert isinstance(command, list)
    assert command[:6] == [
        "ffmpeg",
        "-nostdin",
        "-hide_banner",
        "-loglevel",
        "error",
        "-y",
    ]
    assert command[-7:] == [
        "-ac",
        "1",
        "-ar",
        "16000",
        "-c:a",
        "pcm_s16le",
        command[-1],
    ]
    options = invocation["options"]
    assert isinstance(options, dict)
    assert options["check"] is True
    assert options["stdin"] is subprocess.DEVNULL
    assert "shell" not in options
