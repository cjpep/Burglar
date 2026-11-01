# Burglar 0.26.5

## 0.26.5

- Fixed the deck wheel confirming a spin too early when it picks the deck already selected. It now waits for the server to echo that specific roll ID.
- Fixed swallowed mouse, keyboard, and controller releases when an input was held before the wheel opened. Inputs used only for the overlay, including dismissal clicks, remain blocked from the lobby underneath.
- Includes all 0.26.4 changes: the 126-copy / 63-unique "Don't Worry Chat, We're Scaling" cube and Asteroid exclusion from Burglar consumable pools on Balanced and rulesets using its layer. Other balance changes remain active. Already-owned Asteroids are not deleted.
- Removed the example cube. Existing selections of that file fall back to Default; completed drafts and saved run rosters are retained.
- Keeps the deck wheel, updated icon, Fantom_Balatro's cubes, and previous gameplay fixes. Standard edition only, without spectating.

Validation: 19 focused Lua/API simulation scenarios passed, including all 15 deck outcomes across four simulated clients, delayed metadata, duplicate clicks, matching-roll acknowledgement, input-release handling, and dismissal click-through prevention. Native rendering, the real Balatro controller, and live-server multiplayer were not playtested. Package contents and cube counts were checked.

