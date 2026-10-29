# Spectator table prototype 0.20.4

Credits: Cjpep and Fantom_Balatro.

## Implementation choice

The initial investigation considered a native save snapshot followed by action
replay. This first prototype instead projects periodic complete display frames.
It is an intentionally narrower implementation: useful live information without
replacing the eliminated player's run or running the survivor's game logic.

The supplied PvP playback launcher refuses to run in a real lobby. A faithful
mid-run replay would additionally need card-ID resolver restoration, mod state
outside G.GAME, isolated referee state and suppression of gameplay side effects.
None of those are silently bypassed here. No reconnect changes were made.

## Data flow

1. The viewer requests one surviving player over Burglar's existing directed
   `draftout_pack_v4` MPAPI action. Spectator packets use `kind=spectator_v2`.
2. Both endpoints check the private Burglar Royale session/run, recipient,
   original match membership, current presence and authoritative/cached lives.
   The source requires viewer lives <= 0 and source lives > 0. The viewer also
   requires its native eliminated flag. Unknown lives fail closed.
3. A subscription waits for SHOP or BLIND_SELECT once, then samples visible
   cards and run counters up to four times per second. Unchanged frames have a
   two-second heartbeat; frames over four chunks are limited to one per second. Renewals preserve this gate;
   choosing a new target creates a new token and a fresh gate.
4. A JSON frame is split into UTF-8-safe chunks of at most 4,000 bytes. Receivers
   bound chunk counts to 24 and concurrent incomplete frames to four. Incomplete
   frames expire after four seconds. Schema validation copies only declared fields.
5. A complete validated frame waits at least five seconds after complete receipt
   before display. Sequence numbers reject duplicates and older frames; sequence
   gaps are allowed because each frame is self-contained. No clock sync is assumed.
6. The viewer retains at most 32 delayed frames, discarding superseded due
   frames. Requests renew every four seconds; source subscriptions expire after
   twelve seconds. Streams have no pending response callbacks to leak when ACKs
   are lost. Closing, leaving, changing matches and elimination stop the view.

Each visible card area is limited to 24 entries. The source sends only plain
display fields: center/front keys, a captured name, face-down/debuff status,
edition/sticker names, seal, price, selection status, opaque display ID and
selected numeric ability values. Display IDs are local monotonic labels stored
in a weak-key map, not account IDs or changes to native Card identifiers. A face-down
card has no name/key/value leakage. Neither draw-pile order, draft roster, replay
history, RNG state, account credentials nor a complete native save is transmitted.

The same directed action is already used by the draft. Server payload/rate limits
are not established by the offline relay; verify actual forwarding in a playtest.
There is no incoming external spectator role or server API change in this build.
This is not an anti-cheat boundary against deliberately modified clients; source
authorization relies on the same host outcomes/lives cache as the rest of the mod.

## Code map

- `burglar/spectator.lua`: session authorization, subscriptions, transport,
  polling, results button and F9 shortcut.
- `burglar/spectator_wire.lua`: bounded frame schema, fragmentation, assembly,
  sequence rejection and delayed queue. No game globals.
- `burglar/spectator_capture.lua`: read-only visible-board projection.
- `burglar/spectator_ui.lua`: persistent table lifecycle, player cycling and scripted demo.
- `burglar/spectator_table.lua`: pure layout and cross-area motion model.
- `burglar/spectator_painter.lua`: atlas-image table renderer, HUD and hover values.
- `burglar/mpapi.lua`: dispatches spectator packets/events to the isolated module.
- `main.lua`: loads the module and adds the local preview Config button.

No gameplay Card objects are constructed for the viewer. Art reads atlas images directly through a single Moveable;
the viewer never calls a card's effect, save_run, Game:start_run or the replay
driver. It does not replace G.GAME, PVP.GAME, PVP.REF or the current lobby. Existing
round/run-tag checks and native final-1v1 referee functions are unchanged.

## Automated validation completed

- 14 spectator integration tests through the supplied MPAPI action validation,
  dispatch and simulated relay, with real PvP reports/outcomes and run/round tags.
- An eliminated host watches while a twelve-PvP match reaches one winner;
  exact lives, one final result and unchanged native final-1v1 resolver checked.
- Host migration while another eliminated player watches; the new host continues
  to referee and the eliminated player cannot regain lives or participate.
- Requests from living players rejected; wrong run, old token and wrong sender
  frames ignored; no save/load, replay, RNG, gameplay-card or run-state side effects.
- Initial checkpoint and five-second buffer, target switching, disconnect cleanup,
  subscription expiry, reordered chunks, duplicate chunks and missing-frame recovery.
- Missing frame ACKs do not accumulate MPAPI pending callbacks.
- 25 pure protocol checks including bounded queues, malformed data, sparse arrays,
  non-finite sequence values, incomplete-frame expiry and UTF-8 chunk boundaries.
- 297 layout/motion/capture assertions, including dense 24-card areas, stable
  IDs across hand/play, selected-card lift, reduced motion and face-down data.
- UI lifecycle smoke test exercises a complete demo cycle and atlas draw calls,
  confirms the table is never rebuilt per frame, checks balanced graphics state
  and preserves game/referee state. This does not render Windows/LÖVE pixels.
- Existing main adapter test (3,158 assertions) and eight targeted multiplayer
  regressions, including 50 tied PvPs, long-match completion, duplicate/stale
  reports, departing eliminated players, host handover and native final 1v1.
- Runtime Lua files parsed with Lua 5.1. No unrelated cosmetic test sweep.

The existing adapter's old `YOU: B` assertion was updated to the already-shipped
local-seat label `YOU`. The draft UI code itself was preserved from the coral
arrow patch; no scoring or draft rules were altered for this prototype.

## Required live playtest

1. Install the same prototype on all clients, with only one Burglar folder active.
   Keep the stable version outside Mods for rollback. No dependency/DLL replacement.
2. Outside a lobby, open Config → Local spectator preview. Check the table fits,
   Joker and playing-card art renders, selected cards lift and travel into play,
   shop/pack layouts appear, hover values work and Close/Restart work.
3. Start a fresh four-player private Burglar Royale match and finish the draft.
4. Eliminate a guest first. Use Watch remaining players (or F9), choose a survivor
   and wait for their shop/blind-selection checkpoint plus the buffer.
5. Have the survivor reroll, buy/sell, play/discard, open a pack and use a consumable.
   Confirm those visible changes arrive; the viewer's cards must not be playable.
6. Switch survivors, close/reopen the viewer and briefly interrupt the connection.
   Check old player's frames do not reappear and the display recovers at a checkpoint.
7. Repeat with the host eliminated first. Continue several PvPs, including final
   1v1, while the host watches. Check ready/start flow and life deductions.
8. Verify a watched player leaving/eliminating stops that feed, the final result
   appears correctly, and a new match or ordinary PvP lobby has no old feed.

Record screenshots/crash text, who hosted, who watched, target player, ante and
the last action before a failure. The local preview proves no network behavior.
Live Windows rendering, actual server forwarding, latency, third-party art mods
and reconnect-from-process-restart remain unverified.

## Running the tests

Install Python and `lupa`. Set `DRAFTOUT_API_REFERENCE` and
`DRAFTOUT_PVP_REFERENCE` to the supplied MultiplayerAPI and MultiplayerPvP 1.0.0
source folders. From Burglar:

```
python -m unittest discover -s tests -p spectator_spec.py -v
```

The Lua-only specs can run via `tests/run.py` (which also runs all other Lua specs)
or individually using a Lua 5.1 interpreter. Upstream sources and Balatro game
files are intentionally not bundled. See tests/mpapi_spec.py for the relay fixture.

## What this step does not do

The table interpolates between received display states; it does not execute a
survivor's actions. Chip/mult fields are captured values. Edition borders/seal
markers are simplified, not native shaders. A complete scoring-animation replay
requires a different, more detailed event/replay integration. This version does
not pretend that increasing snapshot frequency provides every scoring event.

## 0.20.2 visual update

The table now owns one decorative native Sprite using the built-in background
shader. It uses a matching boss palette or The Eye for PvP, keeps shader inputs
private, respects reduced motion, and removes the Sprite when the stage closes.
No live background colour tables, run state or network packets are changed.
The prior automated results describe 0.20.1; no test suite was rerun for this
cosmetic update. Actual Windows visuals and official-server delivery remain
playtest requirements. This local preview is scripted gameplay, not the draft.

## 0.20.3 shop layout

The shop phase has a dedicated cabinet: offers/vouchers on the upper shelf and
booster packs below. Price tags sit beneath items, and empty areas have labels.
The sidebar shows money and inventory; the deck stack is hidden during shopping.
Held Jokers and consumables retain their normal top positions. The scripted local
demo automatically visits this layout during its shop phase. No fake clickable
shop controls or inferred reroll costs were added. Network capture and gameplay
are unchanged. Cosmetic test suites were skipped at the user's request.

## 0.20.4 clarity and navigation

Capture adds optional bounded string fields `reroll_cost` and `pack_choices` to
the existing v2 display frame. Older frames default these fields to empty and
show no fabricated values. The source reads current_round.reroll_cost only in
SHOP and G.GAME.pack_choices only in pack states. No reroll/purchase callbacks
are invoked. Updates retain the existing five-second minimum receipt buffer.

The renderer derives waiting/buffering/stalled badges from local receiver state.
A feed with no complete frame for over 12 seconds shows FEED STALLED while
retaining the last board. This is a connection indicator, not a source-clock
latency estimate. Countdown uses the next local delayed-frame deadline. Phase
and shop-update notices compare displayed frames only and reset on target change.

Pack views retain a visible hand for Tarot/Spectral interactions and use two rows
for more than six options when no hand is present. The deck stack is hidden to
avoid covering pack cards. Names and remaining choices are visible.

Previous/Next can select one remaining survivor after a departed target and do
not reselect the current survivor, preserving an existing buffer. Demo controls
only affect the local scripted timeline, never pause the live match.

Validation: 15 MPAPI integration tests passed, including the eliminated host
watching a 12-PvP match and real action relay of new fields through the delay.
Wire checks: 29; layout/capture/status checks: 329; UI draw/lifecycle/control
checks passed. These use Lua 5.1 with supplied API/PvP source and a simulated
relay/graphics calls. They do not establish real-server transport or Windows
visual correctness. Full native animations and action replay remain out of scope.
