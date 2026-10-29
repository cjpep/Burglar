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
