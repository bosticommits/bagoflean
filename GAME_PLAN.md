# Game Plan: Actor Life Simulator (working title)

A solo Roblox RNG game. You start as a nobody, click your way up, and roll auditions for
roles. Luck decides whether you land a background extra or a once-in-a-lifetime blockbuster.
The roles you collect fill your Index and pay you royalties. Later, each new career
(singer, streamer, athlete...) is a new world with its own RNG pool and Index.

Status: **draft, nothing built yet.** Numbers below are starting points to tune in playtests.

---

## 1. The loop

| Layer | Time scale | What the player does |
|---|---|---|
| Core action | seconds | **Rehearse** (click / tap): earn Cash, with a pop-up number and sound |
| RNG roll | seconds | **Audition**: spend Cash to roll a random Role, with a rarity reveal animation |
| Short goal | minutes | Equip your best Roles for **royalties** (Cash per second), buy upgrades |
| Collection | days | Fill the **Index**. Completing a rarity row gives permanent Luck |
| Long goal | weeks | Gain **Fame** to unlock new studios; **Comeback** (rebirth) for permanent boosts |
| Expansion | updates | New **careers**, each with a new world, new roles and a new Index page |

The twist: luck applies to every career. Your luck stat and luck boosts carry over, so
starting a new career feels like a fresh jackpot hunt rather than a grind from zero.

## 2. Currencies and stats

- **Cash**: earned by Rehearse and royalties, spent on Auditions and upgrades. Reset by Comeback.
- **Fame**: earned from every Role you land (higher rarity gives more). Unlocks studios. Never resets.
- **Luck**: a multiplier on rare odds. Sources: upgrades, Index rewards, Comeback, boosts.
- **Comeback points**: from rebirth, spent on permanent perks.

## 3. Rarity and odds (Actor career)

Luck divides the "1 in N" chance (Luck 2 makes a 1/1,000 role a 1/500 role).
The common tiers absorb the leftover chance.

| Tier | Example roles | Base chance | Royalties/sec |
|---|---|---|---|
| Extra | Crowd Extra, Passerby, Waiter #3 | 1 in 2 | 1 |
| Background | Guy at Bus Stop, Hallway Student | 1 in 5 | 3 |
| Supporting | Best Friend, Sidekick, Rival | 1 in 25 | 12 |
| Co-Star | Detective Partner, Love Interest | 1 in 150 | 60 |
| Lead | Action Hero, Space Captain | 1 in 1,000 | 400 |
| Blockbuster | Superhero, Wizard King | 1 in 10,000 | 3,000 |
| Iconic | Award-Winning Legend | 1 in 100,000 | 25,000 |

**Variants** (the index depth): any role can roll as *Shiny* (1 in 50) or *Award-Winning*
(1 in 1,000). These are separate Index slots with royalty multipliers. Version 1 has 20
base roles, which with variants makes 60 Index slots.

Odds are shown in game on the Audition screen. Roblox requires this for paid random items.

## 4. Progression

- **Upgrades** (Cash): Rehearse power, Luck, Audition speed, royalty slots (start with 3 equipped roles).
- **Studios** (Fame gates): Indie Set, then TV Studio, then Film Lot, then Hollywood Hills.
  Each one raises Audition cost and adds better roles to the pool.
- **Index rewards**: complete a tier row for +Luck. Complete the page for a title and badge.
- **Comeback** (rebirth, unlocked at a Fame level): reset Cash and roles (keep the Index)
  for permanent Cash and Luck multipliers.

## 5. Monetization (after version 1 is fun)

- Game passes: 2x Luck, Auto-Rehearse, +2 role slots, faster auditions.
- Developer products: temporary Luck boosts (e.g. "Lucky Coffee", 15 minutes), Cash packs.
- Rules: no buying specific rare roles directly, show odds always, keep it fair for free players.

## 6. Technical rules (from the Roblox skills)

- **Server decides everything**: RNG, Cash, Fame. The client only asks ("roll", "rehearse")
  and plays animations. Rate-limit Rehearse on the server.
- **Saving**: DataStore with session locking (ProfileStore) and a versioned data schema.
  Save on leave, periodically, and on server shutdown.
- **Purchases**: `ProcessReceipt` grants each purchase exactly once.
- **Project layout**: Rojo project in this repo, so every script is in Git.
- Mobile-first UI: most players are on phones. Big buttons, safe areas.

## 7. Milestones

| # | Milestone | Done when |
|---|---|---|
| M0 | Setup | Rojo project synced into Studio. Claude can see and playtest the place |
| M1 | Core click | Rehearse earns Cash on the server, HUD shows Cash, data saves and loads |
| M2 | Auditions | Roll a role with odds, reveal animation, inventory, equip 3, royalties tick |
| M3 | Index | Index screen with locked/unlocked slots, variants, tier-completion Luck rewards |
| M4 | Progression | Upgrades, Fame, 2 studios, Comeback |
| M5 | Polish | Map (film lot), sounds, VFX on rare rolls, tutorial for the first 60 seconds |
| M6 | Launch prep | Monetization, publish checklist, thumbnail and icon, soft launch |
| M7+ | Careers | Career 2 (e.g. Singer) with its own world, roles and Index page |

**Version 1 = M0 to M5.** Playtest after every milestone. If it isn't fun at M2, fix the
loop before adding more.

## 8. Open questions

- Game name
- Art style (bright cartoony "simulator" look vs. something more unique)
- Which second career comes first
- Avatar-based (your character acts in scenes) or UI-based (cards and screens)
