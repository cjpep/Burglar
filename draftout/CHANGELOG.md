# Draftout 0.20.3 — Spectator shop layout

- Added a dedicated shop cabinet with separate offers, vouchers and booster-pack
  shelves, readable price tags and empty-shelf labels.
- While shopping, the sidebar shows available money and inventory instead of
  blind scoring. Held Jokers and consumables remain at the top; the deck stack
  is hidden to leave space for the shop.
- The layout switches with the existing captured shop state. Purchases and
  rerolls continue using the existing delayed display snapshots.
- Preserved the boss background, gameplay, spectator transport and wire format.
- Cosmetic update: test suites were not run; Windows visual playtest pending.

# Draftout 0.20.2 — Spectator boss background

- Replaced the flat green spectator backdrop with Balatro's native animated
  background shader, using the visible boss colour when identifiable and The
  Eye's purple palette for PvP/the local demo.
- Added a subtle dark veil for readability. Reduced motion freezes the swirl.
- The decorative background is owned and removed by the spectator overlay;
  it does not change the underlying run's background, scoring or network protocol.
- Cosmetic update: test suites were not rerun. Windows rendering and real-client
  spectating still need playtesting; the local demo remains scripted gameplay.

# Draftout 0.20.1 — Spectator table prototype

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

# Draftout 0.20.0 — Spectator prototype

- Added a delayed read-only board viewer for eliminated players in private Draftout Royale matches.
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

# Draftout 0.19.1

- Fixed the roster Sort button stretching into a tall column beside the Joker grid.
  Each roster section now owns a separate row, keeping all three card columns
  inside the left panel. Panel width, card scale and top alignment are retained.
- Added a regression check for native row/column structure.

# Draftout 0.19.0

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

- Draftout's native PvP results use the teal palette while retaining native
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
