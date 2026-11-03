> Spectator prototype 0.20.1: see SPECTATOR_PROTOTYPE.md for the new table, protocol and targeted checks. The release notes below describe the earlier baseline.

# Development and release checks

Credits: Fantom and Cjpep.

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
these directories beside the extracted `Draftout-source` directory:

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
Developer archives additionally include tests/tools and historical docs. ZIP
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
the existing Draftout action, then the host commits a two-roster manifest to lobby
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
end-game builder and whose run owns a Draftout pool. It preserves callbacks and
native result data; other mod screens pass through unchanged.

## Live checks before a wider release

- Four-player draft → two separate saved-roster semifinals → fresh final.
- Guest enables before/after host; delayed/lost consent; disabling then normal PvP.
- Score/life/readiness messages over long original-mode matches and host departures.
- Results/recap and roster-mode menus at smaller resolutions and with a controller.
- Compare diagnostics from host and affected guest; confirm no identifiers/pools.

Offline tests mock the renderer and server relay. Passing them is not a claim
that the official server or Windows rendering has been verified.
