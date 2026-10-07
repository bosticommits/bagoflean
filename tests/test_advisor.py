"""Offline tests: mock Rolimons data and a fake Anthropic client. Run: python -m unittest -v"""

import json
import os
import shutil
import sys
import tempfile
import time
import unittest
from types import SimpleNamespace
from unittest import mock

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.dirname(HERE))

import requests  # noqa: E402

import agent  # noqa: E402
import roblox_trade_advisor as rta  # noqa: E402

MOCK = os.path.join(HERE, "mock_items.json")


class TempFiles(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.mkdtemp()
        patches = {
            "MOCK_FILE": MOCK,
            "PORTFOLIO_FILE": os.path.join(self.tmp, "portfolio.json"),
            "CACHE_FILE": os.path.join(self.tmp, "cache.json"),
        }
        for name, value in patches.items():
            p = mock.patch.object(rta, name, value)
            p.start()
            self.addCleanup(p.stop)
        rta._memory_cache.update(fetched_at=0.0, items=None)

    def tearDown(self):
        shutil.rmtree(self.tmp)


class TestSearch(TempFiles):
    def test_search_sorted_by_value_with_flags(self):
        r = rta.search_items("fedora")
        self.assertEqual([i["name"] for i in r["results"]],
                         ["Blue Fedora", "Sparkle Time Fedora", "Classic Fedora", "Ice Fedora"])
        ice = r["results"][-1]
        self.assertTrue(any("hyped" in f for f in ice["flags"]))

    def test_unvalued_is_none_and_flagged(self):
        item = rta.search_items("Red Valk")["results"][0]
        self.assertIsNone(item["value"])
        self.assertTrue(any("unvalued" in f for f in item["flags"]))

    def test_projected_flags(self):
        flags = rta.search_items("Pumped")["results"][0]["flags"]
        joined = " ".join(flags)
        for word in ("projected", "low demand", "falling trend", "inflated RAP"):
            self.assertIn(word, joined)


class TestTrade(TempFiles):
    def test_good_trade(self):
        r = rta.evaluate_trade(["Golden Crown", "Ice Fedora"], ["Classic Fedora"])
        # give 2200+1500=3700, get 4000 -> ratio 1.08 -> fair
        self.assertEqual(r["verdict"], "fair")
        r = rta.evaluate_trade(["Teapot Hat"], ["GC", "DB"])
        # give 2000, get 3200 but Dusty Bucket is terrible demand -> downgraded to fair
        self.assertEqual(r["verdict"], "fair")
        self.assertTrue(any("downgraded" in x for x in r["risks"]))
        r = rta.evaluate_trade(["Teapot Hat"], ["Classic Fedora"])
        self.assertEqual(r["verdict"], "good")

    def test_bad_trade_projected(self):
        r = rta.evaluate_trade(["Classic Fedora"], ["Pumped Shades"])
        self.assertEqual(r["verdict"], "bad")
        self.assertTrue(any("projected" in x for x in r["risks"]))

    def test_unknown_item_returns_suggestions(self):
        r = rta.evaluate_trade(["Fedora"], ["Nonexistent Thing"])
        self.assertIsNone(r["verdict"])
        sides = {u["side"]: u for u in r["unresolved"]}
        self.assertIn("Blue Fedora", sides["give"]["did_you_mean"])
        self.assertEqual(sides["get"]["did_you_mean"], [])

    def test_acronym_and_id(self):
        r = rta.evaluate_trade(["1009"], ["CF"])
        self.assertEqual(r["give"]["items"][0]["name"], "Teapot Hat")
        self.assertEqual(r["get"]["items"][0]["name"], "Classic Fedora")


class TestScan(TempFiles):
    def test_scan_filters_and_fee(self):
        r = rta.scan_candidates(5000, 0.10, 2)
        names = [c["name"] for c in r["candidates"]]
        # Ice Fedora 25%, Classic Fedora 25%, Golden Crown 22%
        self.assertEqual(set(names), {"Ice Fedora", "Classic Fedora", "Golden Crown"})
        for excluded in ("Pumped Shades", "Red Valk Lookalike", "Dusty Bucket", "Teapot Hat", "Blue Fedora"):
            self.assertNotIn(excluded, names)
        cf = next(c for c in r["candidates"] if c["name"] == "Classic Fedora")
        self.assertEqual(cf["resale_proceeds_after_fee"], 2800)
        self.assertEqual(cf["net_after_fee"], -400)  # positive edge, still a loss after the fee
        self.assertGreater(cf["break_even_sell_price"] * 0.7, 3200 - 1)

    def test_min_demand(self):
        names = [c["name"] for c in rta.scan_candidates(5000, 0.10, 4)["candidates"]]
        self.assertEqual(names, ["Ice Fedora"])


class TestPortfolio(TempFiles):
    def test_add_sell_remove(self):
        self.assertTrue(rta.update_portfolio("add", "Classic Fedora", 3000)["ok"])
        self.assertTrue(rta.update_portfolio("add", "GC", 1700)["ok"])
        p = rta.get_portfolio()
        self.assertEqual(p["total_cost"], 4700)
        self.assertEqual(p["total_current_value"], 6200)
        self.assertEqual(p["total_net_if_sold_now"], 2800 + 1540)
        sold = rta.update_portfolio("sell", "classic fedora", 4000)["sold"]
        self.assertEqual(sold["proceeds_after_fee"], 2800)
        self.assertEqual(sold["profit"], -200)
        self.assertTrue(rta.update_portfolio("remove", "Golden Crown", 0)["ok"])
        p = rta.get_portfolio()
        self.assertEqual(p["holdings"], [])
        self.assertEqual(p["realized_profit"], -200)
        with open(rta.PORTFOLIO_FILE) as f:
            self.assertEqual(len(json.load(f)["history"]), 4)

    def test_bad_input(self):
        self.assertFalse(rta.update_portfolio("buy", "CF", 1)["ok"])
        self.assertFalse(rta.update_portfolio("add", "CF", "lots")["ok"])
        self.assertFalse(rta.update_portfolio("add", "Nope Hat", 10)["ok"])
        self.assertFalse(rta.update_portfolio("sell", "CF", 10)["ok"])  # not held


class TestFetchAndCache(TempFiles):
    def setUp(self):
        super().setUp()
        p = mock.patch.object(rta, "MOCK_FILE", None)
        p.start()
        self.addCleanup(p.stop)
        with open(MOCK) as f:
            self.payload = json.load(f)

    def _resp(self):
        return mock.Mock(status_code=200, json=lambda: self.payload, raise_for_status=lambda: None)

    def test_cache_hits_for_15_minutes(self):
        with mock.patch.object(rta.requests, "get", return_value=self._resp()) as get:
            rta.fetch_items()
            rta.fetch_items()
            rta._memory_cache.update(fetched_at=0.0, items=None)
            rta.fetch_items()  # served from disk cache
            self.assertEqual(get.call_count, 1)
            # Age the disk cache past the TTL -> refetch.
            with open(rta.CACHE_FILE) as f:
                c = json.load(f)
            c["fetched_at"] = time.time() - rta.CACHE_TTL_SECONDS - 1
            with open(rta.CACHE_FILE, "w") as f:
                json.dump(c, f)
            rta._memory_cache.update(fetched_at=0.0, items=None)
            rta.fetch_items()
            self.assertEqual(get.call_count, 2)
            get.assert_called_with(rta.ROLIMONS_ITEMS_URL, timeout=15)

    def test_api_down_errors(self):
        with mock.patch.object(rta.requests, "get", side_effect=requests.exceptions.ConnectionError()):
            with self.assertRaisesRegex(rta.RolimonsError, "Could not connect"):
                rta.fetch_items()
        bad = mock.Mock(status_code=429)
        err = requests.exceptions.HTTPError(response=bad)
        resp = mock.Mock(raise_for_status=mock.Mock(side_effect=err))
        with mock.patch.object(rta.requests, "get", return_value=resp):
            with self.assertRaisesRegex(rta.RolimonsError, "429.*rate limited"):
                rta.fetch_items()

    def test_portfolio_survives_api_down(self):
        with mock.patch.object(rta.requests, "get", side_effect=requests.exceptions.Timeout()):
            p = rta.get_portfolio()
        self.assertIn("timed out", p["warning"])

    def test_tool_error_is_reported_to_model(self):
        with mock.patch.object(rta.requests, "get", side_effect=requests.exceptions.Timeout()):
            content, is_error = agent.run_tool("search_items", {"query": "fedora"})
        self.assertTrue(is_error)
        self.assertIn("Rolimons data unavailable", content)


# ---------------------------------------------------------------- agent loop

def text(t):
    return SimpleNamespace(type="text", text=t)


def tool_use(id_, name, input_):
    return SimpleNamespace(type="tool_use", id=id_, name=name, input=input_)


class FakeClient:
    """Mimics client.beta.messages.create, returning scripted responses."""

    def __init__(self, responses):
        self.responses = list(responses)
        self.calls = []
        self.beta = SimpleNamespace(messages=SimpleNamespace(create=self._create))

    def _create(self, **kwargs):
        # Snapshot the messages: the agent mutates its list after the call.
        self.calls.append({**kwargs, "messages": list(kwargs["messages"])})
        return self.responses.pop(0)


class TestAgentLoop(TempFiles):
    def test_tool_loop_and_history(self):
        client = FakeClient([
            SimpleNamespace(stop_reason="tool_use", content=[
                text("Let me check."),
                tool_use("t1", "evaluate_trade", {"give": ["Teapot Hat"], "get": ["Classic Fedora"]}),
                tool_use("t2", "search_items", {"query": "Teapot"}),
            ]),
            SimpleNamespace(stop_reason="end_turn", content=[text("GOOD trade.")]),
            SimpleNamespace(stop_reason="end_turn", content=[text("Follow-up answer.")]),
        ])
        seen = []
        advisor = agent.Advisor(client, on_tool=lambda n, a: seen.append(n))
        self.assertEqual(advisor.ask("Teapot Hat for Classic Fedora?"), "GOOD trade.")
        self.assertEqual(seen, ["evaluate_trade", "search_items"])

        second = client.calls[1]
        self.assertEqual(second["model"], "claude-sonnet-5-5")
        self.assertEqual(second["system"], agent.SYSTEM_PROMPT)
        results = second["messages"][-1]["content"]
        self.assertEqual([r["tool_use_id"] for r in results], ["t1", "t2"])  # one user message
        self.assertEqual(json.loads(results[0]["content"])["verdict"], "good")
        self.assertFalse(results[0]["is_error"])

        self.assertEqual(advisor.ask("And now?"), "Follow-up answer.")
        # History kept: user, assistant(tool_use), user(results), assistant, user
        roles = [m["role"] for m in client.calls[2]["messages"]]
        self.assertEqual(roles, ["user", "assistant", "user", "assistant", "user"])

    def test_unknown_tool_and_api_error_rolls_back(self):
        client = FakeClient([
            SimpleNamespace(stop_reason="tool_use", content=[tool_use("t1", "send_trade", {})]),
            SimpleNamespace(stop_reason="end_turn", content=[text("I can't send trades.")]),
        ])
        advisor = agent.Advisor(client)
        advisor.ask("send this trade for me")
        res = client.calls[1]["messages"][-1]["content"][0]
        self.assertTrue(res["is_error"])

        def boom(**kw):
            raise agent.AgentError("Could not reach the Anthropic API.")
        client.beta.messages.create = boom
        before = len(advisor.messages)
        with self.assertRaises(agent.AgentError):
            advisor.ask("hi")
        self.assertEqual(len(advisor.messages), before)

    def test_missing_key_message(self):
        with mock.patch.dict(os.environ, {}, clear=True):
            with self.assertRaisesRegex(agent.AgentError, "ANTHROPIC_API_KEY is not set"):
                agent.make_client()

    def test_tools_match_functions(self):
        self.assertEqual({t["name"] for t in agent.TOOLS}, set(agent.TOOL_FUNCTIONS))
        # Advice only: nothing that could trade, buy or log in is exposed.
        for t in agent.TOOLS:
            for word in ("cookie", "login", "send_trade", "accept", "purchase"):
                self.assertNotIn(word, t["name"])


if __name__ == "__main__":
    unittest.main()
