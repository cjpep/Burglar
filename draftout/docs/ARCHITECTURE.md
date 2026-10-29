## Two-player support (v0.18.0)

The draft state carries `player_count` (2 or 4). Missing values default to 4 for
existing saved local drafts. Online count comes from the checked roster, never
from the local test preference. Rules handshake 16 prevents mixed clients.
Recap assembly uses the original seat count even after departures, including
compact checkpoint recovery and the final Undrafted tab. Combat round/referee
logic is unchanged; its existing two-survivor branch handles a two-player match
from its first PvP. Initial HUD mode also starts in native duel mode.

# Draftout architecture and review notes (v0.17.3)

Credits: Fantom and Cjpep.

This is a working beta for the supplied MultiplayerAPI/PvP 1.0.0 builds. It has
source-level and offline integration coverage; it is not a fully validated live
multiplayer release.

The catalog excludes Matador, Mr. Bones, Luchador and Showman (141 eligible types). The
standard draft deals only a shuffled prefix: 108 unique types in 12 packs of 9,
27 per seat. The other 33 never enter a roster. Four packs use 9/9/9/8 per seat,
140 dealt and 35 per team, with one type left out. Pick count (1/2) and pack rounds
(1/2/3/4) are snapshotted by the host; defaults are one and three. Core state schema
is 6, native rules handshake 16. The standalone development server was removed
in 0.15.1. Old config drafts/pools
are cleared/disarmed, while continued run saves retain their original roster.

The turn clock separates its captured setting (`scaling` or fixed/off) from
resolved seconds. Scaling resolves once per new wave as 5 times the maximum
remaining pack size, before anyone picks. Local hotseat uses that seat's size.
Snapshots carry the current seconds/mode and remaining countdown; no client
config or received card count determines online deadlines. Fixed timers and
legacy local draft saves retain their prior behavior.

After-pick feedback has no interstitial state or delay. Confirmation only plays
a short optional sound; waiting screens show status and the own-team tray.
Odd pack rounds pass left; even pack rounds pass right. Each round keeps its
direction until its packs are empty. `core.direction` owns that rule and
`core.pack_origin` derives the source seat for recap validation/reconstruction.
Seating arrows
and receiving/passing labels use the current round. Core state records per-seat accepted pick tokens and
keys; ordinary native snapshots omit the full private history.
`recap.lua` snapshots the completed host draft on accepted game start. It sends
five bounded parts only after the API's GAME_ENDED event, validates recipient,
host/session/run/lobby identity, pool exclusivity and complete ordered timelines,
and waits for the receiver's own end event before saving/revealing anything.
A separate context survives draft teardown for retry requests, including when
fewer than four players remain. The most recent completed recap is persisted;
its UI is available after teardown without automatically replacing native results.
Solo developer previews never overwrite that saved recap. Unfinished host state
and recap-transfer recovery after app restart are not implemented.

## Module boundaries

| Module | Responsibility |
|---|---|
| `draftout/core.lua` | Pure deterministic draft rules, atomic picks, availability sampling. |
| `draftout/recap.lua` | Post-match visibility, validated chunk assembly/retries, saved recap and paged gallery. |
| `draftout/session.lua` | Ephemeral session teardown, validated phase names, display polling and eight retired session tokens. |
| `draftout/mpapi.lua` | Draft protocol, fresh command validation, handoff acknowledgements/retries and PvP start gate. `B` is the existing bridge object exposed as `D.mpbridge`. |
| `draftout/mpapi_transport.lua` | Isolated private-API dependency: action binding and lobby factory interception. |
| `draftout/average.lua` | Exact comparison of ordinary/scientific scores; no rounded threshold decisions. |
| `draftout/average_pvp.lua` | Scoped mode/HUD wrappers, average/duel status validation and native 1v1 HUD handoff. |
| `draftout/combat_rounds.lua` | Host readiness and round settlement fences, report/outcome tags, 3-4-player mean resolution and delegation to native 1v1 scoring. |
| `draftout/handover.lua` | Atomic native/Draftout recovery checkpoints, stable outcome IDs, report retries and scoped host takeover. |
| `draftout/showman.lua` | Draftout-scoped Rare Showman; moves/restores native and SMODS rarity entries without replacing other pool contents. |
| `draftout/updates.lua` | One native `Game.update` wrapper and ordered module callbacks. |
| `draftout/overlay.lua` | Stable tinted outer panel with replaceable embedded UIBox content. |
| `draftout/pack_ui.lua` | Native Joker previews, raised selection/shadows, confirm footer, opening effects and timer display. |
| `draftout/draft_views.lua` | Compact progress/seating header, team tray, paged roster and utility controls. |
| `draftout/collection.lua` | Run-scoped roster Collection with display-only sorting and native pagination/art. |
| `main.lua` | Game adapter, shop/generator restrictions, local draft UI and run pool assignment. |

## Lifetime and authorization

Session phase names are `idle`, `checking`, `draft`, `complete`, `playing`, and
`error`. Phase assignment is centralized; message handlers still enforce their
own phase/ownership/token preconditions. This is not a formally verified state
machine. Host reset / validated offer enters checking, picks enter draft, final
pool acknowledgement enters complete, and run preparation enters playing.

The host remains trusted. Draft packets contain only each recipient's pack/roster. The
handshake checks catalog identities and rules version, not full mod build/effect
hashes. There is no trusted-server anti-cheat. Active-run recovery metadata
contains a compact all-seat roster backup; client code can inspect it even
though recap packets and UI are still gated on the local GAME_ENDED event.

Commands use fresh roster/ruleset checks. The 250ms cache is exclusively the
frame-loop context check, invalidated by roster/metadata/snapshot events. It
never authorizes picks or run starts. Timer disconnect checks still read current
connectivity when a timer is enabled. Roster checks stop after the run starts;
combat uses its latched session/run and original participant IDs instead.

Lobby closure, game end or current-lobby replacement clears the draft's packs,
acks, cached catalog, timers, launch flags and transient presentation state. Run
availability remains in `G.GAME.draftout_pool`; historical user config is not
cleared. Host changes before the run require a draft reset. During the run, the
new host restores the committed referee and Draftout lifecycle and forfeits the
departing host. The server chooses the successor; Draftout does not elect one.

Eight retired session tokens are retained to reject recently delayed offers
without retaining unbounded session history. The same active draft can refresh
or reconnect; full process restart does not restore the host's in-memory draft.

## Reliability and performance changes in 0.9.0

- Native start notifications with the same run ID, seed and restart flag are ignored after acceptance,
  preventing a duplicate notification from resetting referee lives or the run.
- Final view / complete-ack / release / release-ack loss is retried at most once
  per 1.5s while the lobby context remains valid. Duplicate completed views resend
  the acknowledgement without writing the saved roster again.
- Native draft catalog keys/signature/set/count are built once per session.
- Readiness labels are updated only when the Draftout overlay is visible.
- The frame dispatcher preserves all native return values without allocating a
  result table each frame. Callbacks retain their original registration order.
- Average payload numeric ranges, final/finished consistency and score syntax
  are checked before the receive revision changes. Both draft and average
  handlers share an error boundary.
- Required PvP referee interfaces are checked before wrapping functions. This
  does not eliminate private-API dependence or make all hook installation
  transactional; optional UI wrappers remain dependent on the pinned game APIs.

A controlled comparison against the v0.8.1 ZIP used the same four-client test
harness, an active untimed draft, no visible overlay and 300 updates at 60Hz.
Roster `get_players` calls fell from 1,800 to 20. This is an operation-count
measurement for that path, not an FPS, CPU-time, memory or network benchmark.
Timed drafts and visible overlays perform additional necessary connectivity/UI
work. Full private view snapshots are still sent on picks and refreshes; no
snapshot-delta protocol was added.

## Combat lifecycle and native 1v1 boundary

The host's combat round opens once all living participants ready the same ante.
It resolves at most once, then cannot reopen for that ante. Ordinary blind resets
and a late final report cannot re-arm the settled PvP. Native API reports/outcomes
carry session/run/ante/sequence tags; old reports and old-run outcomes are rejected
before mutation. Report-handler wrapping and the action-instance factory are
pinned private API dependencies. Extra fields must survive server forwarding.

At 3-4 survivors, `average.lua` computes the exact below-mean set at completion.
At 2 survivors, the controller directly calls the original upstream pure
`PVP.referee_resolve_2p_round`; it does not replace its implementation or require
both players to finish when the native rule can already decide the duel. Native
opponent HUD/score/timers resume. The mode switch is sent as duel status, without
an average. Scores and lives remain in native PVP.REF structures.

## Active-match host handover

`handover.lua` replaces checkpoint/takeover only while this Draftout run is
active. Its checkpoint preserves the pinned upstream `_pvp_ref` v1 fields and
score triplets, adding a versioned `draftout` object with session/run, original
participant IDs, authority generation, readiness, settled ante, sender sequence
fences, the last committed outcome batch, and compact recap data. Other modes
call the original upstream checkpoint/takeover functions. Restoring validates
identity, participant roster, scores/lives, outbox shape and recap completeness
before replacing the native referee. Missing/stale checkpoints fail closed;
the guest's incomplete local referee is never used to guess starting lives.

Scoped referee operations queue authoritative outcomes until their entire state
has been serialized. The metadata write is queued before those actions on the
same Nakama connection. Recovery replays the latest committed batch using stable
per-run outcome IDs, and receivers fence each action/player token by that ID.
Changing hosts changes the accepted sender and authority generation. Clients
retain reports until metadata acknowledges their sequence and retransmit any
unacknowledged reports on handover. Native score relay/replay logging is not
re-run during that retransmission. The ready barrier and closed-ante fence are
restored, so normal-blind reports cannot re-arm a settled PvP.

The original host is forfeited even if still listed as away. An elected
eliminated player can referee without regaining lives or rejoining play. Further
host departures can restore an earlier committed checkpoint in the observed
host chain and forfeit every departing host. Recap data uses catalog indices;
pick tokens and omitted keys reconstruct deterministically and validate before
use. This is a trusted-peer backup, not encryption. The recap UI still opens
only after match end. Unfinished drafts and full app restarts remain unsupported.

Durability assumes the official server accepts these metadata fields and
processes same-connection writes/actions in order. The client has no metadata
commit acknowledgement API; these guarantees still require live verification.

## Test boundaries and next review priorities

The API suite uses actual uploaded lobby/action/start/referee code and a simulated
Nakama relay. It can drop selected messages. Checkpoint tests run the scoped
Draftout writer and actual upstream metadata mirror, with mocked server
storage/echo and modifier/setup helpers. They check that metadata echoes
do not restart a run or reset draft state. It is not an official-server test.

Long-match regressions route through the real outgoing PvP router and actual
report handlers. They include a complete 12-PvP match, 50 ties, five randomized
finishes, duplicate/stale packets across antes and reseeds, and native 1v1 early
finishes after eliminations/leaves. G.GAME transitions, game renderer, upstream
outcome screen bodies and official result negotiation still use harness mocks;
these tests do not establish a fully verified live end-to-end match.

The UI suites mock UIBox, Sprite, Card and Back behavior as needed. They cannot
establish real clipping, pointer/controller focus, animation appearance, GPU
resource cleanup or interactions with arbitrary installed mods. The outer
panel is persistent; its embedded contents are still rebuilt for pack changes.

Priority live checks: repeated full antes/PvP entry, disconnect during a hand,
metadata forwarding, final handoff under lag, and long-session UI allocation
behavior. The earlier entry-stall and disconnect/life reports are not claimed
resolved merely because the offline tests pass. Active-run host handover has
offline coverage; real server election and ordering remain unverified. Review
the private action binding, hook order and session
cleanup first; optimize drawing only after profiling the actual game.

## Removed standalone tool (0.15.1)

Only local development drafting and the native MPAPI/PvP path are loaded. The
standalone connection UI, worker, Python server and launcher are removed. Startup
retires their old config fields, including connection/reconnect data and armed
standalone pool. Existing saved runs retain their own copied availability pool.
No socket worker or standalone update callback is installed.

## Showman rarity scope (0.16.0)

The draft catalog omits Showman. Run startup applies Rare rarity before native
card construction for a new or continued Draftout run. A constant-time frame
check restores the original rarity/pool membership after leaving the run. A
Wraith construction also ensures the override is active. Registry scans happen
only on activation/restoration, not every frame. Both the native rarity pools
and SMODS.ObjectTypes.Joker.rarity_pools are handled, deduplicating aliases.
Only Showman's entries move; their original slots are retained for restoration.
Wraith's native selection, seed, bans, unlock and duplicate checks remain. The
drafted picker excludes Showman even if an older saved roster contains it.

## 0.17.0 UI and Ante 1 failure regression

Native PvP action_start_game sends setAnte(0) before constructing the first run.
Draftout previously stored zero as the referee ante and rejected later Ante 1
fail reports at report_current's exact-ante check. The zero startup marker is
now ignored. The test feeds it through the API, runs the actual native
Game:update_new_round failed-score hook and PVP.ACTIONS.fail_round, then checks
one life loss, duplicate rejection and progression to later PvPs/blinds. The
native final-two resolver, life broadcasts and settlement fences are unchanged.

Draft utilities expand inside the existing panel. They do not own game state or
clock deadlines; Resync sends the same refresh request as before. Error messages
remain visible, while ordinary draft status is conveyed by progress/seating.
The timer has a separate header source so clearing a submitted pack does not
clear the waiting countdown. Selection state survives utility/resync rebuilds.

Collection sorting copies references to roster centers, sorts only that local
list, and re-enters the native collection builder/pager at page 1. A sort control
is inserted by matching the first native CardArea's object identity, avoiding
wrapper nesting assumptions. The callback checks the active run pool and
collection area identity; other collections and the original pools are intact.

## 0.17.1 PvP start recovery

The local outgoing ready action records an ante-scoped pending intent. Every two
seconds while native ready_blind remains true it repeats the same hand-count
request with a fresh report sequence. Unready, accepted start/end/win, local
elimination, reset or ante change clears the intent. Retries never create a
choice or alter first-ready ordering. A ready retry for an open matching ante
replays the original pvp_start_blind event ID; accepted clients deduplicate it.
The retained start event travels in the referee checkpoint across host changes.
Departures also re-evaluate try_start, including zero-life departures; surviving
ready records are retained. Native two-player scoring is unchanged.

Departure-only zero-life cases pass offline, including eliminated-host takeover.
A living departure at an already-ready barrier reproduced a stall before the
fix. Lost-message tests demonstrate recovery, but the exact reported live
eliminated-player hang has not been independently reproduced.

## Animated outline

`border.lua` decorates only the instantiated Draftout surface UIElement. Its
draw wrapper invokes the original, uses native prep_draw for placement/scale,
and restores the graphics stack. Geometry is cached until the surface changes
size; a wall-clock phase belongs to the overlay owner so replacing content does
not restart the lap. No new update hooks, shaders, assets or gameplay messages.
Reduced motion and Pack effects Off draw only the base outline.
