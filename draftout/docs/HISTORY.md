# Draftout v0.18.3 — MultiplayerAPI / PvP 1.0.0

Credits: **Fantom and Cjpep**.

Two or four players each draft three packs of nine random Jokers, picking one
per turn by default. Each player finishes with 27: two players draft 54 unique
types (87 sit out); four players draft 108 (33 sit out). Matador, Mr. Bones, Luchador and Showman stay excluded.
Showman is Rare during Draftout and can be found through Wraith without
entering your drafted shop pool.
The host can choose one or two picks per turn and one to four packs per
player before starting. Packs pass after everyone confirms: left for packs 1/3,
right for packs 2/4, keeping that direction throughout each pack. After the draft,
play private PvP with personal Joker shop pools: average scoring at 3-4 survivors,
then the upstream mod's native 1v1 rules for the final two. Judgment
and Riff-Raff also respect those pools. A solo hotseat draft remains available.

This build targets the three 1.0.0 archives supplied by the user. It replaces the
Experimental MP 0.11.4 adapter; it does not bundle or edit any multiplayer mod.

**Validation:** Lua 5.1 rules and mocked game tests pass. Eighty-five integration tests
use the uploaded MPAPI lobby factory, ActionType registry, parameter validation,
message dispatch, startup callbacks, and built-in start flow, plus PvP's actual
start-match function, referee, numeric-score parser and native enemy-score relay.
A simulated Nakama relay connects two or four independent Lua clients. HUD widgets and
server storage/forwarding remain mocked. Recovery tests run Draftout's scoped
checkpoint writer, the upstream metadata mirror and actual host-change events.
One test also runs native life/end/elimination/winner handlers; result negotiation
and rendering remain mocked. Windows/LÖVE rendering, real official-server forwarding, and a complete
live Royale match have NOT been tested here. Treat this as the 1.0 integration prototype.

## Install on Windows

1. Close Balatro. Move the old **Experimental MP** and any old **Multiplayer**
   folders outside the active Mods folder. Preserve them elsewhere if desired.
   Replace the existing Draftout folder with the one from this ZIP.
2. Install the supplied **MultiplayerAPI 1.0.0** and **MultiplayerPvP 1.0.0** in
   separate mod folders. Speedrunning is optional and may coexist with them.
   Do not extract both packages into the same folder: each has its own core.lua.
3. Check the files sit directly inside one mod folder each. A standard Mods path
   is `%AppData%/Balatro/Mods`; a launcher can use a different profile path.

| Folder | Files directly inside it |
|---|---|
| `Mods/Draftout` | `Draftout.json`, `main.lua`, `draftout/` |
| `Mods/MultiplayerAPI` | `MultiplayerAPI.json`, `core.lua`, `api/` |
| `Mods/MultiplayerPvP` | `MultiplayerPvP.json`, `core.lua`, `pvp_api/` |
| Optional `Mods/MultiplayerSpeedrun` | `BalatroSpeedrunning.json`, `core.lua` |

Minimum supported dependencies: **Steamodded 1.0.0~BETA-1814a**, **Lovely 0.9.0**,
and **Balatro 1.0.1o**, with **MultiplayerAPI 1.0.0+ / MultiplayerPvP 1.0.0+**.
Newer Steamodded/Lovely releases still satisfy the minimums. The loader permits newer API/PvP releases; integration tests use the supplied
1.0.0 sources because the adapter uses internal integration points.

**Before installing beta-1814a:** its upstream release warns that it can wipe stake
progress. Back up `%AppData%/Balatro` and use a new profile before installing it.
See https://github.com/Steamodded/smods/releases/tag/1.0.0-beta-1814a.
This is an upstream save issue; Draftout does not fix it.

On Windows, Lovely 0.9.0 uses `version.dll`; 0.10.0 uses `winmm.dll`. If downgrading,
remove the Lovely 0.10 `winmm.dll` from the **Balatro game directory only**, then
install 0.9's `version.dll` there. Do not leave both Lovely loaders installed or
change Windows system DLLs. No loader or upstream mod is bundled in this ZIP.

Launch through **Steam**. API startup/registration requires Steam to be available.
The Mods screen should show Draftout **0.18.3**, MultiplayerAPI **1.0.0**, and
MultiplayerPvP **1.0.0**. Experimental MP is no longer a dependency.

## First test without other players

1. Open **Mods → Draftout → Config → Local development draft**.
2. Set **Local draft: 2 players** or **4 players**, then choose **Start fresh draft**.
   Packs open automatically. This selector affects local testing only; online
   player count comes from the lobby.
3. Hover the Joker art for native descriptions. Select the configured number and **Confirm selection**.
   You control every selected seat; the next seat appears automatically after confirming.
4. **More → New draft** replaces the unfinished draft and freshly
   shuffles every pack. **Resume saved draft** preserves existing packs/picks.
5. The left **Joker Roster** shows your confirmed picks. Use the page arrows
   to browse. Click **Sort** to cycle Draft order / Rarity / Name / Custom. Rarity
   puts Rare first. Selecting two Jokers swaps them and selects Custom; switching
   sorts preserves that custom order for this draft. Player labels show
   choosing/confirmed/disconnected status and the number of completed seats.
6. At completion choose a seat, close the menu, and start a **new normal run**
   outside all API lobbies. Check shop rolls, Judgment, and Riff-Raff.
7. **Disarm future runs** restores normal pools for subsequent new normal runs.

This verifies the local UI/rules only. A local armed pool is deliberately not
applied to unrelated PvP, Speedrunning, or API practice runs. Continuing an existing
Balatro save retains that save's original pool.

## Online private two- or four-player Battle Royale

Everyone must install the same Draftout/API/PvP versions and use matching content.

1. In the new multiplayer menu choose **PvP → Create Lobby → Battle Royale**.
   Have exactly two or four players total, without spectators. Player count
   is detected automatically when the host checks the draft. For the first test,
   select the **Vanilla** ruleset in Lobby Options before checking the draft.
   The host can click the purple **Change deck** panel and select any of the 15
   standard Balatro decks for everyone. This works even with only the host in
   the lobby, and remains available until the match starts. Guests see the
   shared choice. Wait for the deck name to replace **Syncing deck...** before
   starting. Changing the deck keeps all existing Joker draft picks.
2. Each player presses **F8**, or uses **Mods → Draftout → Config → Multiplayer
   PvP lobby draft**. This is a private Royale feature, not a ranked queue.
3. The host clicks **Check / reset draft**. The host can set **Pick timer** here
   before beginning (Off/Scaling/30/45/60/90 seconds). Wait for **2/2** or **4/4 clients confirmed** and
   at least two seconds, then click **Begin draft**. No packs are sent until this
   catalog/private-routing check passes. If it stalls, capture the displayed
   message; the live server relay is not verified by the offline tests.
4. Select one Joker (or two if the host selected two picks) from your current pack and **Confirm selection**.
   Wait for the other players, then pick from the passed pack. The next round
   opens only after every current pack is empty. A final singleton needs one pick.
5. After completion, every personal pool and its release are acknowledged.
   Close Draftout, use PvP's normal **Ready** control, and let the host click
   **Start** (or **Start Royale match** inside Draftout after everyone is ready).
6. PvP owns the match seed, readiness, life updates, eliminations and victory.
   Draftout supplies personal pools and replaces Royale's scoring cutoff with
   average scoring with 3-4 survivors. With two players, native 1v1 scoring
   applies from the first PvP. Both players start with 4 lives; Ante 1 is normal,
   and Ante 2 onward is Small Blind, Big Blind, then PvP.
   The next new match triggers a fresh draft and reshuffles all packs.

During the draft, **More → Resync pack** asks the host to resend the current
state if the display seems stuck. It does not reroll or change your pack. Only
the host sees **More → Reset draft**. Your picks and the current timer survive
opening More, resyncing and viewing Full roster.

During the run, open **Collection → Jokers** to inspect your drafted pool. Use
**Sort roster** for Collection order, Draft order, Name or Rarity. The default is
Collection order; Rarity puts Rare first. Undrafted Wraith/Soul acquisitions do
not enter this browser or the shop pool.

Once the **run has started**, the original host may leave or disconnect. The
API elects a new host, which restores the latest server-held checkpoint and
continues the match. A departing host forfeits any remaining lives; nobody else
receives extra lives. Scores, remaining hands, drafted shop pools and the final
recap survive the transfer. The final two still use native 1v1 scoring. No manual
transfer button or developer mode is needed. Allow the server to announce the
new host; a temporary disconnect may take time to trigger that announcement.
Before the run starts, a host change requires two or four connected players and
a draft reset. In a two-player match, either player leaving forfeits and awards
the remaining player the win; host recovery still preserves the recap.

The native flow uses MPAPI's existing server connection. It does not require
Python or the separate development draft server. Public queues, ranked, other PvP
modes, and Speedrunning starts pass through without the native Draftout gate.
Private Royale is gated by default; developers can set `native_draft=false` in
persisted Draftout config to disable that integration.

## Draft rules and limits

- Two or four seats. With two, packs pass back and forth between the two players.
  With four, packs 1 and 3 pass left: 1 -> 2 -> 3 -> 4 -> 1.
  Packs 2 and 4 pass right: 4 -> 3 -> 2 -> 1 -> 4. Direction changes only
  when a new set of packs opens. Default: three rounds, with one 9-Joker pack per player each round.
  The optional fourth round contains 8 Jokers per pack.
- Shuffle all 141 eligible vanilla non-Legendary types, then deal 54 with two
  players or 108 with four.
  Each type is unique within the draft; every player finishes with exactly 27.
  The remaining 87 or 33 are unavailable in drafted shop/Buffoon/Judgment/Riff-Raff
  pools for every player. Matador, Mr. Bones, Luchador and Showman never enter the catalog.
- Before starting, the host can choose 1 or 2 picks per turn and 1, 2, 3 or 4 packs
  per player. Pack-count alternatives give 9 or 18 Jokers each; three is the
  default for 27. Four packs use 9/9/9/8 cards per player, giving 35 types each
  (70 total with two players, 140 with four), leaving 71 or one eligible type out. There are no rarity slots.
- Two-pick mode ends each 9-card pack with a single pick. One-pick mode returns
  the ninth and final card to the pack's original owner after two full circles.
- Every submission is atomic. Off-pack, repeated, stale, duplicate, undersized
  or oversized selections cannot partially mutate the draft.
- A new local or native draft uses a fresh random seed plus a persisted counter.
  Refreshes/passing preserve the current draft. Explicit `DRAFTOUT.start(seed)`
  remains a deterministic developer entry point.
- Previews are native Card objects, not purchased/owned Jokers. Collection locks
  do not hide their art/descriptions. Pending selections lock during submission
  and survive unrelated peer confirmations without rebuilding the hovered card.
- Drafting changes availability, not owned Jokers or the playing-card deck.
  Shops use drafted types; missing rarity buckets redistribute. Banned keys in
  the run remain excluded. Exhaustion falls back to drafted duplicates.
- Ordinary, Jumbo, and Mega Buffoon packs generate only types from the run's
  drafted pool, with no Legendary replacement. Forced off-pool pack keys are
  replaced too. Judgment uses drafted types. Riff-Raff uses drafted Commons, or
  generates nothing if there are none.
- **Wraith is an explicit exception:** it can generate any otherwise eligible
  Rare Joker, including an undrafted one. **The Soul remains unchanged** and can
  grant an undrafted Legendary. Other generators remain outside these restrictions.
- Showman is Rare during Draftout and joins Wraith's native eligible Rare pool.
  It is excluded from drafting and drafted shops/Buffoon/Judgment/Riff-Raff
  generation. Wraith does not add it to the roster. Its original rarity/pool
  membership restores outside Draftout; native unlocks, bans and weighting still
  govern whether Wraith can generate it.
- Socket reconnects can refresh the current pack while the same in-memory lobby
  and host remain. An away player's unfinished turn waits. Host changes, roster
  replacements, or ruleset changes invalidate the draft and require a reset.
- During an active match, the elected host restores scores/lives, ready state,
  settled-round fences and committed outcomes from lobby metadata. An invalid
  or missing checkpoint pauses recovery instead of inventing lives/scores.
  Restarting every remaining app or recovering an unfinished draft is unsupported.
  Run saves retain their own pool through `G.GAME.draftout_pool`.
- The host holds every pack in memory. This is a host-authoritative prototype,
  not a trusted-server/anti-cheat implementation. Draft packets contain only
  each recipient's own current pack and drafted list. During the run, recovery
  metadata also contains a compact backup of all rosters/pick order. The normal
  recap UI remains locked until match end, but client mods/debuggers can inspect
  that backup. Handshake checks identities and the
  protocol and combat rules, not full mod/game build hashes.

## v0.18.3 — roster sizing and alignment

- Widened the roster panel by about 28%, preserving its distinct background and shape.
- Enlarged roster Jokers by 25%, retaining three columns and existing pages.
- Top-aligned the roster and draft panels inside their stable transparent holders.
- Increased roster padding and label sizes; retained sorting and subtle empty slots.

## v0.18.2 — roster clarity

- Preserve the left roster's distinct background, frame, card size and page sizes.
- Empty roster slots use transparent interiors with faint teal outlines.
- Replace the extra move-arrow row with one labelled Sort control: Draft order,
  Rarity (highest first), Name (localized), and Custom. Click to cycle modes.
- Swapping two cards selects Custom. Custom order survives other sort modes;
  new picks append there or sort into the active automatic order. Display-only
  sorting never edits draft ownership, pick history or shop pools.
- Heading text is quieter: pale slate on the main title and muted mint on the
  roster. Gold stays on selection accents and the enabled Confirm button.
- Existing two/four-player gameplay and rules handshake 16 are unchanged.

## v0.18.1 — compact draft panels and selected-card shadows

- The title background fits its text. Timer Off removes its empty row; timed,
  paused and zero-second countdowns remain visible. Local clocks initialize
  before building the header so the first timed pack shows its countdown.
- Tighter padding around player status and confirmation counts. Status and
  card-panel backgrounds now use sibling rows for aligned edges and spacing.
- Selected draft previews draw a raised native sprite shadow immediately before
  their artwork, including card-only/focused draw paths. Deselecting restores
  normal shadow drawing. Respects Graphics > Shadows and native shadow exclusions.
- Card dimensions, selection lift, gameplay and two/four-player rules are unchanged.
- Verified offline against the SMODS native shadow step; Windows/GPU rendering
  and final panel alignment still need an in-game visual check.

## v0.18.0 — two-player drafts

- Private Royale lobbies accept exactly two or four players. Online seat count is
  fixed at the lobby check; adding/removing someone before launch requires a reset.
- Two players draft 27 unique Jokers each by default; only those 54 types enter
  their exclusive pools. Optional fourth packs give 35 each. Both pick settings
  and all pack-count options work with either lobby size.
- Two-player matches use the unchanged native PvP 1v1 resolver, including ties
  and early finishes, from the first PvP. Four lives, normal Ante 1, PvP at Ante 2.
- Added a local 2/4-seat selector. Readiness, passing, timers, completion, pool
  exports, recap tabs and host-recovery recaps use the actual seat count.
- Rules handshake 16 requires everyone to update. Protocol 4 and saved draft
  schema 6 remain; older four-seat local drafts default to four seats.
- Offline tests cover two-client draft options, timeouts, readiness retries,
  stale/duplicate reports, Ante 1 losses, departures and a 57-PvP match through
  one winner. Official-server and Windows rendering still need playtesting.

## v0.17.5 — lobby logo sizing

- Enlarged the centered lobby logo from 6.2 to 8.5 UI units and lowered its
  top offset from 0.85 to 1.15. Aspect ratio is preserved.
- Other lobby controls and gameplay are unchanged. Placement needs an in-game
  visual check; this release was syntax-checked offline.

## v0.17.4 — packaging and draft UI fixes

- Removed an embedded older installation that could compete with the real mod
  entry point. One manifest and one main.lua remain.
- Restored the visible pick countdown below the draft title, including warning
  colours and paused state. Draft deadlines and automatic picks are unchanged.
- Roster pages now match the selected draft size: 9; 15+3; 15+12; or 15+12+8.
- The Lua runner discovers every *_spec.lua file, including UI and pack-passing
  checks. Added regressions for countdown presence, roster navigation and package
  structure. Preserves the uploaded Burglar art, selection caret and split layout.
- No changes to combat, host handover, pool rules or native final-two 1v1 scoring.

**Upgrading from the uploaded UI build:** close Balatro, move the entire old
`%AppData%/Balatro/Mods/Draftout` folder to a backup OUTSIDE the Mods folder, then
extract this ZIP into Mods. Do not merely overwrite: that leaves embedded old
files in place. Keep the separate `Mods/config/Draftout.jkr` settings file.
The final layout must be `Mods/Draftout/main.lua` and `Mods/Draftout/Draftout.json`.

## v0.17.3 — traveling border highlight

- Thin teal outline around the shared Draftout panel, with a short lavender
  highlight and fading trail traveling clockwise once every seven seconds.
- Stepped corners follow the pixel-style frame. Geometry adapts to panel size;
  the animation phase persists across pack passes and menu content updates.
- Reduced motion or Pack effects Off leaves a static outline. Uses real time
  while menus are paused and draws only on the visible Draftout overlay.
- Instance-only draw hook restores graphics state and does not touch gameplay.
  Geometry/state tests pass; Windows/LÖVE appearance needs live verification.
- Rules handshake remains 15.

## v0.17.2 — unified draft backdrop and clearer header

- One shared slate-teal backdrop contains the header, draft cards, roster tray
  and footer, with consistent padding. Removed the separate roster-box fill.
- Centered, larger lavender title; larger player/readiness text and pale-blue
  passing information. The timer gets its own centered row so a disabled timer
  cannot shift the title to the left.
- Presentation-only update; rules handshake remains 15.

## v0.17.1 — softer frames and PvP start recovery

- Thinner slate-teal frame and softer shadow across Draftout screens; the roster
  tray uses matching teal. Removed the redundant Draft created message.
- Departures recheck the PvP ready barrier without clearing survivors' choices.
  This fixes a reproduced stall when everyone remaining was ready but the
  departing player was still counted as alive by the referee.
- Pending Ready retries every two seconds until start, unready, elimination or
  a run/ante change. An already-open round resends its original start event;
  stable event IDs prevent peers from entering twice or resetting their hands.
  The start event is included in host-handover checkpoints.
- Final-two scoring continues to use the unchanged native 1v1 resolver.
- Rules handshake 15: everyone should update and use a fresh lobby.

Offline tests cover zero-life departures, eliminated-host handover, readiness
barriers and deliberately dropped ready/start actions. Clean zero-life departure
alone did not reproduce the reported live hang; these fixes address demonstrated
barrier/recovery gaps, but confirmation of that exact symptom needs live testing.

## v0.17.0 — cleaner draft screen, Collection sorting and Ante 1 life fix

- A compact header holds pack/pick progress and the countdown; the smaller
  seating strip keeps names, readiness and receiving/passing direction.
- Larger Joker previews, with lifted selection and native shadows. Removed the
  repeated instructions and SELECTED text under every chosen card.
- One footer holds Back, More, the selection count and the purple Confirm button.
  The team tray groups its count, sort, page controls and Full roster access.
- Resync pack lives under More. It requests the host's existing snapshot, never
  rerolls a pack. Host-only reset lives there during a draft; local tests have
  More → New draft. Automatic updates and reconnect refreshes remain enabled.
- Errors still appear when needed; previous match recap and routine status lines
  no longer compete with the active draft. The countdown stays visible while
  waiting for other picks and while viewing your full roster.
- During a Draftout run, Collection → Jokers adds Sort roster: Collection order,
  Draft order, Name and Rarity (Rare first). Changing it starts on page 1 and
  retains that order when reopening the same run's roster. It never changes
  saved roster order, unlocks, art discovery, shop pools or other collections.
- Fixed ordinary Ante 1 failures being ignored after native PvP's setAnte(0)
  startup report. The referee keeps Ante 1 as the first playable ante; failing
  its Boss (or Small/Big) costs one life. Duplicate failures remain fenced.
- Native final-two 1v1 scoring is unchanged. Core schema 6 / packet protocol 4;
  rules handshake 14 requires everyone to update before starting a fresh lobby.

Offline checks cover the real PvP failed-score hook and API report route,
Collection's native builder/pagination, pending draft choices and timer deadlines,
long PvP matches, stale/duplicate messages and host handover. Windows/LÖVE
rendering and official-server play still require live playtesting.

## v0.16.0 — undrafted Rare Showman

- Removed Showman from the draft and drafted shop/generation pools.
- Showman is Rare during Draftout and becomes an ordinary eligible Wraith roll,
  without a forced drop or special chance. Wraith uses the native picker.
- Both native and SMODS rarity registries update during the run. The original
  rarity and pool positions restore outside Draftout; other entries remain.
- There are now 141 draftable types: three packs still give 27 each, with 33
  left out. Four packs still give 35 each, with one eligible type left out.
- Everyone must update and start a fresh lobby/draft. Core schema is 6, native
  rules handshake 13, packet protocol 4. Continued saves keep their own roster;
  newly generated drafted offers exclude Showman even in an older run.

All 105 Python tests pass, including 72 API simulations and six Showman checks.
Those exercise native Wraith-pool eligibility, SMODS culling, rarity restoration,
shared registries and other entries' preservation. The Showman checks also pass
against the newer SMODS reference. Core/clock/scoring/adapter checks pass;
live playtesting remains necessary.

## v0.15.4 — roster Collection art (historical)

Fixed playing-card art appearing over each Joker in the in-run roster Collection.
Refreshing the unlocked Joker preview now rebuilds only its center sprite;
passing the Collection's empty base table as a card front was creating the extra
default playing-card face. The fix also applies when changing Collection pages.
Discovery/unlock progress, drafted pools and gameplay are unchanged.

Seven collection checks pass against both beta-1814a and 26.1002.0, including a
regression using the actual upstream sprite builder with mocked graphics. The
old version reproduces the extra front sprite under that check. In-game rendering
still needs a visual check.

## v0.15.3 — Gros Michel extinction (historical)

When Gros Michel dies, its native `gros_michel_extinct` run flag now excludes it
from drafted shop rolls, forced picks and duplicate fallback. The same shared
picker also prevents it returning through Buffoon packs, Judgment or Riff-Raff;
Riff-Raff skips generation if no other drafted Common remains. Selling alone
does not mark it extinct. The native death chance is unchanged. No Cavendish is
added to a roster, and the original draft/recap history remains intact.

The flag is local to the player's saved run, so continuing preserves extinction
and a new run starts fresh. No new networking, draft schema or dependency rule
is needed. Regression checks cover generation routes, Showman/fallback and saved
versus new-run state. Live visual/gameplay testing remains necessary.

## v0.15.2 — draft card shadows (historical)

Selectable draft packs now include the native card shadow draw pass, so raised
selections and hovered cards have their normal shadow. Balatro's graphics shadow
setting is respected. Read-only roster/recap galleries keep their existing flat
previews. No draft, combat, protocol or dependency changes.

## v0.15.1 — remove the standalone development server (historical)

Removed the standalone server draft button, connection screen, socket worker,
Python draft server, launcher and dedicated setup documentation/tests. Old
standalone connection settings and armed test pools are retired on startup.
The local four-seat development draft and normal MultiplayerAPI/PvP lobby draft
remain available. Continued run saves keep their original Joker pool. No draft,
scoring, protocol or dependency rules changed; multiplayer requirements stay
`>=1.0.0` for both API and PvP.

Replace the old Draftout folder with this one so retired server files are removed.
98 Python tests pass, including all 72 multiplayer API integration simulations,
plus core/clock/scoring and mocked game-adapter checks. Live-server playtesting
remains necessary.

## v0.15.0 — alternating pack direction (historical)

- Packs 1/3 pass left; packs 2/4 pass right. Every pick within that pack keeps
  the same direction. This changes who feeds you between packs.
- Seating arrows and receiving/passing names follow the current pack direction.
- Solo, native online and optional standalone drafts use the same rule. Recap
  pick origins and host-handover recovery follow reverse-passed packs too.
- Fixed lobby-check offer retries to use the current rules version.
- Draft pools, pack sizes, timer policy, PvP rules and dependencies are unchanged.

Install **0.15.0 on everyone** and start a fresh lobby/draft. Old configured
drafts are cleared and old standalone pools disarmed; existing in-progress run
saves retain their original pool. Core draft schema is **5**, native rules
handshake **12**, native packet protocol **4**, standalone protocol **8**.
The settings migration marker remains 6, preserving current pack/pick settings.

All 104 Python tests pass, including 72 native API integration simulations, plus
the pure core/clock/scoring and mocked adapter assertions. New regressions track
every pack origin across all four rounds and both pick counts, seating arrows,
recovered recap histories and a dropped lobby-check offer. Live rendering/server
behavior still needs playtesting.

## v0.14.0 — host handover during matches (historical)

- An active match continues after its host leaves or disconnects, once the API
  elects a successor. That host forfeits; surviving lives and scores do not reset.
- Native referee records and Draftout's ready/round/report fences are committed
  together before authoritative results are sent. Stable outcome IDs let the
  successor replay a committed result without applying the same end/loss twice.
- Unacknowledged reports are retried to the new host. Partial ready barriers,
  normal-blind failures, multiple host changes, and an eliminated referee are
  covered by offline regressions. A compact recovery backup preserves all four
  rosters and pick order for the post-match recap.
- The native final-two resolver is unchanged, including early finishes and ties.
- All clients must install **0.14.0** and start a fresh lobby/draft. Rules handshake
  is **11**; packet protocol 4, schema 4, standalone protocol 7 and minimum
  Lovely/Steamodded/API versions remain unchanged.

Seventy offline API tests pass, including the existing 12-PvP, 50-tie and
randomized full matches plus host departures during play and between rounds.
Real server election/metadata ordering, disconnect timing and Windows visuals
still need live playtesting. Handover before the run and app-restart recovery
of an unfinished draft are outside this change.

## v0.13.0 — repeated-round safety, native final 1v1 (historical)

Fixed a reproduced lifecycle bug: another final-score report could emit a second
round-end, and after newRound cleared the life blocker it could take another
life. A Draftout PvP now resolves once per ante and stays closed until the next
ante's ready barrier. Late/duplicate score, ready and outcome actions are fenced
by session/run, ante and sequence tags on the existing multiplayer API actions.
Ordinary-blind initialization reports cannot re-resolve an old PvP.

**Scoring:** at 3-4 survivors, strictly below the final lobby mean loses one life,
after everyone finishes. At 2 survivors, Draftout calls the supplied PvP mod's
**unchanged `referee_resolve_2p_round`**. Its native early-finish and tie rules are
preserved. The HUD, opponent score and timer eligibility use native 1v1 behavior;
no mean is computed for that duel. This also applies when eliminated spectators
remain in the lobby. Life counts do not refill during either transition.

The regression suite now uses the actual API action instances/validation/relay,
PvP net router and report handlers, instead of manually resetting referee fields
between simulated rounds. It covers a 12-PvP match with progressive eliminations,
a native final duel and one winner/recap; 50 consecutive ties; five randomized
complete matches against an exact integer life model; stale reports after
newRound/new ante/reseed; and native 1v1 early finishes with two or four people
still in the lobby. The native 1v1 resolver's function identity is asserted
unchanged. These are offline simulations, not real Windows/official-server runs.

**Install v0.13.0 on all clients and start a fresh lobby/draft.** Native rules
handshake is 10; packet protocol 4, draft schema 4 and standalone protocol 7 stay
unchanged. Dependency minimums, draft pools, pack UI and generator exceptions
are unchanged. Host migration/restarting the host during an active match remain
unsupported; soft reconnect and live latency still need real playtesting.

## v0.12.1 — uninterrupted picks (historical)

Removed the after-pick card recap and its presentation delay. Local hotseat
advances straight to the next seat. Online confirmations immediately update the
own-team tray, with a compact waiting status while other players finish. The
next passed pack appears as soon as everyone confirms. Sorting/paging the tray
remains available while waiting. The brief confirmation sound, new-pack opening
animation and complete post-match recap are retained. Draft/network rules,
saved-draft format, dependencies and run pools are unchanged from v0.12.0.

## v0.12.0 — draft UI and post-match recap

- Packs pass **left on every pick in every round**. The seating/readiness strip
  identifies you, the previous player and the next player by display name.
- Nine-card selections use 5+4 rows; eight-card selections use 4+4. Selection
  cards are larger. Smaller packs balance across at most two rows.
- A compact side tray shows six of your own drafted Jokers per page. Its button
  cycles Recent, Rarity and Draft order. The full My Team gallery remains.
  Sorting/paging does not change tentative picks, deadlines or roster contents.
- Countdown text turns amber at 10 seconds and red at 5. A single optional native
  sound plays at five seconds or below, per pick; it does not repeat on refresh.
  Paused and submitted picks do not sound. **Timer sound** in Config mutes the
  cue independently of pack effects; visual warnings remain enabled.
- After the server reports the entire match ended, **Last match recap** appears
  in F8's draft screen and Mods -> Draftout -> Config. Review all four rosters,
  undrafted types and pick-order labels (`pick number | pack.turn`) with native
  hover descriptions. Only the most recent completed online recap is saved.
  Eliminating one player does not reveal the recap early.
- Recap transfers use bounded seat packets and retry missed parts while the same
  lobby and host remain connected. The recap survives normal draft teardown;
  active draft snapshots never include peers' pools or timelines.
- Finish a **Local development draft**, then click **Preview draft recap** to
  inspect the gallery solo. This preview does not replace your saved online recap.

Core draft schema is 4, native rules handshake 9 and standalone protocol 7. Old
local draft configurations are cleared and old standalone pools disarmed; run
saves retain their original pool. Everyone must update and start a fresh draft.
The optional standalone server supports the draft UI/timers but does not referee
matches or distribute post-match recaps. Host migration/app-restart recovery of
an unfinished match remains unsupported. Rendering still requires live testing.

## v0.11.0 — scaling pick timer (historical)

Pick timer now includes **Scaling: 5s per Joker**, immediately after Off. Each
pick gets five seconds per card remaining when that turn starts. Single-pick
nine-card packs run 45/40/35/30/25/20/15/10/5 seconds; two-pick packs run
45/35/25/15/5. New packs reset to 45, or 40 for the eight-card fourth round.

The policy is captured at draft creation and only resolves a new duration after
all players finish the current pick. Early confirmations, refreshes and My Team
do not reset or shorten that turn. Disconnects pause remaining online time.
At expiry, tentative choices are preserved and missing slots are auto-picked.
Off remains the default; fixed 30/45/60/90 timers are still available. Select
Scaling before beginning the draft. Native rules handshake is 8; standalone
protocol is 6. All players/server must update and start a fresh online draft.

## v0.10.1 — optional fourth pack (historical)

The host pack-count control now cycles through 1, 2, 3 and 4. Four-pack drafts
use 9/9/9/8 cards per player: 140 unique types dealt, 35 per team, two left out.
Both one- and two-pick modes support the smaller last round. Three packs remains
the default. Settings labels and all network/completion checks use the actual
roster size. Native rules handshake is 7; standalone protocol is 5. All players
must update together and start a fresh online draft. Dependency minimums and
Joker exclusions are unchanged.

## v0.10.0 — nine-card packs and partial catalog drafts (historical)

Default settings now deal three 9-card packs per player with one pick per turn.
That is 12 packs total, 108 unique Jokers drafted, 27 per player and 34 eligible
Jokers left out. Changing the seed changes the omitted types as well as packs.
The pre-draft controls allow 1/2 picks and 1/2/3 packs per player. Settings lock
for the active draft; clients and auto-picks use the host's transmitted rules.
There are 108 submissions in default mode, or 60 with two picks per turn.

The native rules handshake is 6; standalone protocol is 4. All four players and
any standalone server must update together and begin a fresh draft. Old saved
local draft configurations are cleared and old standalone pools are disarmed;
existing continued runs keep their original roster. Wraith/Soul exceptions, PvP
scoring, life rules and dependency minimums are unchanged.

## v0.9.1 Joker pool exclusions (historical)

Removed Matador (`j_matador`), Mr. Bones (`j_mr_bones`) and Luchador (`j_luchador`)
from the draft catalog. New drafted shop/Buffoon/Judgment/Riff-Raff pools therefore
exclude them. Other generators and unrelated runs keep their existing behavior.

There are 142 eligible types. First and second pack rounds retain 12 cards per
pack; the last round divides the remaining 46 into 12/12/11/11, with seeded seat
assignment. Complete pools have 35/35/36/36 types. Two final singleton picks mean
72 submissions for a complete manual draft. The optional Python server uses the
same allocation rules, verified against Lua.

Old saved local drafts with a different catalog size are cleared/disarmed. Old
armed online pools containing excluded types are disarmed for new runs. Existing
in-progress Balatro run saves retain their own saved pool. All clients must update
and start a fresh lobby/draft to use the new pool. Lovely/SMODS minimums stay the
same. All 37 multiplayer integration tests, core/adapter/compatibility checks and
four standalone-server tests pass with the reduced pool.

## v0.9.0 reliability and optimization pass

- One ordered Draftout frame dispatcher replaces three independent update
  wrappers, preserving native return values. Module responsibilities and known
  limitations are documented in `docs/ARCHITECTURE.md` for code review.
- A session component centralizes phase assignment and cleanup. Closing/replacing
  a lobby or ending a match clears old draft state; recent retired session offers
  cannot reopen it. New drafts clear old opening/reveal caches.
- Frame-loop context validation runs at 250ms intervals and immediately after
  relevant lobby events; picks and starts still validate fresh. Catalog lookups
  use a session cache. Hidden draft overlays no longer update readiness labels.
- Final pool handoff messages retry after loss. Repeated final views do not
  repeatedly save the same pool. Duplicate native starts with the same run identity
  no longer restart the game or reset lives.
- Average packets receive stricter validation; average and draft receives share
  an error boundary. Required private integration interfaces are checked before
  installing referee wrappers; repeated installation is guarded.
- In a controlled 300-frame untimed draft test, roster lookups dropped from
  1,800 (v0.8.1) to 20. This is not an overall FPS/CPU improvement measurement.
- All 37 multiplayer integration tests pass, including dropped handoff messages,
  duplicate starts, stale sessions, fresh command validation and real upstream
  checkpoint/metadata-mirror behavior over a simulated relay. Core, adapter,
  dispatcher and older dependency compatibility checks also pass.

Install v0.9.0 on every client and use a fresh lobby. Lovely 0.9.0 and Steamodded
beta-1814a minimums are unchanged. PvP entry stalls and reported life gain after
disconnect still need real-game verification; this release does not claim host
migration support or complete replacement of private APIs.

## v0.8.1 locked-Joker mod icon

The active Draftout entry on Steamodded's Mods page uses the game's existing
locked-Joker sprite, referenced through `G.j_locked.pos` on the Joker atlas.
No artwork file or copyrighted game textures are bundled. Installed texture
replacements of the Joker atlas will also affect this badge. Native dependency
failure badges remain intact. When Draftout is disabled its Lua hook does not
run, so the normal fallback badge remains. This is an in-game badge, not an
exported PNG or Thunderstore package icon. Gameplay is unchanged.

## v0.8.0 draft usability

- One outer Draftout panel/cursor context remains open between packs, wrapper
  transitions, waiting screens and team pages. It replaces only the embedded
  content using Balatro's native tab-switch pattern. Peer readiness updates still
  update labels in place without rebuilding a player's hovered pack.
- Jokers reveal in a 35ms stagger (under half a second for 13). Each is selectable
  and hoverable once visible. Effects Off and Reduced Motion skip the reveal;
  rebuilding the same active pack retains the original reveal clock.
- Confirmed players see their locked pair and a live count of players still
  choosing. Only that client's own confirmed picks are shown.
- The host deck selector previews standard deck art and the native deck effect
  description. Click a deck to preview; **Use this deck for everyone** commits.
  Cancel leaves the shared deck unchanged. Previewing does not alter viewed_back,
  the run deck, lobby metadata or Joker picks.
- The completed multiplayer draft shows the personal roster in 14-card pages,
  Common/Uncommon/Rare totals and **Close this screen and Ready up in the PvP
  lobby**. Solo completion gives a summary after selecting a seat, with its full
  roster available through Review final roster. The standalone server uses its
  normal pool-arming instruction instead of PvP Ready.
- Offline tests cover the persistent panel lifecycle, reveal/input timing,
  live waiting labels, completion summary and preview-versus-apply behavior.
  All 28 MP integration tests and older dependency compatibility tests pass.
  UIBox/Sprite/Back rendering in those tests is mocked: panel layout, native deck
  descriptions and animation timing still need a Windows in-game visual check.

Install v0.8.0 on every client and start a fresh lobby. Lovely 0.9.0 / SMODS
beta-1814a minimums and existing gameplay rules remain. Previously reported entry
stalls/disconnect life gain remain open live investigations.

## v0.7.5 draft panel entrance

Draftout overlays start at their centered position instead of using Balatro's
10-unit slide from below. Embedded Joker previews lay out at their final grid
positions immediately; the previous background slide made the cards appear
before their panel. The centered entrance also prevents the background from
sliding in again when an opening finishes, packs pass, or the team view returns.
Wrapper opening effects, card pop/selection lift and sounds remain available.
This applies to Draftout's local/online draft and team overlays, without changing
Balatro's other menus. Native overlay offset handling was verified with the
supplied game callback under an offline UIBox harness; Windows visual timing
still needs playtesting. Lovely/SMODS minimums are unchanged.

## v0.7.4 drafted Joker Collection

During an active Draftout run, the normal Joker Collection shows only types in
that run's saved drafted shop pool. Open the usual in-game Collection and choose
Jokers. All drafted types are listed, including those not bought yet. Owned
Wraith/Soul exceptions are not added. Native sorting, pagination, descriptions
and win stickers remain available; drafted previews reveal art/descriptions
without modifying permanent discovery/unlock flags. Other collection categories,
shop pools, main-menu collections and unrelated runs are unaffected. Works with
continued saves carrying `G.GAME.draftout_pool`, including solo test runs.

Fixed an average-display delivery-order race: a fresh live board for the current
ante is retained if it arrives before the native startBlind action, while old
final boards are cleared. Wrong-ante messages cannot advance the revision fence.
The review did not establish another cause for the previously reported PvP entry
stalls or life gain after a disconnect; those remain open live investigations.

Six collection regressions execute Steamodded's real collection builder and page
callback with mocked graphics. They cover 37-card pagination, exclusions, unlocked
art with unchanged discovery flags, scope and error cleanup. All 27 integration
tests pass. Native Windows rendering and real server ordering still need live
playtesting. Existing Lovely 0.9 / SMODS beta-1814a minimums are unchanged.
Install v0.7.4 on every client and use a fresh lobby.

## v0.7.3 playtest fixes and open investigations

- The average is now confined to its HUD fields; native opponent-score values
  retain the actual interaction target's score. Ordinary blinds restore their
  own chip-text binding and scaling callback. Native HUD reset removes the
  dynamic average label reference, and a new PvP start clears the prior mean.
- Average messages from another ante are ignored. Score comparison arithmetic
  and the one-life penalty are unchanged. The rules handshake is now 5 to reject older clients.
- Run-setup deck cycles ignore stale mod-Collection filtering while building
  and switching decks. Reproduced the exact symptom offline: preview says Red
  while profile memory stores Blue, so reopening appears to repair it. Genuine
  mod Collections retain their filters, and temporary state restores on errors.
- Soul-eligible Tarot/Spectral/Planet generation arguments pass upstream unchanged.
  No Soul probabilities or pool weights were changed in Draftout. This does not
  establish why the playtest saw many Souls; other mods, seeds and native behavior
  still need live investigation.
- Repeated native ready barriers and native forfeit tests pass offline. Entry
  stalls and the reported extra life remain unresolved. Added scoped host-side
  Draftout log messages with seat numbers, lives, hands, ante and readiness at
  ready/start/forfeit events to help diagnose the next live run.
- 26 MP integration tests, six deck-cycle regressions, core/adapter checks and
  the older dependency compatibility suite pass. Rendering, real server ordering,
  disconnect/host-migration behavior remain unverified. Host migration is not
  supported by Draftout yet. Use a fresh lobby with v0.7.3 on every client.

## v0.7.2 shared starting deck

The purple private-Royale deck display is now a host-only selector for the 15
standard Balatro decks. Deck art/unlock progression is not required to select
these multiplayer options; custom/modded and Challenge decks are not listed.
The host may choose before guests arrive or after drafting, before match start.
The selector uses the native shared `deck` metadata; launch waits for the host's
server echo, and the normal PvP start flow applies the selected deck to everyone.
Random/individual deck overrides are disabled for the Draftout run so everyone
uses the chosen deck. Existing Joker pools are preserved.

Guest, stale-lobby and mid-match changes are rejected. Other modes are unaffected.
The new offline tests exercise the actual PvP lobby control tree and native
run-start handoff, with game rendering and the server relay mocked. All 24
integration tests pass; native Windows UI rendering and live server behavior
still need playtesting. All players should install v0.7.2 and use a fresh lobby.
Lovely 0.9.0 and SMODS beta-1814a remain the minimum versions.

## v0.7.1 compatibility update

- Lowered Draftout's Lovely minimum from 0.10.0 to 0.9.0 after reviewing its source
  and the exact Lovely 0.9.0 / SMODS beta-1814a sources.
- Kept SMODS minimum beta-1814a. No gameplay changes or protocol changes.
- Draftout has no Lovely TOML patches and makes no direct Lovely API calls.
- Ran all 2,681 adapter assertions under LuaJIT with beta-1814a's actual
  `SMODS.load_file`, `SMODS.save_mod_config`, `SMODS.showman`, and JSON module.
  Filesystem writes, serialization and game rendering remain mocked.
- Checked declared dependency versions using beta-1814a's actual version parser.
- Checked field names in 100 upstream SMODS/API/PvP Lovely manifests against
  Lovely 0.9.0's Rust patch schemas. This is a schema-field check, not execution
  of the injector or proof that every patch matches the game.
- Core/clock/average/adapter tests, 20 multiplayer integration tests and existing
  modern-SMODS atlas regressions passed. Windows DLL injection, the full LÖVE
  game and an official-server four-player match remain unverified.

Compatibility is supported by source review and offline tests, pending in-game
confirmation on the exact older dependency combination.

## v0.7.0 average-score PvP (historical; final-two rules superseded above)

Every player starts with **4 lives**. **Ante 1** uses normal Small, Big and
Boss blinds. **Ante 2 and onward** uses Small, Big, then PvP instead of the Boss.
Draftout enforces this schedule for its own private Royale matches.

At the end of each PvP, add the final scores of every player still alive and
divide by that player count. Each player **strictly below** that average loses
**one life**. Meeting or exceeding it is safe. If everyone ties, nobody loses a
life. With four players, one, two or three players may lose a life. Normal blind
failures retain PvP's one-life penalty. Surviving players keep their run and
continue shopping; there is no life refill when the field shrinks.

Eliminated players are excluded from subsequent averages. With two players,
this becomes the usual lower-score-loses rule; equal scores are safe. The
existing host referee waits for everyone's hands to finish, applies life loss
at most once per blind, and declares the last survivor the winner.

The PvP HUD shows **Average (live)** while hands remain and **Final average**
when everyone has finished, plus the number of finished players. The live value
is provisional. Native hide-score-until-played remains respected. Timer
eligibility uses the average; native Joker/consumable interaction targets remain
separate. Ordinary Royale, 1v1, other PvP modes, Speedrunning, and local draft
testing retain their normal combat behavior outside a launched Draftout match.

Life-loss comparisons use sparse decimal arithmetic on the referee's reported
ordinary/scientific score components: compare score times alive count against
the total, without rounding the average or overflowing a Lua number. HUD values
are rounded for display and do not decide life loss. Layered/tetration score
formats from big-number overhaul mods are not supported by this comparison.

Install **v0.8.1 on every player's machine** and start a fresh lobby/draft.
The native packet protocol remains 4, with combat/draft rules handshake 4;
older rules are rejected before drafting. This changes the MPAPI/PvP match,
not the separate Python draft server or solo development test into a PvP match.

## v0.6.4 automatic pack opening

The local reveal/privacy step is removed. Starting or resuming a draft displays
the current seat automatically, and confirmed pairs advance directly to the next
seat. Local testing now intentionally shows every seat on the same screen.
Online players still receive only their own private pack and roster.

With Pack effects On, the start of each fresh round shows a 0.9-second automatic
Buffoon wrapper animation, using the game's actual wrapper art, native Card
renderer/dissolve shader and buildup/release sounds. Then all assigned Jokers
appear (normally 12, including the one 13-card pack in the final round). Passed
packs, refreshes and My Team returns do not replay it. Effects Off or reduced
motion skips the wrapper; the draft choices appear immediately.

This is an adapted presentation, not a call to Card:open(), Card:explode() or
the native Buffoon shop state. Those routines assume an active run, use a clock
that freezes in paused menus, and handle in-run card acquisition. Draftout keeps
its pregame two-pick transactions and private synchronization. No native pack
area, run state, pack choices, money or owned Jokers are changed by the animation.
The opening uses a real-time clock, independent of game speed and paused menus.
Optional pick timers continue during this brief presentation, both locally and
online. Network protocols and draft rules are unchanged.

## v0.6.3 raised selections

Selected Jokers lift above their resting position and lower when deselected.
The gold outline has been removed. Each preview area reserves headroom for the
lift, and refreshed packs restore the raised state for any pending choices.
Back stays above the pack and Confirm selection stays at the bottom. Preview
selection does not create the normal in-run Use/Sell buttons.

## v0.6.2 selection layout

Selected previews now have a muted gold outline drawn in the card's own moving
coordinates. It follows the card instead of outlining the larger cell and label.
Back is above the pack, and Confirm selection occupies the bottom footer position.
The footer stays disabled until the required number of Jokers is selected and
locks while submitting. Team galleries and waiting screens keep their normal
Back footer. Draft rules and network protocols are unchanged.

## v0.6.1 face-up preview fix

Removed the face-down flip animation that left menu previews showing their backs
in the reported game session. Pack, team, and confirmation previews now explicitly
start with both facing states set to front; they never enter the native flip
state machine or disable hover while waiting for it. Pack effects use a brief
face-up pop and sound instead. Selection works immediately, without waiting for
card update callbacks. Draft rules and native/server protocols are unchanged.

## Draft options and timer behavior

**My Team** is a read-only gallery of your drafted availability pool, not your
currently owned in-run cards. It never shows other online players' picks.
Readiness names/flags update without rebuilding your hovered pack. Local tests
use Seat 1–4 labels; native lobbies use the player display names.

In **Mods → Draftout → Config**, **Pick timer** cycles Off (default), Scaling
(5 seconds per Joker remaining), then fixed 30, 45, 60 and 90 seconds. It applies
to the next draft. The host can also change it on the native checking screen;
other clients use the host's chosen policy and current resolved duration.
For local hotseat, each seat's clock starts automatically when that seat's pack
appears. Closing a local test stops that seat's clock; resuming restarts it.
Refreshing or viewing My Team does not restart the clock. It is a testing mode,
not a competitive timer.

Online, the host/server owns the deadline and auto-picks. Tentative selections
that reach it before the deadline are preserved; missing slots are filled by
random distinct cards from that same pack. A final singleton picks one card.
Late/stale submissions cannot change an expired turn. The clock uses real time,
continues while My Team/the native overlay is closed, and pauses if a peer is
away, resuming its remaining time on reconnect while the same host/state survive.
Host migration still requires a draft reset.

**Pack effects** defaults On and toggles the automatic wrapper opening,
fresh-pack pop and native sounds. Turning it Off keeps the selection lift,
choice counter, team gallery and timing rules. Hover effects remain native.

All clients should use v0.18.3 (the same rules handshake as v0.18.0). Native packet protocol remains 4
with rules handshake 16. Start a fresh lobby/draft. The standalone tool was removed in 0.15.1.

## How the 1.0 adapter works

`draftout/mpapi_transport.lua` registers Draftout's own `draftout_pack_v4`
ActionType in `MPAPI.on_loaded`, keeping its correct Draftout owner. API 1.0.0
filters a lobby's actions to its owning mod and the API, and exposes no public
add-on action hook for PvP lobbies. The compatibility shim wraps
`MPAPI._internal.lobby.create_object` and adds only this action to PvP Nakama
lobbies' `_action_types` tables. It leaves the global ownership filter and every
other action unchanged. Speedrunning/local lobbies receive no Draftout binding.
This internal integration is tested against the supplied 1.0.0 sources;
the dependency declarations also allow newer API/PvP releases.

The old `PVP.ACTIONS.modded` path is not used: its `moddedAction` message is absent
from the new PvP transport router. Native receiver callbacks use the sender
supplied by API dispatch, never an identity inside the submitted payload.

`draftout/mpapi.lua` gates `PVP.pvp_start_match` after PvP's deferred startup,
waits for completed/released pools, and queues the existing start function on the
next Game:update tick. It preserves PvP's server-selected seed and existing
match-start events. Guards reject an unexpected start before pool release.

`draftout/atlas_compat.lua` retains the reported missing-column metadata repair;
after loader startup existing animation atlases receive missing dimensions from
their actual image/cell sizes. It never invents dimensions without source data.

## Developer checks

Python plus `lupa` is required only to run the developer tests:

```powershell
py -3 -m pip install lupa
py -3 tests/run.py
py -3 tests/mpapi_spec.py
py -3 tests/atlas_spec.py
py -3 tests/compatibility_spec.py
py -3 tests/deck_cycle_spec.py
py -3 tests/collection_spec.py
py -3 tests/showman_spec.py
py -3 tests/overlay_spec.py
py -3 tests/updates_spec.py
```

For `mpapi_spec.py`, set `DRAFTOUT_API_REFERENCE` and `DRAFTOUT_PVP_REFERENCE` to
the extracted 1.0.0 mod folders, or place them in the sibling `reference_mp_100`
tree. This suite explicitly skips if the reference source is unavailable. No
upstream mod code/assets are included in this ZIP. Atlas regression tests can use
`DRAFTOUT_SMODS_REFERENCE` pointing at Steamodded 26.1002.0 source.
The compatibility suite uses Python 3.11+ (`tomllib`) and Lupa's LuaJIT runtime;
set `DRAFTOUT_LEGACY_SMODS` to the extracted beta-1814a source and
`DRAFTOUT_LOVELY_REFERENCE` to Lovely v0.9.0 source. These sources are not bundled.

The API tests cover timed auto-picking through the 108 dealt cards, partial-selection
preservation, late-pick rejection, timer pause/resume, private readiness signals,
hover-preserving readiness updates, and deferred startup, per-lobby ownership, Speedrunning/public
isolation, full private draft, forged picks/senders, duplicate offers, release
acks, next-match reshuffling, peer reconnect, host change, start gating, and
preserving the real API start payload. Remaining live checks are installation,
menu rendering, private message routing on the official server, and playing the
complete resulting Royale match with the selected pool restrictions.

Original Draftout code is MIT-licensed. MultiplayerAPI, PvP, Speedrunning, and
Balatro are separate dependencies with their own licenses.
