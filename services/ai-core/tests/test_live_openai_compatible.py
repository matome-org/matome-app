import base64
import json
import os
import struct
import zlib

import pytest

from app.openai_compatible import OpenAICompatibleClient, OpenAICompatibleConfig


pytestmark = pytest.mark.live_ai


def live_client() -> OpenAICompatibleClient:
    if os.environ.get("MATOME_LIVE_AI") != "1":
        pytest.skip("set MATOME_LIVE_AI=1 to run against a real OpenAI-compatible server")
    return OpenAICompatibleClient(OpenAICompatibleConfig.from_environ(os.environ))


def test_live_text_completion() -> None:
    response = live_client().chat_completions(
        messages=[
            {"role": "user", "content": "Reply with exactly: MATOME_OK"},
        ],
        temperature=0,
        max_tokens=32,
    )

    message = response["choices"][0]["message"]
    assert message["role"] == "assistant"
    assert "MATOME_OK" in message["content"]


def test_live_tool_calling() -> None:
    response = live_client().chat_completions(
        messages=[
            {"role": "user", "content": "Use the get_weather tool for Tokyo."},
        ],
        tools=[
            {
                "type": "function",
                "function": {
                    "name": "get_weather",
                    "description": "Get current weather",
                    "parameters": {
                        "type": "object",
                        "properties": {"city": {"type": "string"}},
                        "required": ["city"],
                    },
                },
            }
        ],
        tool_choice="auto",
        temperature=0,
        max_tokens=128,
    )

    tool_call = response["choices"][0]["message"]["tool_calls"][0]
    assert tool_call["function"]["name"] == "get_weather"
    arguments = json.loads(tool_call["function"]["arguments"])
    assert "tokyo" in arguments["city"].lower()


def test_live_vision() -> None:
    image = base64.b64encode(red_png()).decode()
    response = live_client().chat_completions(
        messages=[
            {
                "role": "user",
                "content": [
                    {
                        "type": "text",
                        "text": "What is the dominant color? Reply with one color word.",
                    },
                    {
                        "type": "image_url",
                        "image_url": {"url": f"data:image/png;base64,{image}"},
                    },
                ],
            }
        ],
        temperature=0,
        max_tokens=32,
    )

    assert "red" in response["choices"][0]["message"]["content"].lower()


def red_png(width: int = 64, height: int = 64) -> bytes:
    signature = b"\x89PNG\r\n\x1a\n"

    def chunk(kind: bytes, data: bytes) -> bytes:
        return (
            struct.pack(">I", len(data))
            + kind
            + data
            + struct.pack(">I", zlib.crc32(kind + data) & 0xFFFFFFFF)
        )

    header = struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0)
    scanline = b"\x00" + (b"\xff\x00\x00" * width)
    pixels = zlib.compress(scanline * height)
    return signature + chunk(b"IHDR", header) + chunk(b"IDAT", pixels) + chunk(b"IEND", b"")
