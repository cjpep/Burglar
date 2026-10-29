# Burglar 0.21.1 — release validation

Checked October 29, 2026 against the supplied MultiplayerAPI 1.0.3 and MultiplayerPvP 1.0.3 sources, using Lua 5.1 and a simulated relay. The tests dispatch actual API actions; game rendering is mocked.

- Native deck picker: host/guest button layout and permissions, deck/stake publication, balance changes, preservation of completed draft pools, pending-metadata launch blocking, and unchanged unrelated lobbies passed.
- A twelve-consecutive-PvP match reaches one winner. Final-two-player native 1v1 early finish remains intact. Eliminated-player departures, ready barriers, host handover with native outcome handlers, regular-blind failures, and Ante 1 boss-life loss passed targeted checks.
- Spectator checks passed for an eliminated host watching through twelve rounds, delayed shop/pack frames, and a viewer that cannot execute or change the watched run.
- Standard's staged release files passed the actual API draft/start handoff, twelve-round match, next-match draft reset, and all three native-picker checks against 1.0.3.
- All 33 Standard and 39 Spectator Lua files compile. Both editions pass the main-entry adapter's 3,158 assertions with a mocked game API; the spectator object exists only in Spectator.
- Three packaging checks passed: one manifest/entry point, preserved save/protocol identity and credits, spectator removal, identical shared gameplay files, reproducible archives, and SHA-256 inventories.

Standard physically omits all six spectator modules, their loader, config entry, preview button, and receive/event hooks. It is not simply Spectator with a saved setting switched off.

The API harness now loads the supplied native picker, Party/metadata helpers, pending-death helpers, and blind-result action needed by 1.0.3. Those are test-harness updates, not replacements for upstream game code.

These checks do not launch Balatro on Windows, execute Lovely's patches, exercise the official server, or establish spectator reliability under real network conditions. The updated native deck/draft button layout still needs an in-game visual check. Spectator remains experimental. This is a focused compatibility check, not a rerun of every historical test.
