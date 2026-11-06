# Burglar changelog

## 0.26.7 — Drafted Hanging Chad and Bloodstone in Balanced

- Burglar now offers the Multiplayer PvP version of a drafted Hanging Chad or Bloodstone when the active ruleset silently replaces the vanilla Joker. Previously neither version could appear in normal Balanced shops.
- This also applies to drafted Buffoon Packs and eligible Joker generators. True bans and custom cube copy limits still apply. Vanilla shops keep their original Joker IDs and odds.

## 0.26.6 — Multiplayer 1.0.5 compatibility

- Updated the mod and Thunderstore dependencies to MultiplayerAPI 1.0.5 and MultiplayerPvP 1.0.5.
- Verified the existing integration against the new native startup, readiness acknowledgement, result handling, and host takeover paths. No changes to Burglar's draft or scoring rules were needed.
- Keeps the host's shared random deck wheel, current icon, Fantom_Balatro's custom cubes, the scaling cube, and the Balanced Asteroid exclusion.
- Updated the release builder to produce matching Standard player and Thunderstore packages plus a separate GitHub source archive. Spectator remains deprecated and is excluded from the installable packages.
- Removed the obsolete example cube from the repository source, matching the previous player release. Updated the install and release instructions.

Validation: 104 Python test cases passed; two obsolete custom-picker cases were skipped because the native-picker suite covers their replacement. Tests use the supplied 1.0.5 API/PvP code with a simulated relay and game environment. Coverage includes 2/3/4-player startup, Cocktail recipe propagation, a 24-round FFA-to-1v1 match, repeated/stale reports, host departure, independent semifinal rooms, fresh finals retaining only drafted rosters, native deck/stake/balance changes, Balanced rarity tags and duplicate copy limits, and package integrity. Runtime Lua syntax also checked with Lua 5.1. Native rendering, Steam authentication, automatic tournament room handoffs on the real server, and live multiplayer were not playtested.

## 0.26.5

- Fixed the deck wheel confirming a spin too early when it picks the deck already selected. It now waits for the server to echo that specific roll ID.
- Fixed swallowed mouse, keyboard, and controller releases when an input was held before the wheel opened. Inputs used only for the overlay, including dismissal clicks, remain blocked from the lobby underneath.
- Includes all 0.26.4 changes: the 126-copy / 63-unique "Don't Worry Chat, We're Scaling" cube and Asteroid exclusion from Burglar consumable pools on Balanced and rulesets using its layer. Other balance changes remain active. Already-owned Asteroids are not deleted.
- Removed the example cube. Existing selections of that file fall back to Default; completed drafts and saved run rosters are retained.
- Keeps the deck wheel, updated icon, Fantom_Balatro's cubes, and previous gameplay fixes. Standard edition only, without spectating.

Validation: 19 focused Lua/API simulation scenarios passed, including all 15 deck outcomes across four simulated clients, delayed metadata, duplicate clicks, matching-roll acknowledgement, input-release handling, and dismissal click-through prevention. Native rendering, the real Balatro controller, and live-server multiplayer were not playtested. Package contents and cube counts were checked.

# Burglar 0.26.3 — Shared deck wheel and new icon

## 0.26.4

- Added the 126-copy "Don't Worry Chat, We're Scaling" custom cube (63 unique Jokers).
- Includes Burglar; removes Space Joker, Gros Michel, Popcorn, and Diet Cola from this cube.
- Excludes Asteroids from normal consumable pools in Burglar runs using the Balanced layer, while keeping the other balance changes. Saved runs retain the ban. Does not alter non-Burglar matches or remove already-owned Asteroids.
- Retains the host's random deck wheel, updated package icon, and previous fixes.
- Standard edition only; spectator code remains excluded.

Validation: cube JSON/key/count and archive consistency checks only. No automated gameplay tests or multiplayer playtest for this release.

- Added the host-only Random deck button and shared arcade wheel, including shuffled deck positions, visual polish, and final-highlight alignment fix.
- Uses the supplied Burglar artwork as the Thunderstore icon.
- Includes all 0.26.2 changes: FFA average formatting, open rosters by default, clearer host setup, and empty opponent-row fix.
- Standard excludes the experimental spectator feature; Spectator includes it. Install only one edition.

Packaging checks only; gameplay tests were skipped as requested.

# Burglar 0.26.2 — Draft setup and score display

- Excluded the optional random-deck wheel and arcade presentation; native deck selection remains.
- Kept the empty-opponent-row fix: PvP's opponent Joker and consumable slots are hidden only while empty during Burglar runs. Actual opponent cards still display normally.
- FFA averages now display rounded whole numbers with comma separators. Above 100 million, they use scientific notation with up to two decimal places. Exact life-loss calculations and native final-two 1v1 scoring are unchanged.
- Open deck lists default to on, including a one-time upgrade migration for future drafts. Renamed the control to "Reveal rosters after draft". Existing drafts retain their saved visibility, and later preference changes are preserved.
- Host setup now shows clear settings / connection-check / completed-draft stages. Opening the draft screen no longer starts the connection check before the host chooses settings.
- "Start draft" enables only after all player handshakes and the routing check finish. Recovery, restart, and roster-tool buttons have clearer labels.
- Includes earlier 0.26.1 fixes, three-player FFA, independent tournament semifinals, optional stake modifiers, and Fantom_Balatro's custom cubes.

Install only one edition; all players should update and start a fresh draft. Replace the entire previous Burglar folder. No gameplay or automated gameplay tests were run for this release, as requested. Packaging checks only.

# Burglar 0.26.1 — Three-player FFA

- FFA now supports two, three, or four players, including online drafts and the local development draft.
- Three-player drafts still give each player 27 Jokers with the default settings. Packs pass through all three seats and reverse direction between packs.
- Three surviving players use average-score PvP; the final two use the existing native 1v1 scoring.
- Tournament mode still requires exactly four players.
- Updated player-count labels, saved-roster support, and installation instructions.

Everyone in the lobby must update to 0.26.1. Start a fresh draft after updating.
Tests were not run for this release, as requested. Three-player play still needs an in-game playtest.

# Burglar 0.26.0 — Parallel semifinals, results UI, and stake stickers (playtest)

- Tournament semifinals now run concurrently in two independent native 1v1 rooms. Each room has its own ready checks, hands, scores, lives and match result. The final is a fresh run with the original drafted pools.
- Room creation now releases the creator's old seat first, matching the server's rules. The original room stays alive as semifinal 1 and later the finals room. Automatic reunion waits until semifinal 1 has ended and its players have returned.
- Fixed tournament run tracking when PvP's start callback omits the run ID. Stale end reports cannot replace the active result.
- Replaced the oversized results shell/Jimbo sidebar with a compact centered header and smaller content. Native stats, Joker/player selector, View Deck, seed copy, support link and exit buttons remain.
- Added Stake stickers: Off/On. Off is the default; On enables the selected stake's Eternal, Perishable and Rental modifiers with native rolls and compatibility.
- Bundled Fantom_Balatro's six custom cubes: All Commons, All Uncommons, All Rares, Badlatro, Oops All Scoring Jokers and Powered Cube.

All players must update. Begin a fresh tournament after installing. The tournament changes are simulated, not yet live-server verified.

# Burglar 0.25.0 — Lobby tournaments (playtest)

- Choose Tournament inside a four-player Burglar lobby and draft once. The lobby shows the bracket and routes each pair automatically; no roster export or manual room creation.
- Semifinals run one at a time, with native four-life 1v1 scoring. The two confirmed semifinal winners start a completely fresh native match with their original drafted Joker pools.
- A disputed or drawn result does not promote either player. The tournament includes a return/rejoin path and leaves ordinary lobbies on their existing start flow.
- All four players must update. Standard and Spectator editions both include tournaments; the experimental survivor viewer does not apply to these two-player matches.

# Burglar 0.24.1 — Custom cube names

- The setup status line now shows the selected cube's JSON `name` alongside its eligible Joker count. The selector still shows the filename. Reopening Local development draft also shows the saved selection's name. Cubes without a name use their filename.

# Burglar 0.24.0 — Open deck lists and Jimbo fallback

- Added **Open deck lists**, an optional draft setup setting, off by default. After the draft is complete and before the match starts, everyone can use **Review all rosters** to browse the other players' picks, including duplicate copies. Picks remain private during the draft.
- Made **Scaling: 5s per Joker** the default timer. Existing saved timer choices are preserved.
- Fixed Rare and Uncommon Tag offers falling through to unrelated rarities. They now select an eligible drafted Joker of the promised rarity, or Jimbo when none is available.
- Replaced the exhausted shop/Buffoon Tarot fallback with **Jimbo (`j_joker`)**. Judgment and Riff-Raff also use Jimbo if their eligible pool is exhausted. Jimbo is an explicit exception to roster ownership and copy limits; the saved roster is unchanged. Normal Joker-space rules still apply.
- Kept the draft setup controls stacked and centered, with a paginated roster review screen.
- Updated the multiplayer rules handshake. Everyone in the lobby needs the new Burglar version; use matching editions and Multiplayer versions.

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
