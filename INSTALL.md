# Installing Burglar 0.26.7

This release is **Standard** (no spectator code). Everyone should use version 0.26.7 Standard.

1. Close Balatro.
2. Open `%AppData%\Balatro\Mods` using Win + R.
3. Move your old Draftout or Burglar folder outside Mods. Don't keep backups inside Mods.
4. Extract the ZIP and put its Burglar folder in Mods.
5. Check that `Mods\Burglar\Burglar.json` exists. Avoid a nested Burglar\Burglar folder.
6. Launch Balatro. Requires Steamodded >= beta-1814a, Lovely >= 0.10.0, MultiplayerAPI >= 1.0.5, and MultiplayerPvP >= 1.0.5. This release was checked against Multiplayer 1.0.5.

Create a private Burglar lobby through Multiplayer PvP. Gather two, three, or four players, click Open draft, then let the host choose settings, Check players, and Start draft once connections are ready. After the draft, return to the lobby, ready up, and Start Game.

**Reveal rosters after draft** is on by default (also enabled once when upgrading). Turn it off before drafting if you want private rosters. The new default timer is **Scaling: 5s per Joker**; saved timer preferences are preserved.

The deck/stake button below Open draft uses PvP's native picker. Balance is under Lobby Options. A completed draft is preserved when the host changes these settings before starting.

Solo testing: Mods → Burglar → Config → Local development draft.

The Spectator edition is deprecated. Install Standard only and remove any older Spectator copy from Mods.

README.md contains full instructions. EDITION.txt identifies this player download. The GitHub source ZIP is for repository upload; player downloads are the easiest installation.

For tournaments, switch **Format** to **Tournament** in Open draft with four players. After drafting click **Play tournament**. Both semifinals run independently. Both players return to lobby after their match; Burglar reunites the players for a fresh final.

Replace the whole old Burglar folder, rather than merging files. This release includes the deck wheel and empty-opponent-row fix. No separate wheel patch is needed. Start a fresh draft after everyone updates. Automated Lua/API simulations were run against the supplied 1.0.5 mods. See RELEASE_NOTES.md for scope. Native rendering and live-server multiplayer were not playtested.

The host can choose **Open draft → Random deck** before drafting or after the draft finishes. Every player sees the same animated wheel and selected deck. All players must use this release to see the animation. Native deck selection remains available.
