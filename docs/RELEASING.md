# Uploading Burglar to GitHub

## Repository files

1. Extract **Burglar_v0.26.0_GitHub_Source.zip**.
2. Open **Burglar-source** and upload its **contents** to your repository's root. Don't upload the ZIP as source or create another Burglar-source folder inside the repository.
3. The top level should show `README.md`, `Burglar.json`, `main.lua`, `config.lua`, `LICENSE`, and the `burglar`, `assets`, `docs`, `tests`, and `tools` folders.
4. If updating the old repository, delete its old `Draftout.json` and `draftout` module directory. Uploading new files doesn't automatically remove them. Keep one manifest and one entry point.
5. Commit with a message such as **Package Burglar 0.26.0 in Standard and Spectator editions**. For a repository you maintain yourself, committing directly to main is fine.

The README is the GitHub description and play guide. Suggested short repository description:

> A two- or four-player Balatro Joker draft inspired by Magic: The Gathering. Draft your roster, build your shop pool, and outlast your friends.

## Release downloads

Create a release tagged **v0.26.0**, titled **Burglar 0.26.0**. Attach:

- `Burglar_v0.26.0_Standard.zip`
- `Burglar_v0.26.0_Spectator.zip`

Use `docs/RELEASE_NOTES.md` for the description. Mark it as a pre-release if you want to retain that label while multiplayer playtesting continues. The Spectator edition remains experimental regardless of the release label.

GitHub also offers automatic source archives. Those contain the source edition with spectator code, so direct players to the named Standard/Spectator ZIP assets. Don't overwrite the repository source with the Standard player files; the builder creates both editions from one codebase.

Bookmark your repository's Releases page for easy access to both downloads.

## Build future releases

Update the code, version in `Burglar.json`, and release documents. Run:

```sh
python tools/build_release.py
```

Python 3.10+ is needed; no third-party packages are required for packaging. Output goes to `../dist`; use `--output PATH` to choose another folder.

The builder checks runtime file references, removes spectator modules and entry points from Standard, includes artwork/font licenses, and adds a SHA-256 inventory. Player ZIPs exclude tests, developer notes, caches, logs, dependency sources, and local saves.

Both editions retain the same internal mod ID and prefix for save/protocol compatibility. Install only one.
