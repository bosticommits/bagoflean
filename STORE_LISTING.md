# Store Listing: Hollywood RNG

Text and settings for the Creator Dashboard page. Paste the blocks as they are; change the
name everywhere if the final name changes. Icon and thumbnails come from the design kit.

## Name

Hollywood RNG

(Chosen by Bosti on 7 Oct 2026. The working title was Movie Mogul.)

## Description

Paste this into the Description field (about 860 characters, under Roblox's 1,000 limit):

```
🎬 Run your own film studio and become a Hollywood legend!

⭐ CAST RARE ACTORS
Hold Casting Calls to discover 21 original actors, from Nervous Intern to the 1 in 1,000,000 Icons like The Mogul's Muse. Find Shiny and Award-Winning versions too!

🎥 MAKE MOVIES
Pick a script, cast up to 3 stars and start filming. Your movies keep filming while you're offline!

🍿 PREMIERE NIGHT
Will it Flop, or be a MASTERPIECE? Every premiere is a box-office roll. Masterpieces get announced to the whole server.

🏆 BUILD YOUR LOT
Grow your studio with more sound stages, a bigger cinema and a trophy shelf. Your rarest star goes on your billboard for everyone to see.

🌙 AWARD NIGHT every 30 minutes: more Luck and double premiere payouts!

🎁 Daily rewards, Studio Requests and codes.

Odds for every actor are shown on the casting screen. Everything can be earned for free.
```

## Short pitch (for social posts and the group page)

```
Cast rare actors, make movies that film while you're offline, and pray your premiere is a Masterpiece. 🎬
```

## Settings

| Setting | Value | Why |
|---|---|---|
| Genre | Simulation | Closest match for tycoon and RNG games |
| Max players per server | **6** | The map has 6 lots. A 7th player would have no studio |
| Devices | Phone, Tablet, Computer | Add Console once the controller check in the launch checklist passes |
| Private servers | Off at launch | Can be added later as a paid option |
| Chat | On | Players react to server announcements |

## Age and content questionnaire

Answer honestly in the Experience Questionnaire. The parts that apply to this game:

- **Paid random items: Yes.** Casting Calls give a random actor, and Cash can be bought with
  Robux (Cash packs), and Luck can be bought (2x Luck pass, Lucky Casting). Odds are shown on
  the casting screen, and the shop hides these items in regions that restrict them.
- Violence, blood, crude humour, romance, gambling with real money, social hangouts: None,
  apart from "Horror" and "Romance" being movie genres in name only.
- Expected result: a Minimal or Mild rating, suitable for all ages.

## Price justification

Prices are set in the Creator Dashboard, not in code. The prices below are proposals to start from;
compare them with similar RNG and tycoon games before launch and adjust. Rules: odds stay visible,
no item buys a specific rare actor, and every item can be earned for free.

| Item | Type | Proposed Robux | What the player gets | Why this price |
|---|---|---|---|---|
| 2x Luck | Game pass | 399 | Double casting Luck, forever | Biggest permanent power boost, so the highest pass price. Counts as paid random items |
| Auto-Collect | Game pass | 199 | Box office cash comes to you | Comfort only; saves taps, adds no power |
| +1 Sound Stage | Game pass | 249 | Film one more movie at once | Permanent income boost of about one stage; priced below Luck |
| Faster Filming | Game pass | 149 | Every movie films 25% faster | Small boost that also shortens waits; lowest-priced power pass |
| VIP | Game pass | 99 | Gold VIP tag, chat tag, starred marquee | Cosmetic only; low price, easy first purchase |
| Lucky Casting | Product | 49 | x2 Luck for 15 minutes | Cheap trial of 2x Luck that nudges players toward the pass. Counts as paid random items |
| Skip Filming | Product | 25 | Finish one movie instantly | Impulse buy that removes one wait; offered on long timers |
| Box Office Bag | Product | 49 | 30 minutes of box office cash (5,000 Cash) | Small top-up for a player who is a few Cash short. Counts as paid random items |
| Box Office Vault | Product | 249 | 4 hours of box office cash (50,000 Cash) | Bigger bundle priced about 20 percent better per minute than the Bag. Counts as paid random items |

Check before launch: that the Vault's Cash is no more than a few hours of play at the stage it is
offered, and that nothing here lets a player skip casting, which is the core hook.

## Before going public

- Developer product and game pass IDs are pasted into `src/shared/Shop.luau` (any left at `0`
  show as "Soon" in the shop).
- The launch codes in `src/server/Codes.luau` (PREMIERE, LIGHTSCAMERA, ACTION) are posted on
  the social links.
- Social links (Roblox group, Discord or X) are added on the experience page.
