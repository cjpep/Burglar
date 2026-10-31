# Burglar 0.26.0 — validation and remaining live checks

- 114 targeted Python integration tests: 112 passed, two existing skips for inapplicable reference cases. Includes tournament, stake flags, saved-roster native duels, picker, MPAPI long matches, custom cubes and native balanced rarity tags.
- The tournament harness uses four persistent Lua clients and actual MPAPI action dispatch, the PvP native start callback shape, native 1v1 referee actions, and fresh-run start function. Separate simulated rooms reject creation while seated, preserve original rosters, and route messages only to their members. Tests cover both semifinal finish orders; the second semifinal finishing before the first even starts; four PvP life losses with the other bracket idle; end-screen waiting; stale reports; room allocation refusal; disputed rematches; and a fresh final with distinct run ID/seed.
- Sticker tests use each supported Steamodded version's actual stake-chain traversal. All eight vanilla tiers, default Off, host control, local-vs-online scope, mid-run toggle rejection and custom-stake flags pass. Card randomness, compatibility and sticker application remain native; no new independent sticker roll is added.
- The game adapter passes 3,158 mocked assertions. Duplicate copy-limit checks and results-definition checks pass. All runtime Lua parses. All six bundled cubes match allowed Joker IDs, and release archives/checksums are checked.

These are simulations and structural checks, not a Windows rendering or live-server test. Check the results overlay at your resolution and run the complete four-player bracket before marking the release stable. Both semifinal participants must return to lobby before disconnecting. The original room is briefly listed as spectatable only after its match has finished, providing a server-visible reunion marker; it is disabled again before the final. Existing 0.25.0 tournaments must be restarted after updating.

# Burglar 0.25.0 — tournament playtest validation

A simulated private-room service routes four persistent Lua clients through the 1.0.4 API action dispatcher. Two semifinal winners meet in a third native match with distinct run IDs and seeds, four lives, and their original roster/copy-limit fields only. PvP's actual lobby start function requests a fresh run without save data. Additional cases cover host changes, contested results and replay, stale results, nonparticipant reports, a two-player final with no waiting players, room refusal and rejection of a two-seat bracket. Existing saved-roster native combat, four-player PvP and picker checks were also run.

The server-side room allocator, socket transitions, end screen clicks and Balatro game's renderer are simulated. These checks are not a live server playtest. Test the four-person flow on Windows before promoting this build to a stable release.

# Burglar 0.24.0 — release validation

Checked October 31, 2026 against the supplied MultiplayerAPI/PvP 1.0.4 sources, with Lua 5.1, mocked game rendering and a simulated relay.

- Multiplayer/open-list/custom-cube suite: 97 tests, 95 passed and two skipped. The skips cover pre-1.0.3 behavior replaced by the upstream Party API. This includes the existing long-match, final-two native 1v1, stale/duplicate report, ready-barrier and host-handover checks.
- Open-list tests cover two/four players, four-pack rosters, duplicate copy identities, host-authoritative setup, no opponent-list payloads before completion, malformed/forged view rejection, and review closing at game start or lobby teardown. The match still receives only the player's own drafted pool.
- The main-entry adapter passes 3,158 assertions with mocked game APIs. Additional Lua checks cover the local review screen, player/page navigation, vertically stacked controls, saved options and the shipped timer default.
- Duplicate and rarity-tag checks cover owned/offered copies, pending reservations, pack offers, selling, bans, Gros Michel extinction, empty Common pools, Jimbo exhaustion, generator capacity and delayed Judgment creation. Wraith, Soul and ordinary non-Burglar runs keep their scoped exceptions/behavior.
- The supplied PvP 1.0.4 Rare/Uncommon balanced-tag apply functions execute through Burglar's actual create_card wrapper. They produce the correct available rarity, or Jimbo on copy exhaustion, while retaining native shop UI/materialization and tag consumption. This targeted test passed again after replacing the Tarot fallback.

These are automated simulations, not a Windows Balatro playtest. They do not execute Lovely patching, render the actual UI, or connect to the official server. Native prevention/capacity rules still control whether a card-creation action runs. Spectator remains experimental.

The new open-list feature does not change combat scoring, native final-two 1v1 behavior, or spectator logic. Standard physically omits the spectator modules and hooks. Player ZIPs exclude tests, dependency sources and local saves; the GitHub source ZIP contains the tests and release builder.
