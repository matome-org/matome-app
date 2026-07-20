import math
from collections.abc import Mapping, Sequence
from dataclasses import dataclass
from typing import Any
from urllib.parse import urlparse

import httpx


@dataclass(frozen=True)
class OpenAICompatibleConfig:
    base_url: str
    api_key: str
    model: str
    timeout_seconds: float = 60.0

    def __post_init__(self) -> None:
        normalized = _normalize_base_url(self.base_url)
        if not self.api_key:
            raise ValueError("OPENAI_API_KEY is required")
        if not self.model:
            raise ValueError("OPENAI_MODEL is required")
        if not math.isfinite(self.timeout_seconds) or self.timeout_seconds <= 0:
            raise ValueError("OPENAI_TIMEOUT_SECONDS must be positive finite")
        object.__setattr__(self, "base_url", normalized)

    @classmethod
    def from_environ(cls, environ: Mapping[str, str]) -> "OpenAICompatibleConfig":
        base_url = environ.get("OPENAI_BASE_URL", "")
        api_key = environ.get("OPENAI_API_KEY", "")
        model = environ.get("OPENAI_MODEL", "")
        for name, value in (
            ("OPENAI_BASE_URL", base_url),
            ("OPENAI_API_KEY", api_key),
            ("OPENAI_MODEL", model),
        ):
            if not value:
                raise ValueError(f"{name} is required")

        timeout_value = environ.get("OPENAI_TIMEOUT_SECONDS", "60")
        try:
            timeout_seconds = float(timeout_value)
        except ValueError as error:
            raise ValueError("OPENAI_TIMEOUT_SECONDS must be numeric") from error
        return cls(
            base_url=base_url,
            api_key=api_key,
            model=model,
            timeout_seconds=timeout_seconds,
        )


class OpenAICompatibleClient:
    def __init__(
        self,
        config: OpenAICompatibleConfig,
        *,
        transport: httpx.BaseTransport | None = None,
    ) -> None:
        self._config = config
        self._transport = transport

    def chat_completions(
        self,
        *,
        messages: Sequence[Mapping[str, Any]],
        tools: Sequence[Mapping[str, Any]] | None = None,
        tool_choice: str | Mapping[str, Any] | None = None,
        temperature: float | None = None,
        max_tokens: int | None = None,
    ) -> dict[str, Any]:
        payload: dict[str, Any] = {
            "model": self._config.model,
            "messages": list(messages),
        }
        if tools is not None:
            payload["tools"] = list(tools)
        if tool_choice is not None:
            payload["tool_choice"] = tool_choice
        if temperature is not None:
            payload["temperature"] = temperature
        if max_tokens is not None:
            payload["max_tokens"] = max_tokens

        try:
            with httpx.Client(
                transport=self._transport,
                timeout=self._config.timeout_seconds,
            ) as client:
                response = client.post(
                    f"{self._config.base_url}/chat/completions",
                    headers={
                        "authorization": f"Bearer {self._config.api_key}",
                        "content-type": "application/json",
                    },
                    json=payload,
                )
                response.raise_for_status()
                body = response.json()
        except (httpx.HTTPError, ValueError):
            raise RuntimeError("OpenAI-compatible provider request failed.") from None

        if not isinstance(body, dict) or not isinstance(body.get("choices"), list):
            raise RuntimeError("OpenAI-compatible provider returned invalid data.")
        return body


def _normalize_base_url(value: str) -> str:
    base_url = value.strip().rstrip("/")
    parsed = urlparse(base_url)
    if parsed.scheme not in {"http", "https"} or not parsed.netloc:
        raise ValueError("OPENAI_BASE_URL must be an HTTP(S) URL")
    if parsed.query or parsed.fragment:
        raise ValueError("OPENAI_BASE_URL must not include a query or fragment")
    if not parsed.path.rstrip("/").endswith("/v1"):
        base_url = f"{base_url}/v1"
    return base_url
