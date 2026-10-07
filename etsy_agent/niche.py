"""The niche the agent designs for: pickleball apparel and gifts.

Why pickleball (researched October 2026):
- SFIA's 2026 report: ~24.3M Americans played in 2025, up 22.8% year over
  year and 171.8% over three years - the fastest-growing US sport three
  years running. ~4.5M brand-new players in 2025 alone, and every new
  player is a fresh buyer of "my new obsession" merch.
- Players skew older with disposable income (retirees, empty nesters), and
  their families constantly need gift ideas - gift searches are the
  highest-intent traffic on Etsy.
- The sport has its own vocabulary (dink, kitchen, 0-0-2, erne, banger),
  so insider jokes land with players and are hard for generic sellers to
  fake.
- Clubs, leagues, and tournaments buy matching shirts in bulk.
- Designs are typography-led with simple icons (paddles, balls, nets),
  which is exactly what the agent can draw cleanly as vector art.

Everything niche-specific lives in this file. To point the agent at a
different niche, write another NicheProfile and pass it to the pipeline.
"""

from __future__ import annotations

from dataclasses import dataclass, field


@dataclass(frozen=True)
class NicheProfile:
    name: str
    summary: str
    personas: list[str]
    sub_niches: list[str]
    vocabulary: list[str]
    humor_angles: list[str]
    styles_that_sell: list[str]
    icon_library: list[str]
    occasions: list[str]
    avoid: list[str]
    # Brands, leagues, pro players and other protected names. Matched
    # case-insensitively on word boundaries against slogans, artwork text
    # and listing copy. Not a substitute for a trademark search.
    blocked_terms: list[str] = field(default_factory=list)

    def as_prompt(self) -> str:
        def bullets(items: list[str]) -> str:
            return "\n".join(f"- {item}" for item in items)

        return f"""<niche name="{self.name}">
{self.summary}

<buyer_personas>
{bullets(self.personas)}
</buyer_personas>

<sub_niches>
{bullets(self.sub_niches)}
</sub_niches>

<insider_vocabulary>
{bullets(self.vocabulary)}
</insider_vocabulary>

<humor_angles>
{bullets(self.humor_angles)}
</humor_angles>

<styles_that_sell>
{bullets(self.styles_that_sell)}
</styles_that_sell>

<icon_library>
{bullets(self.icon_library)}
</icon_library>

<occasions_calendar>
{bullets(self.occasions)}
</occasions_calendar>

<avoid>
{bullets(self.avoid)}
- Never use these protected names anywhere: {", ".join(self.blocked_terms)}
</avoid>
</niche>"""


PICKLEBALL = NicheProfile(
    name="Pickleball apparel & gifts",
    summary=(
        "Funny, insider, and giftable designs for pickleball players, sold as "
        "print-on-demand t-shirts, sweatshirts and hoodies (plus mugs/totes "
        "from the same artwork). Pickleball is the fastest-growing sport in "
        "the US (~24M players, +23% YoY). Buyers are players themselves and, "
        "very often, their spouses, kids and friends shopping for a gift."
    ),
    personas=[
        "Retiree / 55+ player who plays daily at the community center and "
        "proudly calls it their whole personality",
        "Pickleball grandma or grandpa - the gift-giver is a grandchild or "
        "adult child searching 'pickleball gift for grandpa'",
        "Competitive 30-50 year old chasing a higher rating, loves insider "
        "strategy jokes (third shot drop, resets, stacking)",
        "Brand-new player who just got hooked (4.5M new players a year) - "
        "'my new addiction' energy",
        "Couples who play together, and spouses who've 'lost' their partner "
        "to pickleball",
        "Club / league organiser ordering matching shirts for a team or "
        "tournament",
    ],
    sub_niches=[
        "Retirement & grandparent gifts",
        "Insider strategy humor (kitchen, dinks, third shot drop, erne, ATP)",
        "Couples / spouse humor",
        "Holiday & seasonal (Christmas, Mother's/Father's Day, birthdays)",
        "Pickleball + coffee / wine / beer lifestyle mashups",
        "Ex-tennis players who 'switched sides'",
        "Team, club and tournament shirts (customisable names)",
    ],
    vocabulary=[
        "dink / dinking / dinker - soft shot into the kitchen",
        "the kitchen / non-volley zone (NVZ) - you can't volley from it",
        "'0-0-2' / 'zero zero start' - how every game's score call begins",
        "third shot drop, reset, speed-up, put-away",
        "erne - jumping around the kitchen to volley; ATP - around the post",
        "banger - player who just hits hard; lob, poach, stack",
        "open play, paddle tap at the net, 'paddles up', rating chasers",
        "'Pickleball is my cardio', 'one more game'",
    ],
    humor_angles=[
        "Puns on dink (dinkin' problem, dink responsibly-style wordplay done "
        "freshly), kitchen (kitchen jokes for people who don't cook), pickle",
        "Holiday mashups (Dink the Halls, Jingle balls with pickleballs as "
        "ornaments, Thankful for dinks)",
        "Self-deprecating obsession ('One more game' every two hours, 'I "
        "came for the exercise, stayed for the drama')",
        "Retirement framing ('Retirement plan: pickleball', 'I'm retired, "
        "this is my job now')",
        "Insider-only jokes that tennis or casual players won't get - core "
        "players pay for feeling seen",
    ],
    styles_that_sell=[
        "Retro 70s sunset stripes and groovy wavy type",
        "Vintage badge / patch / circular emblem with crossed paddles",
        "Collegiate varsity block lettering (great for 'Pickleball Club' and "
        "custom team names)",
        "Big bold stacked typography - one punchline, readable from across "
        "the court",
        "Cute illustrated pickle or pickleball character with a pun",
        "Minimal line-art paddle + short phrase for an upscale look",
    ],
    icon_library=[
        "Pickleball: optic-yellow (#D9F03C) or lime circle with rows of small "
        "darker holes",
        "Paddle: rounded rectangle face with a shorter handle, often crossed "
        "in pairs",
        "Net: horizontal band with a grid/mesh pattern",
        "Court: rectangle with a centre line and the kitchen line",
        "Pickle: green elongated bean shape with bumps, optional face",
        "Sun / sunset with horizontal stripes, stars, sparkles, laurels",
    ],
    occasions=[
        "Jan: New Year resolutions, indoor season",
        "Feb: Valentine's (couples who dink together)",
        "Mar-Apr: outdoor season opener, spring tournaments",
        "May: Mother's Day (2nd Sunday), graduations, retirement season",
        "Jun: Father's Day (3rd Sunday), summer leagues",
        "Jul-Aug: summer, US national tournaments, vacations",
        "Sep-Oct: fall leagues, Halloween",
        "Nov: Thanksgiving, Black Friday, Christmas gift shopping starts",
        "Dec: Christmas & holiday gifts - the biggest Etsy sales month",
        "Year-round: birthdays (milestone 50/60/70), retirement parties",
        "List designs 6-8 weeks before an occasion so Etsy search can index "
        "and rank them in time",
    ],
    avoid=[
        "Brand logos, look-alike logos, or parodies of famous slogans or "
        "marks (e.g. a swoosh or 'Just Do It' remix) - trademark takedowns "
        "can close an Etsy shop",
        "Names or likenesses of pro players, leagues, tours, or rating "
        "systems",
        "Song lyrics, movie quotes, and TV catchphrases",
        "Generic clip-art look; tiny details that disappear when printed",
        "Mean-spirited jokes about age, gender or body - the audience is "
        "older and gift-givers buy warm humor",
    ],
    blocked_terms=[
        "Selkirk", "JOOLA", "Franklin Sports", "Paddletek", "Onix",
        "CRBN", "Gearbox", "Vatic", "Six Zero", "Babolat",
        "Diadem", "ProKennex", "Niupipo", "Nike", "Adidas",
        "Lululemon", "Skechers", "PPA", "PPA Tour", "MLP",
        "Major League Pickleball", "APP Tour", "USA Pickleball", "DUPR",
        "UTR", "USAPA", "Ben Johns", "Anna Leigh Waters", "Tyson McGuffin",
        "Anna Bright", "Federico Staksrud", "Catherine Parenteau",
        "Pickleball Kingdom", "Chicken N Pickle", "Disney", "Grinch",
        "Peanuts", "Snoopy", "Rick and Morty", "Pickle Rick",
    ],
)
