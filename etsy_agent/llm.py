"""Thin wrapper around the Anthropic Messages API used by every pipeline step."""

from __future__ import annotations

import base64
import json
import os
import threading
from dataclasses import dataclass, field

import anthropic

MODEL = os.environ.get("ETSY_AGENT_MODEL", "claude-opus-5-5")
# Server-side refusal fallback: if a safety classifier declines a request
# (rare for this workload), the API retries it on Anthropic's recommended
# fallback model instead of returning an empty answer.
FALLBACK_BETA = "server-side-fallback-2026-07-01"

# Opus 5.5 list prices, USD per million tokens - used only for the estimate.
PRICE_IN, PRICE_OUT, PRICE_CACHE_WRITE, PRICE_CACHE_READ = 4.0, 20.0, 5.0, 0.20


class AgentError(RuntimeError):
    pass


@dataclass
class Usage:
    input: int = 0
    output: int = 0
    cache_write: int = 0
    cache_read: int = 0
    calls: int = 0
    _lock: threading.Lock = field(default_factory=threading.Lock, repr=False)

    def add(self, usage) -> None:
        with self._lock:
            self._add(usage)

    def _add(self, usage) -> None:
        self.calls += 1
        self.input += usage.input_tokens or 0
        self.output += usage.output_tokens or 0
        self.cache_write += getattr(usage, "cache_creation_input_tokens", 0) or 0
        self.cache_read += getattr(usage, "cache_read_input_tokens", 0) or 0

    def cost(self) -> float:
        return (
            self.input * PRICE_IN
            + self.output * PRICE_OUT
            + self.cache_write * PRICE_CACHE_WRITE
            + self.cache_read * PRICE_CACHE_READ
        ) / 1_000_000

    def summary(self) -> str:
        line = (
            f"{self.calls} API calls, {self.input + self.cache_write + self.cache_read:,} input "
            f"/ {self.output:,} output tokens"
        )
        if MODEL == "claude-opus-5-5":
            line += f" (~${self.cost():.2f} at list price)"
        return line


def image_block(png: bytes) -> dict:
    return {
        "type": "image",
        "source": {
            "type": "base64",
            "media_type": "image/png",
            "data": base64.standard_b64encode(png).decode("ascii"),
        },
    }


@dataclass
class LLM:
    client: anthropic.Anthropic = field(default_factory=anthropic.Anthropic)
    model: str = MODEL
    usage: Usage = field(default_factory=Usage)

    def call(
        self,
        *,
        system: str,
        messages: list[dict],
        effort: str = "high",
        schema: dict | None = None,
        tools: list[dict] | None = None,
        max_tokens: int = 64000,
    ):
        """One request (streamed, so long SVGs never hit HTTP timeouts).

        `messages` is extended in place with any server-tool continuation
        turns, so callers can keep appending to the same conversation.
        """
        output_config: dict = {"effort": effort}
        if schema:
            output_config["format"] = {"type": "json_schema", "schema": schema}
        params = dict(
            model=self.model,
            max_tokens=max_tokens,
            # The system prompt is identical across every design in a run,
            # so cache it.
            system=[{"type": "text", "text": system, "cache_control": {"type": "ephemeral"}}],
            thinking={"type": "adaptive"},
            output_config=output_config,
            betas=[FALLBACK_BETA],
            fallbacks="default",
        )
        if tools:
            params["tools"] = tools

        for _ in range(6):  # server tools (web search) may pause long turns
            with self.client.beta.messages.stream(messages=messages, **params) as stream:
                message = stream.get_final_message()
            self.usage.add(message.usage)
            if message.stop_reason != "pause_turn":
                break
            messages.append({"role": "assistant", "content": message.content})

        if message.stop_reason == "refusal":
            detail = getattr(message.stop_details, "explanation", None) if message.stop_details else None
            raise AgentError(f"The model declined this request. {detail or ''}".strip())
        if message.stop_reason == "max_tokens":
            raise AgentError("The response hit max_tokens before finishing.")
        return message

    @staticmethod
    def text(message) -> str:
        return "".join(b.text for b in message.content if b.type == "text")

    def json(self, **kwargs) -> dict:
        message = self.call(**kwargs)
        return json.loads(self.text(message))
