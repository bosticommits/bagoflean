#!/usr/bin/env python3
"""Movie Mogul economy simulator.

Reads the tuning numbers straight from src/shared/*.luau (so it always simulates what the game
ships), plays a simple "sensible player" through a week of sessions, and prints when each
milestone happens. It mirrors the server math in Movies, Actors, Upgrades and EconomyService.

    python3 tools/economy_sim.py                 # typical player, 300 runs
    python3 tools/economy_sim.py --player casual
    python3 tools/economy_sim.py --runs 50 --seed 7
    python3 tools/economy_sim.py --days 28           # four weeks (rebirths keep going)
    python3 tools/economy_sim.py --no-rebirth        # the player never rebirths
    python3 tools/economy_sim.py --no-events         # the same week without special events

The player model is deliberately plain: it collects, claps, premieres as soon as a film is
ready, buys the cheapest useful upgrade it can afford, picks the best script and cast it owns,
and spends the rest on casting. Once a rebirth costs less than about 20 minutes of income it stops
buying upgrades and saves for it, then rebirths as soon as it can afford one. During special events
it takes part: half the Cash Rain coins, the Mystery Crate's free cast, a Spotlight visit. Real
players are messier, so treat the output as a curve shape, not a promise.
"""
from __future__ import annotations

import argparse
import math
import random
import re
import statistics
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SHARED = ROOT / "src" / "shared"

# --- Reading the Luau tuning files --------------------------------------------------------------


def _num(expr: str) -> float:
    expr = expr.strip().rstrip(",")
    if not re.fullmatch(r"[\d\s.*/+()-]+", expr):
        raise ValueError(f"not a plain number expression: {expr!r}")
    return float(eval(expr, {"__builtins__": {}}))  # digits and arithmetic only (checked above)


def _block(text: str, name: str) -> str:
    """Body of `<name> = { ... }` with balanced braces."""
    start = text.index(name + " = {") + len(name + " = {")
    depth, i = 1, start
    while depth:
        depth += {"{": 1, "}": -1}.get(text[i], 0)
        i += 1
    return text[start : i - 1]


def _rows(body: str) -> list[dict]:
    rows = []
    for row in re.findall(r"\{([^{}]*(?:\{[^{}]*\}[^{}]*)*)\}", body):
        item: dict = {}
        for key, value in re.findall(r"(\w+)\s*=\s*(\"[^\"]*\"|\{[^{}]*\}|[^,]+?)\s*(?:,|$)", row):
            value = value.strip()
            if value.startswith('"'):
                item[key] = value.strip('"')
            elif value.startswith("{"):
                item[key] = [_num(v) for v in value.strip("{}").split(",") if v.strip()]
            elif value == "nil":
                item[key] = None
            else:
                try:
                    item[key] = _num(value)
                except ValueError:
                    item[key] = value
        rows.append(item)
    return rows


def _reward(text: str) -> dict:
    """A Shop.Reward table written on one line: cash, cashMinutes, luckMinutes, skips, script."""
    reward = {}
    for key in ("cash", "cashMinutes", "luckMinutes", "skips"):
        match = re.search(rf"\b{key} = ([\d.]+)", text)
        if match:
            reward[key] = float(match.group(1))
    script = re.search(r'script = \{ genre = "([\w-]+)", length = "(\w+)", count = (\d+)', text)
    if script:
        reward["script"] = (script.group(1), script.group(2), int(script.group(3)))
    return reward


def _special(text: str, name: str) -> float:
    """A plain number tunable `SpecialEvents.<name> = ...` (comments ignored)."""
    return _num(re.search(rf"SpecialEvents\.{name} = ([\d\s.*/+()]+?)\s*(?:--.*)?$", text, re.M).group(1))


def load_tuning() -> dict:
    config_text = (SHARED / "Config.luau").read_text()
    config = {}
    for key, value in re.findall(r"^\s*(\w+)\s*=\s*([^\"\n]+?),?\s*(?:--.*)?$", config_text, re.M):
        try:
            config[key] = _num(value)
        except ValueError:
            pass

    movies_text = (SHARED / "Movies.luau").read_text()
    actors_text = (SHARED / "Actors.luau").read_text()
    upgrades_text = (SHARED / "Upgrades.luau").read_text()

    genre_fame = {
        k.strip('["]'): _num(v)
        for k, v in re.findall(r"(\[?\"?[\w-]+\"?\]?)\s*=\s*([\d.]+)", _block(movies_text, "Movies.GenreFame"))
    }
    upgrades = _rows(_block(upgrades_text, "Upgrades.List"))
    for upgrade in upgrades:
        if upgrade["id"] == "Stages":
            upgrade["maxLevel"] = config["MaxStages"] - config["StartingStages"]

    rebirth_text = (SHARED / "Rebirth.luau").read_text()
    rebirth = {key: _num(value) for key, value in re.findall(r"^Rebirth\.(\w+) = ([\d.]+)", rebirth_text, re.M)}

    events_text = (SHARED / "Events.luau").read_text()
    rewards_text = (SHARED / "Rewards.luau").read_text()
    codes_text = (ROOT / "src" / "server" / "Codes.luau").read_text()
    achievements_text = (SHARED / "Achievements.luau").read_text()
    specials_text = (SHARED / "SpecialEvents.luau").read_text()

    return {
        "config": config,
        "rebirth": rebirth,
        "award_period": _num(re.search(r"Events.AwardNightPeriod = ([^\n]+)", events_text).group(1)),
        "award_length": _num(re.search(r"Events.AwardNightLength = ([^\n]+)", events_text).group(1)),
        "daily": [_reward(line) for line in _block(rewards_text, "Rewards.Daily").splitlines() if "{" in line],
        "stay_gift": _reward(re.search(r"Rewards.StayGift = (\{[^\n]*\})", rewards_text).group(1)),
        "requests": [_reward(line.split("reward =")[1]) for line in _block(rewards_text, "Rewards.Requests").splitlines()
                     if "reward =" in line],
        "requests_per_day": int(_num(re.search(r"Rewards.RequestsPerDay = (\d+)", rewards_text).group(1))),
        "codes": [_reward(line.split("reward =")[1]) for line in codes_text.splitlines() if "reward =" in line],
        "achievements": [
            {"id": m.group(1), "stat": m.group(2), "target": _num(m.group(3)), "reward": _reward(line.split("reward =")[1])}
            for line in _block(achievements_text, "Achievements.List").splitlines()
            if (m := re.search(r'id = "(\w+)".*stat = "([\w:-]+)", target = (\d+)', line))
        ],
        "specialty": _num(re.search(r"Movies.SpecialtyBonus = ([\d.]+)", movies_text).group(1)),
        "fame_exponent": _num(re.search(r"Movies.FameExponent = ([\d.]+)", movies_text).group(1))
        if "Movies.FameExponent" in movies_text
        else 0.5,
        "genres": re.findall(r"\"([\w-]+)\"", _block(movies_text, "Movies.Genres")),
        "lengths": _rows(_block(movies_text, "Movies.Lengths")),
        "genre_fame": genre_fame,
        "results": _rows(_block(movies_text, "Movies.Results")),
        "tiers": _rows(_block(actors_text, "Actors.Tiers")),
        "actors": _rows(_block(actors_text, "Actors.List")),
        "variants": _rows(_block(actors_text, "Actors.Variants")),
        "agencies": _rows(_block(actors_text, "Actors.Agencies")),
        "upgrades": {u["id"]: u for u in upgrades},
        "specials": {
            "events": [(m.group(1), _num(m.group(2))) for m in re.finditer(
                r'id = "(\w+)",.*?seconds = ([\d.]+)', _block(specials_text, "SpecialEvents.List"), re.S)],
            "slot": _special(specials_text, "SlotSeconds"),
            "gap": _special(specials_text, "Gap"),
            "luck": _special(specials_text, "LuckMultiplier"),
            "coins": int(_special(specials_text, "CoinCount")),
            "coin_cash": _special(specials_text, "CoinCash"),
            "coin_cinema_seconds": _special(specials_text, "CoinCinemaSeconds"),
            "coin_fame_share": _special(specials_text, "CoinFameShare"),
            "crate_luck": _special(specials_text, "CrateLuckMultiplier"),
            "spotlight_reward": _reward(re.search(r"SpecialEvents.SpotlightReward = (\{[^\n]*\})", specials_text).group(1)),
            "film_speed": _special(specials_text, "FilmSpeed"),
        },
    }


# --- Game math (mirrors the Luau) ----------------------------------------------------------------


class Game:
    def __init__(self, tuning: dict):
        self.t = tuning
        self.c = tuning["config"]
        self.tier_index = {tier["id"]: i for i, tier in enumerate(tuning["tiers"])}
        self.tier = {tier["id"]: tier for tier in tuning["tiers"]}
        self.actor = {actor["id"]: actor for actor in tuning["actors"]}
        self.variant = {v["id"]: v for v in tuning["variants"]}
        self.by_tier: dict[str, list] = {}
        for actor in tuning["actors"]:
            self.by_tier.setdefault(actor["tier"], []).append(actor)
        self.result_mult = {r["id"]: r["multiplier"] for r in tuning["results"]}
        self._tier_cache: dict = {}
        self._premiere_cache: dict = {}
        self._special_cache: dict = {}

    # Special events (SpecialEvents.luau): one per slot of the clock, dealt like a deck, at a random
    # time in the slot clear of Award Night. Python's RNG stands in for Roblox's, so the order
    # differs from the game's but the share of each event and the timing rules are the same.
    def special_window(self, slot: int, seconds: float) -> tuple[float, float] | None:
        sp, period, length = self.t["specials"], self.t["award_period"], self.t["award_length"]
        gap = sp["gap"]
        first = slot * sp["slot"] + gap
        last = (slot + 1) * sp["slot"] - gap - seconds
        for n in range(int((first - length - gap) // period), int((last + seconds + gap) // period) + 1):
            block_from, block_to = n * period - gap - seconds, n * period + length + gap
            if block_to > first and block_from < last:
                if last - block_to >= block_from - first:
                    first = max(first, block_to)
                else:
                    last = min(last, block_from)
        return None if last < first else (first, last)

    def special_for_slot(self, slot: int) -> tuple[str, float, float] | None:
        if slot in self._special_cache:
            return self._special_cache[slot]
        events = self.t["specials"]["events"]

        def deck(cycle: int) -> list:
            cards = list(events)
            random.Random(cycle).shuffle(cards)
            return cards

        cycle = slot // len(events)
        cards = deck(cycle)
        if cards[0] == deck(cycle - 1)[-1]:
            cards[0], cards[1] = cards[1], cards[0]
        event_id, seconds = cards[slot % len(events)]
        window = self.special_window(slot, seconds)
        out = None
        if window is not None:
            starts = window[0] + random.Random(slot).randint(0, int(window[1] - window[0]))
            out = (event_id, starts, starts + seconds)
        self._special_cache[slot] = out
        return out

    def special_at(self, clock: float) -> tuple[str, float, float] | None:
        live = self.special_for_slot(int(clock // self.t["specials"]["slot"]))
        return live if live is not None and live[1] <= clock < live[2] else None

    def tier_chances(self, luck: float, min_tier: int) -> list[tuple[str, float]]:
        key = (round(luck, 4), min_tier)
        if key in self._tier_cache:
            return self._tier_cache[key]
        tiers = self.t["tiers"]
        open_ = {}
        remaining = 1.0
        for tier in reversed(tiers[1:]):
            chance = remaining * min(1.0, max(luck, 1.0) / tier["oneIn"])
            open_[tier["id"]] = chance
            remaining -= chance
        open_[tiers[0]["id"]] = remaining
        removed = sum(open_[tiers[i]["id"]] for i in range(min_tier - 1))
        out = [(tier["id"], 0.0 if i < min_tier - 1 else open_[tier["id"]] / (1 - removed)) for i, tier in enumerate(tiers)]
        self._tier_cache[key] = out
        return out

    def variant_chances(self, luck: float) -> dict:
        luck = max(luck, 1.0)
        award_one_in = self.variant["Award"]["oneIn"]
        shiny_one_in = self.variant["Shiny"]["oneIn"]
        award = min(1.0, luck / award_one_in)
        shiny = (1 - award) * min(1.0, luck / shiny_one_in)
        return {"Normal": 1 - award - shiny, "Shiny": shiny, "Award": award}

    def roll_actor(self, rng: random.Random, luck: float, min_tier: int) -> tuple[str, str]:
        pick, running, chosen = rng.random(), 0.0, None
        for tier_id, chance in self.tier_chances(luck, min_tier):
            running += chance
            chosen = tier_id
            if pick < running:
                break
        actor = rng.choice(self.by_tier[chosen])
        v = self.variant_chances(luck)
        vp = rng.random()
        variant = "Award" if vp < v["Award"] else "Shiny" if vp < v["Award"] + v["Shiny"] else "Normal"
        return actor["id"], variant

    def premiere_chances(self, luck: float) -> dict:
        key = round(luck, 4)
        if key in self._premiere_cache:
            return self._premiere_cache[key]
        luck = max(luck, 1.0)
        chances = {r["id"]: r["chance"] for r in self.t["results"]}
        extra = 0.0
        for rid in ("Blockbuster", "Cult", "Masterpiece"):
            add = chances[rid] * (luck - 1)
            chances[rid] += add
            extra += add
        for rid in ("Flop", "Hit"):
            take = min(chances[rid], extra)
            chances[rid] -= take
            extra -= take
        total = sum(chances.values())
        out = {k: v / total for k, v in chances.items()}
        self._premiere_cache[key] = out
        return out

    def expected_result_mult(self, luck: float) -> float:
        return sum(p * self.result_mult[rid] for rid, p in self.premiere_chances(luck).items())

    def roll_result(self, rng: random.Random, luck: float) -> str:
        pick, running, chosen = rng.random(), 0.0, "Flop"
        for result in self.t["results"]:
            running += self.premiere_chances(luck)[result["id"]]
            chosen = result["id"]
            if pick < running:
                break
        return chosen

    def actor_power(self, key: str, genre: str) -> float:
        actor_id, variant_id = key.split(":")
        actor = self.actor[actor_id]
        bonus = self.t["specialty"] if actor["genre"] == genre else 1.0
        return self.tier[actor["tier"]]["starPower"] * self.variant[variant_id]["multiplier"] * bonus

    def payout(self, base: float, power: float, mult: float, genre_bonus: float) -> int:
        return max(1, math.floor(base * power * genre_bonus * mult))

    def fame(self, payout: float) -> int:
        return max(1, math.floor(payout ** self.t["fame_exponent"]))


# --- One player ---------------------------------------------------------------------------------

UPGRADE_ORDER = ["Stages", "Cinema", "Luck", "Offline", "Clap"]


class Player:
    def __init__(self, game: Game, rng: random.Random, clap_rate: float, cast_rate: float):
        self.g, self.rng = game, rng
        c = game.c
        self.clap_rate, self.cast_rate = clap_rate, cast_rate
        self.now = 0.0
        self.cash = c["StartingCash"]
        self.fame = 0
        self.accrued = 0.0
        self.last_collect = 0.0
        self.cinema: list[int] = []
        self.films: list[dict] = []  # {stage, end, length, genre, cast, base}
        self.roster: dict[str, int] = {}
        self.index: set[str] = set()
        self.upgrades = {u: 0 for u in UPGRADE_ORDER if u != "Stages"}
        self.stage_count = int(c["StartingStages"])
        self.rewards: set[str] = set()
        self.first_film_done = False
        self.events: dict[str, float] = {}
        self.cast_credit = 0.0
        self.clap_credit = 0.0
        self.earned_total = 0.0
        self.premieres = 0
        self.played = 0.0
        self.offline_earned = 0.0
        self.reward_earned = 0.0
        self.luck_boost_until = 0.0
        self.skips = 0
        self.free_scripts: dict[tuple[str, str], int] = {}
        self.streak = 0
        self.sessions = 0
        self.luck_pass = False
        self.achievements = True
        self.counts = {"cast": 0, "premiere": 0, "hit": 0, "clap": 0, "script": 0, "collect": 0}
        self.trophies = 0
        self.claimed: set[str] = set()
        self.last_daily_day = -1
        self.clock_offset = rng.uniform(0, game.t["award_period"])  # where Award Night falls
        self.specials_on = True
        self.special_done: tuple | None = None  # the special event whose pickups are taken
        self.curve: dict[int, dict] = {}
        self.rebirths = 0
        self.rebirth_enabled = True

    # stats
    def level(self, uid: str) -> int:
        return self.stage_count - int(self.g.c["StartingStages"]) if uid == "Stages" else self.upgrades[uid]

    def luck(self) -> float:
        c = self.g.c
        tiers = sum(1 for r in self.rewards if r.startswith("tier:"))
        return (c["BaseLuck"] + c["LuckStep"] * self.level("Luck") + c["TierRewardLuck"] * tiers
                + self.g.t["rebirth"]["LuckStep"] * self.rebirths)

    # rebirth (Rebirth.luau and RebirthService)
    def cash_mult(self) -> float:
        return 1 + self.g.t["rebirth"]["CashStep"] * self.rebirths

    def rebirth_cost(self) -> float | None:
        r = self.g.t["rebirth"]
        if not self.rebirth_enabled or self.rebirths >= r["Max"]:
            return None
        return math.floor(r["FirstCost"] * r["CostGrowth"] ** self.rebirths)

    def saving_for_rebirth(self) -> float | None:
        """The rebirth price while the player is saving for it (within SAVE_MINUTES of income)."""
        cost = self.rebirth_cost()
        if cost is None or cost > self.income_per_second() * 60 * SAVE_MINUTES:
            return None
        return cost

    def try_rebirth(self):
        cost = self.rebirth_cost()
        if cost is None or self.cash < cost:
            return
        # RebirthService: bank the box office at the old rate, then reset Cash and upgrades. The
        # waiting box office comes along as starting Cash; films already filming keep going.
        self.accrue()
        banked = math.floor(self.accrued)
        self.accrued -= banked
        self.cash = self.g.c["StartingCash"] + banked
        self.upgrades = {u: 0 for u in self.upgrades}
        self.stage_count = int(self.g.c["StartingStages"])
        self.rebirths += 1
        self.mark(f"Rebirth {self.rebirths}")

    def award_night(self) -> bool:
        return (self.now + self.clock_offset) % self.g.t["award_period"] < self.g.t["award_length"]

    def special(self) -> tuple[str, float, float] | None:
        """The special event live now: (id, starts, ends) on the game clock, or None."""
        return self.g.special_at(self.now + self.clock_offset) if self.specials_on else None

    def cast_luck(self) -> float:
        """CastingService.castLuck: stat Luck x 2x Luck pass x Lucky Casting x Award Night x
        Lucky Star."""
        luck = self.luck()
        if self.luck_pass:
            luck *= self.g.c["PassLuckMultiplier"]
        if self.luck_boost_until > self.now:
            luck *= self.g.c["BoostLuckMultiplier"]
        if self.award_night():
            luck *= self.g.c["AwardNightLuckMultiplier"]
        live = self.special()
        if live is not None and live[0] == "LuckyStar":
            luck *= self.g.t["specials"]["luck"]
        return luck

    def clap_seconds(self) -> float:
        return self.g.c["ClapSeconds"] + self.g.c["ClapStep"] * self.level("Clap")

    def offline_cap(self) -> float:
        return self.g.c["OfflineCapSeconds"] + self.g.c["OfflineCapStepSeconds"] * self.level("Offline")

    def rate(self) -> float:
        c = self.g.c
        royalties = sum(p * c["RoyaltyRate"] for p in self.cinema)
        return c["CinemaIncomePerSecond"] + royalties * (1 + c["CinemaStep"] * self.level("Cinema"))

    def mark(self, name: str):
        self.events.setdefault(name, self.now)

    # economy
    def accrue(self):
        elapsed = max(self.now - self.last_collect, 0)
        rate = self.rate()
        self.accrued = min(self.accrued + elapsed * rate, self.offline_cap() * rate)
        self.last_collect = self.now

    def collect(self):
        self.accrue()
        amount = math.floor(self.accrued)
        self.accrued -= amount
        self.cash += amount
        self.earned_total += amount

    def genre_bonus(self, genre: str) -> float:
        return 1 + (self.g.c["GenreBonus"] if f"genre:{genre}" in self.rewards else 0)

    # rewards
    def claim_rewards(self):
        discovered = {k.split(":")[0] for k in self.index}
        for tier in self.g.t["tiers"]:
            rid = f"tier:{tier['id']}"
            if rid not in self.rewards and all(a["id"] in discovered for a in self.g.by_tier[tier["id"]]):
                self.rewards.add(rid)
                self.mark(f"Index row done: {tier['id']}")
        for genre in self.g.t["genres"]:
            rid = f"genre:{genre}"
            members = [a["id"] for a in self.g.t["actors"] if a["genre"] == genre]
            if rid not in self.rewards and members and all(m in discovered for m in members):
                self.rewards.add(rid)

    def grant(self, reward: dict):
        """RewardService.apply: Cash is the floor or minutes of cinema income, whichever is more."""
        cash = reward.get("cash", 0.0)
        if "cashMinutes" in reward:
            cash = max(cash, self.rate() * reward["cashMinutes"] * 60)
        cash = math.floor(cash)
        self.cash += cash
        self.earned_total += cash
        self.reward_earned += cash
        if "luckMinutes" in reward:
            self.luck_boost_until = max(self.luck_boost_until, self.now) + reward["luckMinutes"] * 60
        self.skips += int(reward.get("skips", 0))
        if "script" in reward:
            genre, length, count = reward["script"]
            self.free_scripts[(genre, length)] = self.free_scripts.get((genre, length), 0) + count

    def login_rewards(self, day: int, first_session_today: bool, session_number: int):
        if session_number == 2:  # codes are found on socials, so not in the very first session
            for code in self.g.t["codes"]:
                self.grant(code)
        if day != self.last_daily_day:
            self.streak = self.streak + 1 if day == self.last_daily_day + 1 else 1
            self.last_daily_day = day
            daily = self.g.t["daily"]
            self.grant(daily[(self.streak - 1) % len(daily)])
            if self.streak in (7, 14, 21):
                self.mark(f"Day {self.streak} streak reward")

    def achievement_value(self, stat: str) -> float:
        if stat == "masterpiece":
            return self.trophies
        if stat == "fame":
            return self.fame
        if stat == "index":
            return len(self.index)
        if stat.startswith("tier:"):
            return sum(1 for k in self.index if self.g.actor[k.split(":")[0]]["tier"] == stat[5:])
        if stat.startswith("variant:"):
            return sum(1 for k in self.index if k.split(":")[1] == stat[8:])
        return self.counts.get(stat, 0)

    def claim_achievements(self):
        """Achievements: claimed as soon as they are done (one-time rewards)."""
        if not self.achievements:
            return
        for a in self.g.t["achievements"]:
            if a["id"] not in self.claimed and self.achievement_value(a["stat"]) >= a["target"]:
                self.claimed.add(a["id"])
                self.grant(a["reward"])

    def special_events(self, step: float):
        """Takes part in the live special event: Golden Hour speeds films up; the one-off pickups
        are taken once the player has had time to get there (about 20 s in). A sensible player
        grabs half the Cash Rain coins."""
        live = self.special()
        if live is None:
            return
        event_id, starts, _ = live
        sp = self.g.t["specials"]
        if event_id == "GoldenHour":
            for film in self.films:
                if film["end"] > self.now:
                    film["end"] = max(self.now, film["end"] - step * (sp["film_speed"] - 1))
        if self.special_done == (event_id, starts) or self.now + self.clock_offset < starts + 20:
            return
        self.special_done = (event_id, starts)
        self.mark("First special event")
        if event_id == "CashRain":
            # SpecialEvents.coinCash: the most of a floor, cinema income, or a share of Fame.
            coin = max(sp["coin_cash"], self.rate() * sp["coin_cinema_seconds"], self.fame * sp["coin_fame_share"])
            for _ in range(sp["coins"] // 2):
                self.grant({"cash": coin})
        elif event_id == "MysteryCrate":
            agency = [a for a in self.g.t["agencies"] if self.fame >= a["fame"]][-1]
            self.roll(agency, self.cast_luck() * sp["crate_luck"])
        elif event_id == "Spotlight":
            self.grant(sp["spotlight_reward"])

    def finish_requests(self):
        """Studio Requests: the player finishes the day's three during the first session."""
        for request in self.rng.sample(self.g.t["requests"], self.g.t["requests_per_day"]):
            self.grant(request)

    def use_skips(self):
        while self.skips > 0:
            running = [f for f in self.films if f["end"] > self.now]
            if not running:
                return
            max(running, key=lambda f: f["end"])["end"] = self.now
            self.skips -= 1

    # films
    def busy_counts(self) -> dict[str, int]:
        busy: dict[str, int] = {}
        for film in self.films:
            for key in film["cast"]:
                busy[key] = busy.get(key, 0) + 1
        return busy

    def best_cast(self, genre: str) -> tuple[list[str], float]:
        busy = self.busy_counts()
        copies = []
        for key, count in self.roster.items():
            free = count - busy.get(key, 0)
            if free > 0:
                power = self.g.actor_power(key, genre)
                copies += [(power, key)] * min(free, int(self.g.c["MaxCast"]))
        copies.sort(reverse=True)
        chosen = copies[: int(self.g.c["MaxCast"])]
        return [k for _, k in chosen], sum(p for p, _ in chosen)

    def unlocked_genres(self):
        return [g for g in self.g.t["genres"] if self.fame >= self.g.t["genre_fame"].get(g, 0)]

    def unlocked_lengths(self):
        return [l for l in self.g.t["lengths"] if self.fame >= l["fame"]]

    def choose_film(self, window: float | None):
        """Best (length, genre, cast, power). `window` = seconds until the player can next premiere
        (None while actively playing: optimise profit per second instead)."""
        luck_mult = self.g.expected_result_mult(self.luck())
        best, best_score = None, 0.0
        for genre in self.unlocked_genres():
            cast, power = self.best_cast(genre)
            if not cast:
                continue
            for length in self.unlocked_lengths():
                if length["cost"] > self.cash:
                    continue
                expected = length["base"] * power * self.genre_bonus(genre) * luck_mult * self.cash_mult()
                profit = expected - length["cost"]
                if profit <= 0:
                    continue
                if window is None:
                    # Active: clapping shortens films; assume taps are shared across busy stages.
                    speed = 1 + self.clap_rate * self.clap_seconds() / max(1, len(self.films) + 1)
                    score = profit / (length["seconds"] / speed)
                else:
                    # Going offline: the most profit that is ready by the time the player is back.
                    if length["seconds"] > window and length is not self.unlocked_lengths()[0]:
                        continue
                    score = profit
                if score > best_score:
                    best, best_score = (length, genre, cast, power), score
        return best

    def start_films(self, window: float | None):
        used = {f["stage"] for f in self.films}
        for stage in range(1, self.stage_count + 1):
            if stage in used:
                continue
            choice = self.choose_film(window)
            if choice is None:
                return
            length, genre, cast, power = choice
            free = next((key for key, n in self.free_scripts.items() if n > 0 and key[1] == length["id"]
                         and key[0] in self.unlocked_genres()), None)
            if free is not None:
                self.free_scripts[free] -= 1
                genre = free[0]
                cast, power = self.best_cast(genre)
            else:
                self.cash -= length["cost"]
                self.counts["script"] += 1
            seconds = length["seconds"]
            if not self.first_film_done:
                seconds = min(seconds, self.g.c["FirstFilmSeconds"])
                self.first_film_done = True
            self.films.append({"stage": stage, "end": self.now + seconds, "length": length, "genre": genre,
                               "cast": cast, "power": power})
            self.mark(f"First {length['name']}")

    def award_night_before(self, deadline: float) -> bool:
        period, length = self.g.t["award_period"], self.g.t["award_length"]
        into = (self.now + self.clock_offset) % period
        return into < length or self.now + (period - into) < deadline

    def premiere_ready(self, session_end: float | None = None):
        ready = [f for f in self.films if f["end"] <= self.now]
        if session_end is not None and not self.award_night() and self.award_night_before(session_end):
            # Save finished Features and Epics for the doubled Award Night payout (plan section 12).
            ready = [f for f in ready if f["length"]["seconds"] < 45 * M]
        for film in ready:
            self.films.remove(film)
            result = self.g.roll_result(self.rng, self.luck())
            payout = self.g.payout(film["length"]["base"], film["power"], self.g.result_mult[result],
                                   self.genre_bonus(film["genre"]))
            if self.award_night():
                payout *= self.g.c["AwardNightPayoutMultiplier"]
            fame = self.g.fame(payout)  # Fame comes from the movie itself, before the rebirth bonus
            payout = math.floor(payout * self.cash_mult())
            self.accrue()
            self.cinema.append(payout)
            self.cinema.sort(reverse=True)
            del self.cinema[int(self.g.c["CinemaCapacity"]):]
            self.fame += fame
            self.cash += payout
            self.earned_total += payout
            self.premieres += 1
            self.counts["premiere"] += 1
            if self.g.result_mult[result] >= 3:
                self.counts["hit"] += 1
            if result == "Masterpiece":
                self.trophies += 1
            self.mark(f"First {result}")
            for name, gate in self.fame_gates():
                if self.fame >= gate:
                    self.mark(name)

    def fame_gates(self):
        t = self.g.t
        for genre, fame in t["genre_fame"].items():
            if fame > 0:
                yield f"Unlock {genre} scripts", fame
        for length in t["lengths"]:
            if length["fame"] > 0:
                yield f"Unlock {length['name']} scripts", length["fame"]
        for agency in t["agencies"]:
            if agency["fame"] > 0:
                yield f"Unlock {agency['name']}", agency["fame"]

    # spending
    def next_upgrade(self):
        best = None
        for uid in UPGRADE_ORDER:
            upgrade = self.g.t["upgrades"][uid]
            level = self.level(uid)
            if level >= upgrade["maxLevel"] or self.fame < upgrade["fame"][level]:
                continue
            cost = upgrade["costs"][level]
            if best is None or cost < best[1]:
                best = (uid, cost)
        return best

    def buy_upgrades(self):
        if self.saving_for_rebirth() is not None:
            return  # upgrades would be reset by the rebirth
        while True:
            nxt = self.next_upgrade()
            if nxt is None or nxt[1] > self.cash:
                return
            uid, cost = nxt
            self.accrue()
            self.cash -= cost
            if uid == "Stages":
                self.stage_count += 1
                self.mark(f"Sound stage {self.stage_count}")
            else:
                self.upgrades[uid] += 1
                if self.upgrades[uid] == self.g.t["upgrades"][uid]["maxLevel"]:
                    self.mark(f"{uid} upgrade maxed")
            if all(self.level(u) >= self.g.t["upgrades"][u]["maxLevel"] for u in UPGRADE_ORDER):
                self.mark("All upgrades maxed")

    def income_per_second(self) -> float:
        luck_mult = self.g.expected_result_mult(self.luck())
        films = 0.0
        for film in self.films:
            films += film["length"]["base"] * film["power"] * luck_mult / film["length"]["seconds"]
        return self.rate() + films * self.cash_mult()

    def cast(self, dt: float):
        self.cast_credit = min(self.cast_credit + self.cast_rate * dt, 3)
        # Save towards the next upgrade if it is within ~4 minutes of income.
        reserve = 0.0
        nxt = self.next_upgrade()
        saving = self.saving_for_rebirth()
        if saving is not None:
            reserve = saving
        elif nxt is not None and nxt[1] <= self.income_per_second() * 240:
            reserve = nxt[1]
        # Keep money for a script on every stage too.
        reserve += sum(l["cost"] for l in self.unlocked_lengths()[:1]) * self.stage_count
        while self.cast_credit >= 1:
            budget = self.cash - reserve
            agency = None
            for a in self.g.t["agencies"]:
                if self.fame >= a["fame"] and a["cost"] * 10 <= budget:
                    agency = a
            if agency is None:
                if self.cash >= self.g.t["agencies"][0]["cost"] and len(self.roster) < 3:
                    agency = self.g.t["agencies"][0]  # first few casts in the tutorial
                else:
                    return
            self.cast_credit -= 1
            self.counts["cast"] += 1
            self.cash -= agency["cost"]
            self.roll(agency, self.cast_luck())

    def roll(self, agency: dict, luck: float):
        actor_id, variant = self.g.roll_actor(self.rng, luck, int(agency["minTier"]))
        key = f"{actor_id}:{variant}"
        self.roster[key] = self.roster.get(key, 0) + 1
        self.index.add(key)
        self.mark(f"First {self.g.actor[actor_id]['tier']} actor")
        if variant != "Normal":
            self.mark(f"First {variant} variant")
        for n in (21, 32, 42, 63):
            if len(self.index) >= n:
                self.mark(f"Index {n}/63")
        if agency["minTier"] > 1:
            self.mark(f"First roll at {agency['name']}")

    def clap(self, dt: float):
        self.clap_credit += self.clap_rate * dt
        running = [f for f in self.films if f["end"] > self.now]
        while self.clap_credit >= 1 and running:
            self.clap_credit -= 1
            self.counts["clap"] += 1
            film = min(running, key=lambda f: f["end"])
            film["end"] = max(self.now, film["end"] - self.clap_seconds())
            running = [f for f in self.films if f["end"] > self.now]
        self.clap_credit = min(self.clap_credit, 1)

    # time
    def play(self, seconds: float, offline_after: float, day: int, first_today: bool, last_today: bool,
             step: float = 2.0):
        end = self.now + seconds
        before = self.earned_total
        self.premiere_ready(end)
        self.collect()
        self.offline_earned += self.earned_total - before
        self.sessions += 1
        self.login_rewards(day, first_today, self.sessions)
        self.use_skips()
        requests_at = self.now + min(seconds, 10 * M) if first_today else None
        last_collect = self.now
        while self.now < end:
            self.now += step
            self.played += step
            mark = int(self.played // M)
            if mark in CURVE_MINUTES and mark not in self.curve:
                self.curve[mark] = self.snapshot()
            self.clap(step)
            self.special_events(step)
            self.premiere_ready(end)
            if self.now - last_collect >= 30:
                self.collect()
                self.counts["collect"] += 1
                last_collect = self.now
            if requests_at is not None and self.now >= requests_at:
                self.finish_requests()
                requests_at = None
            self.claim_rewards()
            self.claim_achievements()
            self.try_rebirth()
            self.buy_upgrades()
            remaining = end - self.now
            self.start_films(None if remaining > 180 else remaining + offline_after)
            self.cast(step)
        if last_today and seconds >= self.g.c["StayGiftMinSeconds"]:
            self.grant(self.g.t["stay_gift"])
        self.collect()
        self.buy_upgrades()
        self.start_films(offline_after)
        self.now = end + offline_after

    def snapshot(self) -> dict:
        return {"cash/min": self.income_per_second() * 60, "cinema/min": self.rate() * 60, "fame": self.fame, "luck": self.luck(),
                "index": len(self.index),
                "reward %": 100 * self.reward_earned / max(1, self.earned_total),
                "offline %": 100 * self.offline_earned / max(1, self.earned_total), "stages": self.stage_count, "premieres": self.premieres,
                "rebirths": self.rebirths}


# --- Schedules ----------------------------------------------------------------------------------

H, M = 3600, 60
# Attention while online: a roll every ~3 s and a clapperboard tap every ~1.7 s on average (the
# player is also reading reveals, picking casts and walking to the collect pad).
CAST_RATE = 0.35
CLAP_RATE = 0.6
CURVE_MINUTES = (5, 10, 20, 30, 45, 60, 90, 120, 180, 240, 300, 330, 480, 660, 990, 1320)
# A player starts saving for a rebirth once it costs less than this many minutes of income.
SAVE_MINUTES = 20


def schedule(kind: str, total_days: int = 7) -> list[tuple[str, float, float]]:
    """(label, minutes online, minutes offline after). Each day adds to 24 h."""
    days = []
    if kind == "typical":
        # Day 1: 20 + 15 + 25 min. Then 3 x 15 min a day.
        day1 = [(20, 3 * 60), (15, 4.5 * 60), (25, 0)]
        rest = [(15, 5 * 60), (15, 5 * 60), (15, 0)]
    elif kind == "casual":
        day1 = [(15, 6 * 60), (10, 0)]
        rest = [(10, 8 * 60), (10, 0)]
    elif kind == "hardcore":
        day1 = [(60, 2 * 60), (45, 3 * 60), (60, 0)]
        rest = [(60, 3 * 60), (60, 0)]
    else:
        raise SystemExit(f"unknown player {kind}")
    for day in range(1, total_days + 1):
        plan = day1 if day == 1 else rest
        used = sum(on + off for on, off in plan)
        sessions = list(plan)
        sessions[-1] = (sessions[-1][0], 24 * 60 - used)
        for n, (on, off) in enumerate(sessions, 1):
            days.append((f"day {day} session {n}", on, off))
    return days


def fmt_time(seconds: float | None, sched) -> str:
    """Seconds of game clock -> 'day 2, 14 min played'."""
    if seconds is None:
        return "-"
    clock, played = 0.0, 0.0
    for label, on, off in sched:
        if seconds <= clock + on * M:
            played += seconds - clock
            day = label.split()[1]
            return f"day {day} ({played / M:.0f} min played)"
        clock += (on + off) * M
        played += on * M
    return "later"


def played_minutes(seconds: float, sched) -> float:
    clock, played = 0.0, 0.0
    for _, on, off in sched:
        if seconds <= clock + on * M:
            return (played + max(0, seconds - clock)) / M
        if seconds <= clock + (on + off) * M:
            return (played + on * M) / M
        clock += (on + off) * M
        played += on * M
    return played / M


def run(tuning: dict, kind: str, runs: int, seed: int, luck_pass: bool = False, days: int = 7,
        rebirth: bool = True, achievements: bool = True, specials: bool = True):
    game = Game(tuning)
    sched = schedule(kind, days)
    events: dict[str, list[float]] = {}
    snaps: dict[str, list[dict]] = {}
    last_of_day = {}
    for label, _, _ in sched:
        last_of_day[label.split()[1]] = label
    checkpoints = {"day 1 session 1": "end of first session", last_of_day["1"]: "end of day 1",
                   last_of_day["3"]: "end of day 3"}
    for week in range(1, days // 7 + 1):
        checkpoints[last_of_day[str(week * 7)]] = f"end of week {week}"
    for r in range(runs):
        player = Player(game, random.Random(seed + r), clap_rate=CLAP_RATE, cast_rate=CAST_RATE)
        player.luck_pass = luck_pass
        player.achievements = achievements
        player.rebirth_enabled = rebirth
        player.specials_on = specials
        for i, (label, on, off) in enumerate(sched):
            day = int(label.split()[1])
            first_today = i == 0 or sched[i - 1][0].split()[1] != str(day)
            last_today = i == len(sched) - 1 or sched[i + 1][0].split()[1] != str(day)
            player.play(on * M, off * M, day, first_today, last_today)
            if label in checkpoints:
                snaps.setdefault(checkpoints[label], []).append(player.snapshot())
        for name, at in player.events.items():
            events.setdefault(name, []).append(at)
        for mark, snap in player.curve.items():
            snaps.setdefault(f"{mark} min played", []).append(snap)
    return game, sched, events, snaps, runs


def report(kind: str, runs: int, seed: int, luck_pass: bool = False, days: int = 7, rebirth: bool = True,
           achievements: bool = True, specials: bool = True):
    tuning = load_tuning()
    game, sched, events, snaps, runs = run(tuning, kind, runs, seed, luck_pass, days, rebirth, achievements, specials)
    owns = " with the 2x Luck pass" if luck_pass else ""
    never = ", never rebirths" if not rebirth else ""
    without = ", no special events" if not specials else ""
    print(f"# Movie Mogul economy sim: {kind} player{owns}{never}{without}, {runs} runs\n")
    total_played = sum(on for _, on, _ in sched)
    print(f"Schedule: {total_played / 60:.1f} h played over {days} days.\n")
    print("| Milestone | Players who reach it | Median | Fast 10% | Slow 10% |")
    print("|---|---|---|---|---|")
    rows = []
    for name, times in events.items():
        times = sorted(times)
        median = times[len(times) // 2] if len(times) * 2 >= runs else None
        rows.append((median if median is not None else times[0] + 1e12, name, times))
    for _, name, times in sorted(rows):
        share = len(times) / runs
        median = times[len(times) // 2] if share >= 0.5 else None
        p10 = times[max(0, int(runs * 0.1) - 1)] if share >= 0.1 else None
        p90 = times[int(runs * 0.9) - 1] if share >= 0.9 else None
        print(f"| {name} | {share:.0%} | {fmt_time(median, sched)} | {fmt_time(p10, sched)} | {fmt_time(p90, sched)} |")
    print()
    keys = list(next(iter(snaps.values()))[0])
    print("| When | " + " | ".join(keys) + " |")
    print("|---" * (len(keys) + 1) + "|")
    for label, rows_ in snaps.items():
        if "min played" in label:
            continue
        print(f"| {label} | " + " | ".join(f"{statistics.median(r[k] for r in rows_):,.1f}" for k in keys) + " |")
    print()
    print("Curve by minutes played (median):\n")
    print("| Played | " + " | ".join(keys) + " |")
    print("|---" * (len(keys) + 1) + "|")
    for mark in CURVE_MINUTES:
        rows_ = snaps.get(f"{mark} min played")
        if rows_:
            print(f"| {mark} min | " + " | ".join(f"{statistics.median(r[k] for r in rows_):,.1f}" for k in keys) + " |")
    print()


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--player", default="typical", choices=["typical", "casual", "hardcore"])
    parser.add_argument("--runs", type=int, default=300)
    parser.add_argument("--seed", type=int, default=1)
    parser.add_argument("--luck-pass", action="store_true", help="the player owns the 2x Luck game pass")
    parser.add_argument("--days", type=int, default=7, help="days to simulate (whole weeks get a checkpoint)")
    parser.add_argument("--no-rebirth", action="store_true", help="the player never rebirths")
    parser.add_argument("--no-achievements", action="store_true", help="leave achievement rewards out (to compare)")
    parser.add_argument("--no-events", action="store_true", help="switch the special events off (to compare)")
    args = parser.parse_args()
    report(args.player, args.runs, args.seed, args.luck_pass, args.days, not args.no_rebirth, not args.no_achievements,
           not args.no_events)
