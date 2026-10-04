#!/usr/bin/env python3
"""Chat-based Roblox Limited trade advisor.

Talk in plain language; the agent answers using live Rolimons data via the
functions in roblox_trade_advisor.py. Advice only: nothing here logs in to
Roblox, uses your cookie or password, or sends/accepts trades or purchases.

    python agent.py                       # chat mode
    python agent.py --once "is X for Y a good trade?"
"""

import argparse
import json
import os
import sys

import roblox_trade_advisor as rta

MODEL = "claude-sonnet-5-5"
MAX_TOOL_ROUNDS = 10  # safety cap on tool calls per question

SYSTEM_PROMPT = """You are a cautious Roblox Limited trade advisor. You are helping the user grow a starting budget of about 5,000 Robux toward funding their game.

How to answer:
- Base every claim about items, prices, values, demand or trends on tool results from this conversation. If data is missing or an item is unvalued, say so plainly instead of guessing.
- Always flag projected items, low demand, falling trends and inflated RAP when they appear in the results.
- Always account for Roblox's 30% marketplace fee when talking about profit: a resale at price P returns 0.7 x P. Item-for-item trades have no fee.
- Never promise profit. Present trades as "good", "fair" or "bad" with the reasons and the risks.
- Warn about scam patterns when relevant: anything done outside Roblox's own trade window, anyone asking for the user's password or cookie (.ROBLOSECURITY), and offers that look too good to be true.
- You only give advice. You cannot log in, buy, sell or send trades, and the user makes every trade themselves. If asked to do any of that, say so.
- If an item name is ambiguous or not found, ask which item they mean, using the suggestions from the tool.
- Use update_portfolio only when the user tells you they actually bought, sold or want to remove something.
- Keep answers short and clear: a verdict or direct answer first, then a few bullet points."""

TOOLS = [
    {
        "name": "search_items",
        "description": "Search Roblox Limited items on Rolimons by name or acronym. Returns RAP, value (null if unvalued), demand, trend and risk flags for the best matches.",
        "input_schema": {
            "type": "object",
            "properties": {"query": {"type": "string", "description": "Item name, part of a name, acronym or item id."}},
            "required": ["query"],
            "additionalProperties": False,
        },
        "strict": True,
    },
    {
        "name": "evaluate_trade",
        "description": "Evaluate a trade: what the user gives versus what they get. Returns a good/fair/bad verdict, value totals per side and risk flags. If some names are not recognised it returns suggestions instead.",
        "input_schema": {
            "type": "object",
            "properties": {
                "give": {"type": "array", "items": {"type": "string"}, "description": "Items the user would give (names, acronyms or ids)."},
                "get": {"type": "array", "items": {"type": "string"}, "description": "Items the user would receive."},
            },
            "required": ["give", "get"],
            "additionalProperties": False,
        },
        "strict": True,
    },
    {
        "name": "scan_candidates",
        "description": "Find flip candidates the user can afford: valued, non-projected, not falling, RAP <= budget and value above RAP by at least min_edge. Includes net profit after the 30% fee if resold at value.",
        "input_schema": {
            "type": "object",
            "properties": {
                "budget": {"type": "integer", "description": "Maximum Robux to spend on one item."},
                "min_edge": {"type": "number", "description": "Minimum (value - RAP) / RAP, e.g. 0.1 for 10%. Use 0.1 if unsure."},
                "min_demand": {"type": "integer", "description": "Minimum demand level: 0 terrible, 1 low, 2 normal, 3 high, 4 amazing. Use 2 if unsure."},
            },
            "required": ["budget", "min_edge", "min_demand"],
            "additionalProperties": False,
        },
        "strict": True,
    },
    {
        "name": "get_portfolio",
        "description": "Show the user's tracked holdings from portfolio.json: cost, current value, and net if sold now after the 30% fee.",
        "input_schema": {"type": "object", "properties": {}, "additionalProperties": False},
        "strict": True,
    },
    {
        "name": "update_portfolio",
        "description": "Record something the user says they already did: 'add' a purchase (price = what they paid), 'sell' a holding (price = sale price; 30% fee is applied), or 'remove' an entry (price ignored, use 0). Only records data locally; it never trades.",
        "input_schema": {
            "type": "object",
            "properties": {
                "action": {"type": "string", "enum": ["add", "sell", "remove"]},
                "item": {"type": "string", "description": "Item name, acronym or id."},
                "price": {"type": "integer", "description": "Robux amount."},
            },
            "required": ["action", "item", "price"],
            "additionalProperties": False,
        },
        "strict": True,
    },
]

TOOL_FUNCTIONS = {
    "search_items": lambda a: rta.search_items(a["query"]),
    "evaluate_trade": lambda a: rta.evaluate_trade(a["give"], a["get"]),
    "scan_candidates": lambda a: rta.scan_candidates(a["budget"], a.get("min_edge", 0.10), a.get("min_demand", 2)),
    "get_portfolio": lambda a: rta.get_portfolio(),
    "update_portfolio": lambda a: rta.update_portfolio(a["action"], a["item"], a["price"]),
}


class AgentError(RuntimeError):
    """A problem the user should see as a plain message (bad key, API down, ...)."""


def run_tool(name, args):
    """Execute one tool call. Returns (json_text, is_error)."""
    fn = TOOL_FUNCTIONS.get(name)
    if fn is None:
        return json.dumps({"error": f"Unknown tool {name}"}), True
    try:
        return json.dumps(fn(args)), False
    except rta.RolimonsError as e:
        return json.dumps({"error": f"Rolimons data unavailable: {e}"}), True
    except (KeyError, TypeError, ValueError, RuntimeError) as e:
        return json.dumps({"error": f"{type(e).__name__}: {e}"}), True


def make_client():
    if not os.environ.get("ANTHROPIC_API_KEY"):
        raise AgentError(
            "ANTHROPIC_API_KEY is not set.\n"
            "Get a key at https://console.anthropic.com/ and run:\n"
            "  export ANTHROPIC_API_KEY=sk-ant-...      (macOS/Linux)\n"
            "  setx ANTHROPIC_API_KEY sk-ant-...        (Windows, then reopen the terminal)"
        )
    try:
        import anthropic
    except ImportError:
        raise AgentError("The anthropic package is not installed. Run: pip install requests anthropic")
    return anthropic.Anthropic()


def _call_model(client, messages):
    import anthropic

    try:
        return client.beta.messages.create(
            model=MODEL,
            max_tokens=16000,
            system=SYSTEM_PROMPT,
            tools=TOOLS,
            messages=messages,
            output_config={"effort": "medium"},
            # If a safety classifier declines, the API retries on a fallback model in the same call.
            betas=["server-side-fallback-2026-07-01"],
            fallbacks="default",
        )
    except anthropic.AuthenticationError:
        raise AgentError("The Anthropic API rejected your key. Check ANTHROPIC_API_KEY.")
    except anthropic.PermissionDeniedError:
        raise AgentError(f"Your Anthropic key does not have access to {MODEL}.")
    except anthropic.RateLimitError:
        raise AgentError("Anthropic rate limit hit. Wait a moment and try again.")
    except anthropic.APIConnectionError:
        raise AgentError("Could not reach the Anthropic API. Check your internet connection.")
    except anthropic.APIStatusError as e:
        if e.status_code >= 500:
            raise AgentError(f"The Anthropic API is down or overloaded (HTTP {e.status_code}). Try again shortly.")
        raise AgentError(f"Anthropic API error {e.status_code}: {e.message}")


class Advisor:
    """Holds the conversation in memory and runs the tool-use loop per question."""

    def __init__(self, client, on_tool=None):
        self.client = client
        self.messages = []
        self.on_tool = on_tool  # optional callback(name, args) for showing progress

    def ask(self, question):
        checkpoint = len(self.messages)
        self.messages.append({"role": "user", "content": question})
        try:
            return self._loop()
        except BaseException:
            # Drop the half-finished turn so the next question starts from a valid history.
            del self.messages[checkpoint:]
            raise

    def _loop(self):
        for _ in range(MAX_TOOL_ROUNDS):
            response = _call_model(self.client, self.messages)
            # Keep the full content (thinking + tool_use blocks), not just the text.
            self.messages.append({"role": "assistant", "content": response.content})

            if response.stop_reason == "refusal":
                return "Sorry, I can't help with that request."
            if response.stop_reason == "pause_turn":
                continue
            tool_calls = [b for b in response.content if b.type == "tool_use"]
            if response.stop_reason != "tool_use" or not tool_calls:
                text = "\n".join(b.text for b in response.content if b.type == "text").strip()
                if response.stop_reason == "max_tokens":
                    text += "\n\n(answer was cut off)"
                return text or "(no answer)"

            results = []
            for call in tool_calls:
                if self.on_tool:
                    self.on_tool(call.name, call.input)
                content, is_error = run_tool(call.name, call.input)
                results.append({"type": "tool_result", "tool_use_id": call.id,
                                "content": content, "is_error": is_error})
            # All results for one assistant turn go back in a single user message.
            self.messages.append({"role": "user", "content": results})

        return "I stopped after too many tool calls without a final answer. Try a more specific question."


def _show_tool(name, args):
    print(f"  [checking {name} {json.dumps(args)}]", file=sys.stderr)


def chat(advisor):
    print("Roblox trade advisor (advice only, you make every trade yourself).")
    print("Type a question, or 'quit' to exit.\n")
    while True:
        try:
            question = input("you> ").strip()
        except (EOFError, KeyboardInterrupt):
            print()
            return 0
        if not question:
            continue
        if question.lower() in ("quit", "exit", "q"):
            return 0
        try:
            print(f"\nadvisor> {advisor.ask(question)}\n")
        except AgentError as e:
            print(f"\nError: {e}\n", file=sys.stderr)
        except KeyboardInterrupt:
            print("\n(cancelled)\n")


def main(argv=None):
    p = argparse.ArgumentParser(description="Chat with a cautious Roblox Limited trade advisor.")
    p.add_argument("--once", metavar="QUESTION", help="ask a single question and exit")
    p.add_argument("--quiet", action="store_true", help="don't show which tools are being called")
    args = p.parse_args(argv)

    try:
        client = make_client()
    except AgentError as e:
        print(f"Error: {e}", file=sys.stderr)
        return 1

    advisor = Advisor(client, on_tool=None if args.quiet else _show_tool)
    if args.once:
        try:
            print(advisor.ask(args.once))
        except AgentError as e:
            print(f"Error: {e}", file=sys.stderr)
            return 1
        return 0
    return chat(advisor)


if __name__ == "__main__":
    sys.exit(main())
