# Store Listing: Movie Mogul

Text and settings for the Creator Dashboard page. Paste the blocks as they are; change the
name everywhere if the final name changes. Icon and thumbnails come from the design kit.

## Name

Movie Mogul

(Alternatives from the plan: "Studio Tycoon RNG", "Hollywood RNG". Roblox search favours names
that say the genre, so "Movie Mogul RNG" is worth a test once the game has players.)

## Description

Paste this into the Description field (about 820 characters, under Roblox's 1,000 limit):

```
🎬 Run your own film studio and become a Hollywood legend!

⭐ CAST RARE ACTORS
Hold Casting Calls to discover 21 original actors, from Nervous Intern to the 1 in 150,000 Mogul's Muse. Find Shiny and Award-Winning versions too!

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

## Before going public

- Developer product and game pass IDs are pasted into `src/shared/Shop.luau` (any left at `0`
  show as "Soon" in the shop).
- The launch codes in `src/server/Codes.luau` (PREMIERE, LIGHTSCAMERA, ACTION) are posted on
  the social links.
- Social links (Roblox group, Discord or X) are added on the experience page.
