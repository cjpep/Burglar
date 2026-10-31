# Burglar 0.24.0 — release validation

Checked October 31, 2026 against the supplied MultiplayerAPI/PvP 1.0.4 sources, with Lua 5.1, mocked game rendering and a simulated relay.

- Multiplayer/open-list/custom-cube suite: 97 tests, 95 passed and two skipped. The skips cover pre-1.0.3 behavior replaced by the upstream Party API. This includes the existing long-match, final-two native 1v1, stale/duplicate report, ready-barrier and host-handover checks.
- Open-list tests cover two/four players, four-pack rosters, duplicate copy identities, host-authoritative setup, no opponent-list payloads before completion, malformed/forged view rejection, and review closing at game start or lobby teardown. The match still receives only the player's own drafted pool.
- The main-entry adapter passes 3,158 assertions with mocked game APIs. Additional Lua checks cover the local review screen, player/page navigation, vertically stacked controls, saved options and the shipped timer default.
- Duplicate and rarity-tag checks cover owned/offered copies, pending reservations, pack offers, selling, bans, Gros Michel extinction, empty Common pools, Jimbo exhaustion, generator capacity and delayed Judgment creation. Wraith, Soul and ordinary non-Burglar runs keep their scoped exceptions/behavior.
- The supplied PvP 1.0.4 Rare/Uncommon balanced-tag apply functions execute through Burglar's actual create_card wrapper. They produce the correct available rarity, or Jimbo on copy exhaustion, while retaining native shop UI/materialization and tag consumption. This targeted test passed again after replacing the Tarot fallback.

These are automated simulations, not a Windows Balatro playtest. They do not execute Lovely patching, render the actual UI, or connect to the official server. Native prevention/capacity rules still control whether a card-creation action runs. Spectator remains experimental.

The new open-list feature does not change combat scoring, native final-two 1v1 behavior, or spectator logic. Standard physically omits the spectator modules and hooks. Player ZIPs exclude tests, dependency sources and local saves; the GitHub source ZIP contains the tests and release builder.
