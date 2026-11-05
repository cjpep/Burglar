# Releasing Burglar 0.26.6

## Update GitHub source

1. Extract `Burglar_v0.26.6_GitHub_Source.zip`.
2. Open `Burglar-source`. Upload its contents to the repository root. Do not upload the ZIP as source or create a nested Burglar-source folder.
3. Delete `cubes/example_pool.json` from GitHub if it remains there. Web uploads replace and add files, but do not delete missing files.
4. Commit as `Burglar 0.26.6: Multiplayer 1.0.5 compatibility`.

The stable internal ID remains Draftout for saved data and network compatibility. The visible mod name is Burglar. Historical spectator source and notes remain in the developer archive, but main.lua does not load them and the builder excludes them from installable packages.

## Publish GitHub release

Create a release using tag `v0.26.6` and title `Burglar 0.26.6`. Paste the changelog bullets from the root `RELEASE_NOTES.md`. Attach `Burglar_v0.26.6_Standard.zip` as the player download. You may also attach the source and Thunderstore ZIPs if desired. This release was simulated, not live playtested; retain a pre-release label if that matches your rollout.

## Update Thunderstore

Under the existing **cj** team, upload `Burglar_v0.26.6_Standard_Thunderstore.zip` unchanged. Its manifest name remains `Burglar`, so version 0.26.6 updates the existing package. Do not re-enable or upload the deprecated spectator edition. The package includes manifest.json, icon.png, README.md and CHANGELOG.md at the ZIP root, with the playable mod in Burglar/.

Dependencies are listed for MultiplayerAPI/PvP 1.0.5, Lovely 0.10.0 and Steamodded 26.1002.0. The multiplayer packages must be published on Thunderstore for dependency validation to accept them.

## Rebuild

Update `Burglar.json`, `manifest.json`, and the release documents together, then run:

```sh
python tools/build_release.py --output dist
```

The builder requires Python 3.10+ and no extra packages. It checks matching versions/dependencies, module references, the 256x256 PNG icon, assets, and Standard-only runtime contents. It creates three deterministic ZIPs, each with a CONTENTS.sha256 inventory. It does not bundle Balatro or the dependency mods.
