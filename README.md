# Draftout v0.19.0

Credits: **Fantom and Cjpep**.

Draft Jokers with two or four players, then play with personal Joker shop pools.
The default draft gives each player 27 Jokers. Packs pass left on rounds 1/3
and right on rounds 2/4. The host can choose 1–4 packs and 1–2 picks per turn;
the fourth pack contains 8 Jokers, for a 35-Joker roster.

## Install

1. Close Balatro. Move your old Draftout folder outside the Mods directory.
2. Extract the player ZIP's **Draftout** folder into `%AppData%\Balatro\Mods`.
   Replace the whole folder; don't nest or merge it with an older copy.
3. Install Steamodded **1.0.0-beta-1814a or later**, Lovely **0.9.0 or later**,
   MultiplayerAPI **1.0.0**, and MultiplayerPvP **1.0.0**. The supplied 1.0.0
   builds are the integration baseline; later upstream releases need retesting.
4. Remove the old Multiplayer / MultiplayerExperimental mods from active Mods.
   MultiplayerSpeedrunning is optional. Everyone should use Draftout **0.19.0**.

This ZIP contains only Draftout. It does not replace game files, DLLs or other mods.
The separate Developer ZIP is for reviewing source/tests, not another mod to install.

## Standard Draftout match

1. Create a **private PvP Royale lobby**. Get exactly two or four players in.
2. Open Draftout through **F8** or **Mods → Draftout → Config → Multiplayer PvP lobby draft**.
3. Host: **Check / reset draft**, choose settings, then **Begin draft** after all clients confirm.
4. Select Jokers from each pack and confirm. Hover cards for descriptions.
   The left roster has page arrows and Draft order / Rarity / Name / Custom sorting.
5. Once the draft is complete, close it, ready up in PvP, and let the host start.

Everyone starts with four lives. Ante 1 is normal; Ante 2 onward replaces the
boss with PvP. With 3–4 survivors, players below the final average lose a life.
With two survivors, native PvP 1v1 scoring/early finishes apply.

Shops, Buffoon packs, Judgment and Riff-Raff respect your roster. Wraith can
produce any Rare, including Showman; Soul remains an exception. Matador,
Mr. Bones, Luchador and Showman are not drafted. An extinct Gros Michel does
not return to your shop pool. In-run Collection shows your roster and supports sorting.

## Bracket play: draft once, play separate 1v1s

Pairings are manual: for example, seats 1 vs 2 and 3 vs 4, then the winners.

1. All four players complete the normal online draft above. You can stop there;
   starting a four-player Royale match is not required.
2. Each player opens **Save roster / bracket 1v1**, then **Save latest draft roster**.
   The same screen is under **Mods → Draftout → Config → Saved-roster 1v1 / bracket**.
3. **Copy roster code** is optional backup/export. **Import from clipboard** loads a code.
   Your most recently saved/imported roster also persists in Draftout's config.
4. Leave the draft lobby. Each pair creates a **private Nemesis (normal 1v1) lobby**.
5. Both players open Saved-roster 1v1 and click **Enable for this lobby**.
   Wait for **Rosters confirmed**, close the screen, ready up, and start through PvP.
6. Winners repeat steps 4–5 for the final, using the same saved roster.

Each matchup is a **fresh run with four lives**. Money, deck upgrades, acquired
Jokers and other progress do not transfer; only the drafted availability pool does.
Native 1v1 combat remains in charge. The mode validates matching draft identifiers,
different seats and non-overlapping rosters. It does not manage brackets or certify
export codes against deliberate editing. Enable it again for each new matchup.

Ordinary PvP does **not** inherit your saved roster. Both players must explicitly
enable roster mode; it is unavailable in public/ranked, Royale or larger lobbies.

## Test on your own

Open **Config → Local development draft**. Choose two or four seats, start a
fresh draft, and control each seat in turn. At completion, use a seat for a
**new normal run outside API lobbies**. **Disarm future runs** turns that local
assignment off. Local testing does not exercise online forwarding or multiplayer combat.

## Diagnostics and bug reports

Before a playtest, turn **Config → Diagnostics: On**. After a problem, use
**Copy diagnostic log** or attach these files from Windows Explorer:

`%AppData%\Balatro\draftout-diagnostics\current.log`

`%AppData%\Balatro\draftout-diagnostics\previous.log`

These are relative to LÖVE's save directory; custom installations may use a
different save location. Each file is limited to 128 KiB. The clipboard contains
the most recent 256 events. Disk writes are batched at most once per second
while running (plus explicit enable/disable flushes); a crash may lose the last
unflushed second. If disk writing fails, recent events remain available to copy.

Logs use anonymous session/run counters and seat numbers. They include draft
phase, accepted/rejected PvP actions, readiness/lives snapshots on the host,
and connection events. They exclude account IDs, names, lobby codes, seeds,
chat, Joker pools and raw packet/error contents. Nothing is uploaded automatically.
Diagnostics default to Off. Turning them off stops recording; existing files remain.

For a useful report, include your version, screenshot/crash text, ante, host,
players remaining, and what each player clicked before the problem. A host log
plus the affected player's log is especially useful for readiness/score issues.

## Validation and remaining limits

Offline tests cover draft rules, actual MPAPI action dispatch through a simulated
relay, native referee behavior, long matches, host handover, roster-mode consent,
export/import validation, diagnostics, UI ownership and packaging. Compatibility
checks use supplied Steamodded/Lovely sources; they do not execute Lovely patches.

The new roster mode and results styling still need Windows/LÖVE and official-server
playtests. Rendering, real server forwarding, recovery ordering and arbitrary mod
combinations are not established by offline tests. This remains a beta release.

See **CHANGELOG.md** for this release. The Developer bundle contains the test
suite, release builder, architecture notes and historical release notes.
