# Burglar 0.26.6 — Multiplayer 1.0.5 compatibility

- Updated the mod and Thunderstore dependencies to MultiplayerAPI 1.0.5 and MultiplayerPvP 1.0.5.
- Verified the existing integration against the new native startup, readiness acknowledgement, result handling, and host takeover paths. No changes to Burglar's draft or scoring rules were needed.
- Keeps the host's shared random deck wheel, current icon, Fantom_Balatro's custom cubes, the scaling cube, and the Balanced Asteroid exclusion.
- Updated the release builder to produce matching Standard player and Thunderstore packages plus a separate GitHub source archive. Spectator remains deprecated and is excluded from the installable packages.
- Removed the obsolete example cube from the repository source, matching the previous player release. Updated the install and release instructions.

Validation: 104 Python test cases passed; two obsolete custom-picker cases were skipped because the native-picker suite covers their replacement. Tests use the supplied 1.0.5 API/PvP code with a simulated relay and game environment. Coverage includes 2/3/4-player startup, Cocktail recipe propagation, a 24-round FFA-to-1v1 match, repeated/stale reports, host departure, independent semifinal rooms, fresh finals retaining only drafted rosters, native deck/stake/balance changes, Balanced rarity tags and duplicate copy limits, and package integrity. Runtime Lua syntax also checked with Lua 5.1. Native rendering, Steam authentication, automatic tournament room handoffs on the real server, and live multiplayer were not playtested.

## Installing

Everyone should update to Burglar 0.26.6 and MultiplayerAPI/PvP 1.0.5 before starting a fresh draft. Lovely 0.10.0+ and Steamodded beta-1814a+ are still required. Replace the whole old Burglar folder; don't install two copies. Keep the current icon and manifest name when updating the existing cj-Burglar Thunderstore listing.

## Files

- `Burglar_v0.26.6_Standard.zip`: attach to your GitHub release; players extract the Burglar folder into Mods.
- `Burglar_v0.26.6_Standard_Thunderstore.zip`: upload unchanged to the existing cj-Burglar package.
- `Burglar_v0.26.6_GitHub_Source.zip`: extract and upload the contents of Burglar-source to the repository root. This is for development, not the recommended player installation.

See `docs/RELEASING.md` in the source ZIP for the upload steps.
