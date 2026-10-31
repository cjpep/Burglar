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
