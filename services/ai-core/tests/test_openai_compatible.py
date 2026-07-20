import json
import math

import httpx
import pytest

from app.openai_compatible import OpenAICompatibleClient, OpenAICompatibleConfig


def test_config_normalizes_base_url_and_reads_provider_neutral_environment() -> None:
    config = OpenAICompatibleConfig.from_environ(
        {
            "OPENAI_BASE_URL": "http://localhost:1234/",
            "OPENAI_API_KEY": "local-token",
            "OPENAI_MODEL": "local/model",
        }
    )

    assert config.base_url == "http://localhost:1234/v1"
    assert config.api_key == "local-token"
    assert config.model == "local/model"


@pytest.mark.parametrize("missing", ["OPENAI_BASE_URL", "OPENAI_API_KEY", "OPENAI_MODEL"])
def test_config_fails_closed_when_required_setting_is_missing(missing: str) -> None:
    environ = {
        "OPENAI_BASE_URL": "http://localhost:1234/v1",
        "OPENAI_API_KEY": "local-token",
        "OPENAI_MODEL": "local/model",
    }
    del environ[missing]

    with pytest.raises(ValueError, match=missing):
        OpenAICompatibleConfig.from_environ(environ)


@pytest.mark.parametrize(
    "base_url",
    [
        "http://localhost:1234/v1?api-version=test",
        "http://localhost:1234/v1#fragment",
    ],
)
def test_config_rejects_base_url_query_and_fragment(base_url: str) -> None:
    with pytest.raises(ValueError, match="query or fragment"):
        OpenAICompatibleConfig(
            base_url=base_url,
            api_key="local-token",
            model="local/model",
        )


@pytest.mark.parametrize("timeout", [math.nan, math.inf, -math.inf, 0])
def test_config_requires_a_finite_positive_timeout(timeout: float) -> None:
    with pytest.raises(ValueError, match="positive finite"):
        OpenAICompatibleConfig(
            base_url="http://localhost:1234/v1",
            api_key="local-token",
            model="local/model",
            timeout_seconds=timeout,
        )


def test_chat_completions_uses_only_openai_compatible_wire_contract() -> None:
    requests: list[httpx.Request] = []

    def respond(request: httpx.Request) -> httpx.Response:
        requests.append(request)
        return httpx.Response(
            200,
            json={
                "id": "chatcmpl-test",
                "object": "chat.completion",
                "model": "local/model",
                "choices": [
                    {
                        "index": 0,
                        "message": {
                            "role": "assistant",
                            "content": "MATOME_OK",
                            "tool_calls": [],
                        },
                        "finish_reason": "stop",
                    }
                ],
            },
        )

    transport = httpx.MockTransport(respond)
    client = OpenAICompatibleClient(
        OpenAICompatibleConfig(
            base_url="http://localhost:1234/v1",
            api_key="local-token",
            model="local/model",
        ),
        transport=transport,
    )

    response = client.chat_completions(
        messages=[{"role": "user", "content": "ping"}],
        temperature=0,
        max_tokens=32,
    )

    assert response["choices"][0]["message"]["content"] == "MATOME_OK"
    assert len(requests) == 1
    assert requests[0].url == "http://localhost:1234/v1/chat/completions"
    assert requests[0].headers["authorization"] == "Bearer local-token"
    assert json.loads(requests[0].content) == {
        "model": "local/model",
        "messages": [{"role": "user", "content": "ping"}],
        "temperature": 0,
        "max_tokens": 32,
    }


def test_chat_completions_passes_tools_and_multimodal_content_unchanged() -> None:
    payloads: list[dict[str, object]] = []

    def respond(request: httpx.Request) -> httpx.Response:
        payloads.append(json.loads(request.content))
        return httpx.Response(
            200,
            json={
                "choices": [
                    {
                        "message": {
                            "role": "assistant",
                            "content": "",
                            "tool_calls": [
                                {
                                    "type": "function",
                                    "function": {
                                        "name": "lookup",
                                        "arguments": '{"query":"matome"}',
                                    },
                                }
                            ],
                        }
                    }
                ]
            },
        )

    client = OpenAICompatibleClient(
        OpenAICompatibleConfig(
            base_url="http://localhost:1234/v1",
            api_key="local-token",
            model="local/model",
        ),
        transport=httpx.MockTransport(respond),
    )
    tools = [
        {
            "type": "function",
            "function": {
                "name": "lookup",
                "description": "Look up a value",
                "parameters": {
                    "type": "object",
                    "properties": {"query": {"type": "string"}},
                    "required": ["query"],
                },
            },
        }
    ]
    messages = [
        {
            "role": "user",
            "content": [
                {"type": "text", "text": "Inspect this image"},
                {
                    "type": "image_url",
                    "image_url": {"url": "data:image/png;base64,fixture"},
                },
            ],
        }
    ]

    response = client.chat_completions(
        messages=messages,
        tools=tools,
        tool_choice="auto",
    )

    assert payloads[0]["messages"] == messages
    assert payloads[0]["tools"] == tools
    assert payloads[0]["tool_choice"] == "auto"
    assert response["choices"][0]["message"]["tool_calls"][0]["function"]["name"] == "lookup"


def test_provider_errors_are_bounded_and_do_not_expose_response_body() -> None:
    client = OpenAICompatibleClient(
        OpenAICompatibleConfig(
            base_url="http://localhost:1234/v1",
            api_key="secret-token",
            model="local/model",
        ),
        transport=httpx.MockTransport(
            lambda _request: httpx.Response(500, text="private provider detail")
        ),
    )

    with pytest.raises(RuntimeError) as failure:
        client.chat_completions(messages=[{"role": "user", "content": "ping"}])

    assert "private provider detail" not in str(failure.value)
    assert "secret-token" not in str(failure.value)
