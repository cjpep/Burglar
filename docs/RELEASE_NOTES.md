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

Choose **Standard** for the full mode without spectator code, or **Spectator** for the experimental delayed viewer. Install only one edition. Close Balatro and replace the entire old Burglar folder.

Requires Steamodded beta-1814a+, Lovely 0.10+, MultiplayerAPI 1.0.4+, and MultiplayerPvP 1.0.4+. Automated integration checks use the supplied 1.0.4 sources. Live Windows visual and multiplayer playtesting is still needed.

Original idea: **Fantom_Balatro**. Development: **Cjpep**. Thanks to **NightmareBalatro, AustereGenie388, PatientEscape38, and UnseenExplosion** for playtesting.
