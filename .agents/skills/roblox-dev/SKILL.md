---
name: roblox-dev
description: >-
  Expert guidelines, patterns, and workflows for Roblox Luau game development.
  Covers strict Luau typing, server-authoritative security, Rojo structure,
  ProfileStore persistence, BadgeService, and marketplace monetization.
---

# Roblox Luau Development Skill

This skill enforces and guides high-quality Roblox development standards within this project.

## 1. Luau & Scripting Standards
- Always prefix Luau modules with `--!strict`.
- Never trust the client:
  - All inventory, currency, rolling odds, badges, and timer grants MUST occur strictly on the server.
  - RemoteEvents and RemoteFunctions should validate parameters and pass intentions (e.g. `RollCastingCall`), never values (e.g. never pass `amount = 5000` or `outcome = "Masterpiece"`).
- Keep pure logic, odds calculations, and math in `src/shared/` without engine side-effects so they remain testable via headless tools (Lune).

## 2. Badges & Monetization
- **BadgeService**:
  - Always wrap `BadgeService:AwardBadge(userId, badgeId)` and `UserHasBadgeAsync` in `pcall` since Roblox web API calls can fail intermittently.
  - Cache awarded badges in-memory per session or in saved player data to prevent redundant calls.
- **MarketplaceService**:
  - Keep `ProcessReceipt` idempotent and strictly integrated with `ProfileStore` transaction locking.
  - Do not sell power directly without free-path progression.
  - Comply with PolicyService for paid random items (loot box regulations).

## 3. Rojo & Project Layout
- Client UI code lives in `src/client/`.
- Server logic lives in `src/server/`.
- Cross-boundary configs and types live in `src/shared/`.
