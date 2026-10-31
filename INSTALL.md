# Installing Burglar 0.26.0

Choose one player download: **Standard** (no spectator code) or **Spectator** (experimental viewer included). Use the same version and edition as your friends.

1. Close Balatro.
2. Open `%AppData%\Balatro\Mods` using Win + R.
3. Move your old Draftout or Burglar folder outside Mods. Don't keep backups inside Mods.
4. Extract the ZIP and put its Burglar folder in Mods.
5. Check that `Mods\Burglar\Burglar.json` exists. Avoid a nested Burglar\Burglar folder.
6. Launch Balatro. Requires Steamodded >= beta-1814a, Lovely >= 0.10.0, MultiplayerAPI >= 1.0.4, and MultiplayerPvP >= 1.0.4. This release was checked against Multiplayer 1.0.4.

Create a private Burglar lobby through Multiplayer PvP. Gather two or four players, click Open draft, then let the host choose settings and Start drafting. After the draft, return to the lobby, ready up, and Start Game.

Optional: enable **Open deck lists** before drafting to review everyone's completed rosters before the run. The new default timer is **Scaling: 5s per Joker**; saved timer preferences are preserved.

The deck/stake button below Open draft uses PvP's native picker. Balance is under Lobby Options. A completed draft is preserved when the host changes these settings before starting.

Solo testing: Mods → Burglar → Config → Local development draft.

To switch editions, close Balatro and replace the entire Burglar folder with the other edition. Do this between matches. Never install both at once.

README.md contains full instructions. EDITION.txt identifies this player download. The GitHub source ZIP is for repository upload; player downloads are the easiest installation.

For tournaments, switch **Format** to **Tournament** in Open draft with four players. After drafting click **Play tournament**. Both semifinals run independently. Both players return to lobby after their match; Burglar reunites the players for a fresh final.
