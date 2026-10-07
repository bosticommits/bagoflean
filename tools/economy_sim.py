#!/usr/bin/env python3
"""Movie Mogul economy simulator.

Reads the tuning numbers straight from src/shared/*.luau (so it always simulates what the game
ships), plays a simple "sensible player" through a week of sessions, and prints when each
milestone happens. It mirrors the server math in Movies, Actors, Upgrades and EconomyService.

    python3 tools/economy_sim.py                 # typical player, 300 runs
    python3 tools/economy_sim.py --player casual
    python3 tools/economy_sim.py --runs 50 --seed 7

The player model is deliberately plain: it collects, claps, premieres as soon as a film is
ready, buys the cheapest useful upgrade it can afford, picks the best script and cast it owns,
and spends the rest on casting. Real players are messier, so treat the output as a curve shape,
not a promise.
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

    return {
        "config": config,
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
        self.curve: dict[int, dict] = {}

    # stats
    def level(self, uid: str) -> int:
        return self.stage_count - int(self.g.c["StartingStages"]) if uid == "Stages" else self.upgrades[uid]

    def luck(self) -> float:
        c = self.g.c
        tiers = sum(1 for r in self.rewards if r.startswith("tier:"))
        return c["BaseLuck"] + c["LuckStep"] * self.level("Luck") + c["TierRewardLuck"] * tiers

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
                expected = length["base"] * power * self.genre_bonus(genre) * luck_mult
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
            self.cash -= length["cost"]
            seconds = length["seconds"]
            if not self.first_film_done:
                seconds = min(seconds, self.g.c["FirstFilmSeconds"])
                self.first_film_done = True
            self.films.append({"stage": stage, "end": self.now + seconds, "length": length, "genre": genre,
                               "cast": cast, "power": power})
            self.mark(f"First {length['name']}")

    def premiere_ready(self):
        for film in [f for f in self.films if f["end"] <= self.now]:
            self.films.remove(film)
            result = self.g.roll_result(self.rng, self.luck())
            payout = self.g.payout(film["length"]["base"], film["power"], self.g.result_mult[result],
                                   self.genre_bonus(film["genre"]))
            self.accrue()
            self.cinema.append(payout)
            self.cinema.sort(reverse=True)
            del self.cinema[int(self.g.c["CinemaCapacity"]):]
            self.fame += self.g.fame(payout)
            self.cash += payout
            self.earned_total += payout
            self.premieres += 1
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
        return self.rate() + films

    def cast(self, dt: float):
        self.cast_credit = min(self.cast_credit + self.cast_rate * dt, 3)
        # Save towards the next upgrade if it is within ~4 minutes of income.
        reserve = 0.0
        nxt = self.next_upgrade()
        if nxt is not None and nxt[1] <= self.income_per_second() * 240:
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
            self.cash -= agency["cost"]
            actor_id, variant = self.g.roll_actor(self.rng, self.luck(), int(agency["minTier"]))
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
            film = min(running, key=lambda f: f["end"])
            film["end"] = max(self.now, film["end"] - self.clap_seconds())
            running = [f for f in self.films if f["end"] > self.now]
        self.clap_credit = min(self.clap_credit, 1)

    # time
    def play(self, seconds: float, offline_after: float, step: float = 2.0):
        end = self.now + seconds
        before = self.earned_total
        self.premiere_ready()
        self.collect()
        self.offline_earned += self.earned_total - before
        last_collect = self.now
        while self.now < end:
            self.now += step
            self.played += step
            mark = int(self.played // M)
            if mark in CURVE_MINUTES and mark not in self.curve:
                self.curve[mark] = self.snapshot()
            self.clap(step)
            self.premiere_ready()
            if self.now - last_collect >= 30:
                self.collect()
                last_collect = self.now
            self.claim_rewards()
            self.buy_upgrades()
            remaining = end - self.now
            self.start_films(None if remaining > 180 else remaining + offline_after)
            self.cast(step)
        self.collect()
        self.buy_upgrades()
        self.start_films(offline_after)
        self.now = end + offline_after

    def snapshot(self) -> dict:
        return {"cash/min": self.income_per_second() * 60, "cinema/min": self.rate() * 60, "fame": self.fame, "luck": self.luck(),
                "index": len(self.index),
                "offline %": 100 * self.offline_earned / max(1, self.earned_total), "stages": self.stage_count, "premieres": self.premieres}


# --- Schedules ----------------------------------------------------------------------------------

H, M = 3600, 60
# Attention while online: a roll every ~3 s and a clapperboard tap every ~1.7 s on average (the
# player is also reading reveals, picking casts and walking to the collect pad).
CAST_RATE = 0.35
CLAP_RATE = 0.6
CURVE_MINUTES = (5, 10, 20, 30, 45, 60, 90, 120, 180, 240, 300, 330)


def schedule(kind: str) -> list[tuple[str, float, float]]:
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
    for day in range(1, 8):
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
    return "after week 1"


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


def run(tuning: dict, kind: str, runs: int, seed: int):
    game = Game(tuning)
    sched = schedule(kind)
    events: dict[str, list[float]] = {}
    snaps: dict[str, list[dict]] = {}
    last_of_day = {}
    for label, _, _ in sched:
        last_of_day[label.split()[1]] = label
    checkpoints = {"day 1 session 1": "end of first session", last_of_day["1"]: "end of day 1",
                   last_of_day["3"]: "end of day 3", last_of_day["7"]: "end of week 1"}
    for r in range(runs):
        player = Player(game, random.Random(seed + r), clap_rate=CLAP_RATE, cast_rate=CAST_RATE)
        for label, on, off in sched:
            player.play(on * M, off * M)
            if label in checkpoints:
                snaps.setdefault(checkpoints[label], []).append(player.snapshot())
        for name, at in player.events.items():
            events.setdefault(name, []).append(at)
        for mark, snap in player.curve.items():
            snaps.setdefault(f"{mark} min played", []).append(snap)
    return game, sched, events, snaps, runs


def report(kind: str, runs: int, seed: int):
    tuning = load_tuning()
    game, sched, events, snaps, runs = run(tuning, kind, runs, seed)
    print(f"# Movie Mogul economy sim: {kind} player, {runs} runs\n")
    total_played = sum(on for _, on, _ in sched)
    print(f"Schedule: {total_played / 60:.1f} h played over 7 days.\n")
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
    args = parser.parse_args()
    report(args.player, args.runs, args.seed)
