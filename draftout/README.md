# Draftout v0.20.3 — Spectator Table Prototype

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
   MultiplayerSpeedrunning is optional. Everyone should use Draftout **0.20.3 (this prototype)**.

This ZIP contains only Draftout. It does not replace game files, DLLs or other mods.
This prototype includes its source, tests and developer notes in the same Draftout folder.
These are not additional mods to install. Keep only one Draftout folder in Mods.

## Experimental spectator board

This is a separate prototype, not a replacement for your stable playtest build.
Keep your old Draftout folder somewhere outside Mods so you can roll back.
The recent Burglar header, Bungee font and coral passing arrows are included.

**Preview alone:** outside any multiplayer lobby, open **Mods → Draftout → Config →
Local spectator preview**. The example cycles through drawing, selecting and playing a hand, scoring, buying
a Joker, opening a pack and choosing the next blind. Cards move between their
positions on the table; use Restart demo to begin again.
This is a visual demonstration, not a connection test; it does not change your run.

**Watch a real match:** everyone must install this same prototype. Start a normal
four-player private Draftout Royale match. After losing all your lives, stay in the
lobby and click **Watch remaining players** on your results screen. **F9** also opens
the viewer after elimination if the button is missing. Choose a surviving player.
Their feed starts at their next shop or blind-selection screen, then buffers for
at least five seconds. A player already at either checkpoint can start sending
immediately. Survivors do not need to press a button.

The viewer now fills the screen with a game-style table: score, chips/mult,
hands/discards, money and lives on the left; Jokers/consumables at the top; played
cards in the middle; a single hand along the bottom and a deck stack to the right.
Shop and pack displays automatically take over the center area. Hover a card to
raise it and see captured values. Use Previous/Next player to change the view,
or Back to results to stop watching without leaving the lobby.

Changed boards are sampled up to four times per second. Unchanged boards send a
two-second heartbeat; large frames are limited to one per second. Each complete
frame still waits at least five seconds after receipt. Stable display IDs allow
smooth hand-to-play and shop-to-Joker movement without rebuilding the screen.
Reduced-motion settings snap cards into place. All clients need this version;
the spectator wire format changed from the first prototype.

This is a closer visual representation of the game, not full native action replay.
It does not reproduce every scoring trigger, sound, edition shader or animation;
brief events between samples can be missed. The local demo uses scripted scores.
Card values in the live view come from the watched client. Each area is capped at
24 visible entries; large hands/collections overlap to remain on the table.
No unseen draw-pile order or drafted pool is sent.

The existing host/referee continues running normally, including if the eliminated
host is watching. Spectating never starts a replacement run, plays a card, submits
a score, changes lives or activates a Joker. Final-two-player scoring is unchanged.
This does not implement reconnect, external spectators, public/ranked spectating,
or the saved-roster Nemesis bracket mode. In a two-person match there is nobody
left to watch after elimination because that match has already ended.

**Validation:** targeted automated tests passed for table layout/motion, display
IDs and selection transfer, update pacing, delayed/fragmented updates, dropped and
stale messages, eliminated-host viewing through a twelve-PvP match, native final
1v1 rules, host migration, cleanup and read-only rendering logic. These tests use
the supplied MultiplayerAPI/PvP 1.0.0 source with a simulated relay. Windows/LÖVE
pixels, official-server forwarding and real latency still require a live playtest.
See `docs/SPECTATOR_PROTOTYPE.md` for the technical scope and test checklist.

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
