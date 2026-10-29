> Current release: 0.21.0. See RELEASING.md for the two editions and RELEASE_VALIDATION.md for the packaging checks. SPECTATOR_PROTOTYPE.md documents the experimental viewer.

# Development and release checks

Credits: Cjpep and Fantom_Balatro.

The developer archive includes the complete editable Lua source, assets, tests,
notes and packaging script. Do not install it alongside the player archive.

## Tests

Python 3.11+ and `lupa==2.8` are required for the supplied test runners.

```
python -m pip install lupa==2.8
python tests/run.py
python -m unittest discover -s tests -p '*_spec.py'
```

The Python integration tests use separately obtained reference sources. Keep
these directories beside the extracted `Burglar-source` directory:

- `reference_mp_100/BalatroMultiplayer-MultiplayerAPI-1.0.0`
- `reference_mp_100/BalatroMultiplayer-MultiplayerPvP-1.0.0`
- `reference_smods/smods-1.0.0-beta-1814a`
- `reference_smods/smods-26.1002.0`
- `reference_lovely/lovely-injector-0.9.0`

Individual test headers document environment-variable overrides. Reference
sources and game files are not bundled. Tests that require unavailable references
skip where supported; a run with skipped suites is not equivalent to full validation.

## Build

```
python tools/build_release.py --output dist
```

The builder selects an explicit set of runtime modules, assets and player docs.
The GitHub source archive additionally includes tests/tools and historical docs. ZIP
ordering, timestamps and permissions are fixed; each archive includes a SHA-256
inventory. Rebuilding identical sources produces identical ZIP bytes in the same
Python/zlib environment. The builder verifies metadata, module paths and assets;
it does not substitute for running tests.

## 0.19.0 boundaries

`roster_duel.lua` owns persisted roster tickets and per-lobby consent. Tickets
contain only format version, anonymous draft identifier, original seat/count,
pack rounds and Joker keys. The identifier is a correlation hash, not a signature.
Only the private Nemesis path consumes tickets; ordinary runs/public/ranked and
Royale remain separate. Two explicitly opted-in clients exchange consent through
the existing Burglar action, then the host commits a two-roster manifest to lobby
metadata. The guest acknowledges that exact token before the host starts.

`Game.start_run` still copies an availability pool into the new run. Saved-roster
matches use native PvP's referee and never activate the average-scoring adapter.
The host enforces four starting lives; new match/lobby consent is required after
completion, departure or host change. There is no automatic bracket scheduling,
spectating, cross-process match recovery or signed tournament roster enforcement.

`diagnostics.lua` is optional, local and bounded: 256 recent event lines, 256
pending disk lines, one-second flush cadence, current/previous files of at most
128 KiB each. Its event/field allowlists prevent arbitrary payloads from entering
the log. Disk/clipboard failures are isolated. Numeric action tags retain their
sequences but session/run identifiers are replaced with process-local counters.

`results_ui.lua` themes only MPAPI result shells whose body is PvP's native
end-game builder and whose run owns a Burglar pool. It preserves callbacks and
native result data; other mod screens pass through unchanged.

## Live checks before a wider release

- Four-player draft → two separate saved-roster semifinals → fresh final.
- Guest enables before/after host; delayed/lost consent; disabling then normal PvP.
- Score/life/readiness messages over long original-mode matches and host departures.
- Results/recap and roster-mode menus at smaller resolutions and with a controller.
- Compare diagnostics from host and affected guest; confirm no identifiers/pools.

Offline tests mock the renderer and server relay. Passing them is not a claim
that the official server or Windows rendering has been verified.

## Burglar lobby picker entry (0.20.5)

`burglar/lobby_entry.lua` wraps `PVP.build_game_select_ui` after MPAPI loads.
Only the create_lobby intent receives an extra native pillar. The upstream page
is built first; one extra pillar column is inserted, and its icon disposal is
composed with the original page disposal. No generic API functions, game-mode
registries, private lobby flow, or third-party source files are replaced.

The callback resolves the current native Royale create handler at click time.
Burglar continues using its existing private pvp_royale integration, not a newly
registered server mode. The count describes supported draft sizes (2 or 4);
the native lobby capacity is unchanged. F8 still opens setup.

## Shared settings and lobby access (0.20.6)

`deck_picker.lua` decorates the existing private Royale lobby controls with a
Join / view draft row. The host starts the existing routing check only when no
session exists; otherwise the callback opens the current draft. Guests cannot
create/reset a draft. No persistent opt-in or server/player-role change occurs.

`B.matches` still verifies lobby object, code, exact player IDs and owner. Only
a completed/released, not-started session can adopt an updated ruleset profile.
Host balance controls additionally require all pool-release acknowledgements.
Changes use partial lobby metadata and launch waits for the host's metadata echo.
The native Lobby Options callback delegates to this path for Burglar lobbies,
preserving its original behavior elsewhere. This avoids the native full metadata
writer restoring stale config.back when a shared deck had been selected.

The picker embeds native Back.generate_UI nodes directly in its parent layout
and never creates a detached description UIBox. Deck preview does not set
G.GAME.viewed_back, run saves, RNG state or shared metadata until Apply. Its
sprite cleanup is idempotent and also runs when an overlay is closed indirectly.
