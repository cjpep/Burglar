# Burglar 0.23.1 — Draft setup layout fix

- Keep the draft settings inside a row so local development and online Open draft menus stack their controls vertically and center them inside the panel.
- Fix the pool selector pushing player count, timer, action and Back buttons to the right or outside the panel.
- No gameplay, duplicate-copy, scoring or multiplayer connection changes.

# Burglar 0.23.0 — Duplicate cubes and Multiplayer 1.0.4

- Custom JSON cubes can repeat Joker IDs. Each copy is independently drafted, displayed, passed and saved; players may draft the same Joker from different copies.
- In duplicate-enabled cubes, new Joker availability follows each player's drafted copy count. Owned cards and shop/pack offers reserve copies; selling frees them again.
- Apply copy limits to shops, Buffoon packs, Judgment and Riff-Raff. Exhausted shop/pack Joker slots use a Tarot fallback. Wraith, Soul and copying effects retain their exceptions; Default drafts retain prior behavior.
- Preserve copy identities through roster sorting, Collection, recap, saved-roster 1v1s and host checkpoints.
- Update compatibility to MultiplayerAPI/PvP 1.0.4 score text and host checkpoint formats. Burglar continues using its own scoped round recovery; ordinary PvP retains native synchronization.
- Keep average scoring for three/four survivors and native head-to-head scoring for two.
- Everyone must update Burglar and use matching Multiplayer versions. Automated checks use the uploaded 1.0.4 sources; live Windows playtesting remains necessary.

# Burglar 0.22.1 — Simpler pool selector

- Removed the Commons-only preset. Draft pool now cycles through Default and custom JSON files only.
- Existing Commons-only settings return to Default. Custom JSON pools remain unchanged.
- Updated the cube guide. No gameplay or network protocol changes.

# Burglar 0.22.0 — Custom draft pools

- Click another Joker to replace a full selection; pick-two mode replaces the oldest selected card. Clicking a selected card still deselects it. Confirmation and timeout intent tracking remain in place.
- Added a Draft pool selector: Default, Commons only, and custom JSON files from the cubes folder.
- Host shares the selected list with every client; guests validate it without needing the file. Prepared drafts retain their original list.
- Reject invalid JSON, duplicates, excluded/missing Joker IDs, and pools too small for the selected player/pack counts.
- Included a complete example JSON and editing guide. Custom pools use eligible vanilla Jokers; duplicate/spawn-block behavior is unchanged.
- Includes v0.21.2 PvP recovery. Everyone must use the same version.

# Burglar 0.21.2 — PvP recovery

- Retry unacknowledged match reports every three seconds using their original run/round tags and sequence numbers.
- Recover missed PvP results from the host checkpoint, including life totals, eliminations, and the winner. Retain the terminal transaction across later ante/ready updates and host handovers.
- Keep original outcome IDs so repeated recovery cannot resolve the round or deduct a life twice. Ignore checkpoints from another run, host authority, or ante.
- Check for a missed result before processing the match-ended notification.
- Preserve the existing ready/start retry, average scoring with three or four survivors, and native 1v1 endgame.
- Everyone must use 0.21.2 together; the draft compatibility check rejects older builds.
- Validated with the supplied MultiplayerAPI/PvP 1.0.3 code and simulated message loss. Official-server playtesting remains necessary; this cannot repair a broken game animation or a complete disconnection.

# Burglar 0.21.1 — Multiplayer 1.0.3 compatibility

- Updated requirements to MultiplayerAPI/PvP >= 1.0.3 and Lovely >= 0.10.0.
- Use PvP's native deck/stake picker, preserving its challenge and sleeve handling.
- Keep Open draft in the existing deck-control space for hosts and guests, without adding a lobby row or Group Queue button.
- Keep completed draft pools when the host changes deck, stake, or balance; wait for server metadata confirmation before launch.
- Balance remains under Lobby Options. No draft, life, or final-two-player scoring rules changed.
- Checked native picker routing, host/guest controls, twelve-round matches, eliminated-player departures, host handover, Ante 1 boss losses, and delayed spectator updates using the supplied 1.0.3 code and a simulated relay.
- Standard still physically excludes spectator modules and hooks. Windows rendering and official-server play need playtesting.

# Burglar 0.21.0 — Release packaging

- Two complete player editions: Standard excludes spectator code; Spectator includes the experimental viewer.
- Renamed install/module folders and manifest to Burglar. Internal save and protocol identifiers remain compatible.
- Included the latest compact lobby layout and clearer draft button labels.
- Updated author order to Cjpep, then Fantom_Balatro; credited the original concept and playtesters.
- Added current install/play instructions, GitHub release notes, and a reproducible builder for both editions.
- No draft rules, life rules, or final-two-player scoring changes in this packaging release.

# Burglar 0.20.6 — Lobby draft access and shared settings

- Added Join / view draft to every player's private Burglar/Royale lobby. Hosts
  can check clients and begin the draft there; guests can open the same draft
  without F8. Opening a completed draft never resets it. F8 still works.
- Preserve completed Joker pools/session IDs when the host changes balance
  rules before the match. Deck and balance can be applied together after drafting.
- Block balance changes during an unfinished draft, pending pool release or
  match launch. Keep host, roster and lobby identity checks.
- Fixed the native Lobby Options balance path overwriting a selected shared
  deck with an older config.back value. Wait for metadata confirmation at launch.
- Reworked the deck picker into a side-by-side native description/art preview
  and selected-deck grid, with balance controls and Apply/Cancel. Description
  nodes now participate directly in layout; preview sprites are cleaned up.
- Lovely 0.10.0 passes source-level compatibility review: beta-1814a dependency
  parsing and 100 dependency patch manifests checked against its schema.
  The Lovely >=0.9.0 requirement is retained; no injector binary is bundled.
- Validation: 9 focused lobby/deck/session cases, a 12-PvP spectator match, and
  3 source-level compatibility cases passed. No full unrelated suite run.
  Windows rendering, patch execution and live-server play remain unverified.

# Burglar 0.20.5 — Burglar lobby entry

- Added a Burglar pillar to PvP's Create Lobby page alongside the four native
  options, using the same button, nameplate, description and player-count UI.
- Added the locked Joker icon, a coral nameplate, the description "Draft your
  Jokers / Build your shop pool" and a supported player count of "2 or 4".
- CREATE delegates to native private-Royale creation, preserving its queue
  guards and connection setup. Draft setup still opens with F8 in the lobby.
- Practice menus, other modes, draft rules and match scoring are unchanged.
- Passed a focused headless check using the supplied native picker/pillar code:
  one added entry, native routing, unchanged practice, and sprite cleanup.
  Actual Windows menu spacing still needs visual playtesting.

# Burglar 0.20.4 — Spectator clarity and navigation

- Added waiting/buffering/stalled-feed badges and a local buffer countdown.
- Show actual reroll cost in shops and remaining choices while opening packs.
  These optional fields also accept older v2 frames that do not supply them.
- Added pack-specific titles, a pack panel, two rows for larger packs without
  a hand, and the visible hand when using card-targeting packs.
- Added short phase/shop-update notices derived only from displayed snapshots.
  Shop changes are labelled neutrally; snapshots do not identify every action.
- Fixed player navigation when only one survivor remains after the old target
  leaves. Selecting the same survivor no longer restarts their delay buffer.
- Added Pause / resume and Next step controls to the local demo, plus two shop
  packs and a changed shop offer/cost for inspection.
- Passed 15 MPAPI spectator integration tests (including a 12-PvP match), wire
  and layout/capture checks, and headless UI lifecycle/control checks.
- Match rules, scoring and native final 1v1 logic are unchanged. Live-server
  delivery and Windows appearance still require playtesting.

# Burglar 0.20.3 — Spectator shop layout

- Added a dedicated shop cabinet with separate offers, vouchers and booster-pack
  shelves, readable price tags and empty-shelf labels.
- While shopping, the sidebar shows available money and inventory instead of
  blind scoring. Held Jokers and consumables remain at the top; the deck stack
  is hidden to leave space for the shop.
- The layout switches with the existing captured shop state. Purchases and
  rerolls continue using the existing delayed display snapshots.
- Preserved the boss background, gameplay, spectator transport and wire format.
- Cosmetic update: test suites were not run; Windows visual playtest pending.

# Burglar 0.20.2 — Spectator boss background

- Replaced the flat green spectator backdrop with Balatro's native animated
  background shader, using the visible boss colour when identifiable and The
  Eye's purple palette for PvP/the local demo.
- Added a subtle dark veil for readability. Reduced motion freezes the swirl.
- The decorative background is owned and removed by the spectator overlay;
  it does not change the underlying run's background, scoring or network protocol.
- Cosmetic update: test suites were not rerun. Windows rendering and real-client
  spectating still need playtesting; the local demo remains scripted gameplay.

# Burglar 0.20.1 — Spectator table prototype

- Replaced the tabbed card-information panel with a persistent full-table view.
- Added native-style score/chips/mult/resources sidebar, top Joker/consumable rows,
  central played cards, one hand row and a deck stack. Shops/packs appear in place.
- Added stable display IDs, raised selected cards, eased movement across areas,
  hover inspection and shadows. Reduced motion snaps transitions.
- Increased changed-state sampling to up to 4 Hz; suppressed duplicate idle frames
  with two-second heartbeats and limited large frames to 1 Hz.
- Added a scripted local demo covering draw, selection, play, score, shop, purchase
  and pack selection. Live data remains delayed by at least five seconds.
- Bumped spectator wire format to v2; everyone must use this prototype version.
- No scoring/draft rules or referee changes. Full native action replay is not yet implemented.

# Burglar 0.20.0 — Spectator prototype

- Added a delayed read-only board viewer for eliminated players in private Burglar Royale matches.
- Added Watch remaining players on the results screen, F9 access after elimination,
  survivor selection, board/card tabs and a local visual preview in Config.
- First board update starts at a shop or blind-selection checkpoint. Full display
  snapshots then refresh approximately once per second with a five-second minimum buffer.
- Added bounded fragment assembly, sequence checks, per-view tokens, run/session
  scoping, expiring subscriptions and full-frame recovery after packet loss.
- Kept the live run/referee in place; no replay engine or save/load side effects.
- Preserved average PvP with three/four survivors and native final 1v1 scoring.
- Included the post-0.19.1 header/font, seat-text, larger passing arrows, pulse
  and coral color changes in the complete package.
- Updated one stale local-seat label assertion in the existing test harness.

This prototype uses display snapshots, not action replay. Full scoring animations,
animated editions, reconnect and external spectator joins are not included.
The official server and Windows renderer still require a live playtest.

# Burglar 0.19.1

- Fixed the roster Sort button stretching into a tall column beside the Joker grid.
  Each roster section now owns a separate row, keeping all three card columns
  inside the left panel. Panel width, card scale and top alignment are retained.
- Added a regression check for native row/column structure.

# Burglar 0.19.0

## Added

- Saved-roster 1v1 mode for manually arranged draft brackets. Export/import a
  completed personal roster; both players opt in in a private two-player Nemesis lobby.
- Matching-draft, distinct-seat and disjoint-pool checks, retrying consent, and
  fresh four-life native PvP runs. Saved rosters persist; lobby activation does not.
- Optional local diagnostics with anonymous seat/session/run references,
  accepted/rejected combat actions, readiness/lives snapshots, clipboard copy,
  bounded memory and two rotating 128 KiB log files.
- Reproducible player/developer ZIP builder, file inventories and release checks.

## Changed

- Burglar's native PvP results use the teal palette while retaining native
  result handling, player/deck controls and exit buttons.
- Draft completion and post-match recap use current headers/panel styling.
  Recap pages show 12 Jokers in six columns, with existing pick-order labels.
- Player ZIP excludes tests, caches and historical development notes.
- Current installation, bracket, testing and troubleshooting instructions replace
  the long historical README; history remains in the Developer bundle.

## Fixed / cleanup

- A delayed send-error callback from an old lobby or draft cannot unlock the
  current pack or overwrite the new session's status.
- Lobby artwork no longer polls lobby metadata during gameplay; the lobby page
  checks metadata once per update instead of twice.
- Combat tracing now uses opt-in diagnostics rather than unconditional console output.

## Unchanged

- Three/four-survivor average scoring and the original mode's native final-1v1 rules.
- Joker eligibility, shop restrictions, Wraith/Soul exceptions and draft passing rules.
- v0.18.3 draft layout: wider left panel, larger three-column roster, top alignment.

New mode and UI changes need live testing. No spectate feature is included.
