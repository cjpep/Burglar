# Custom draft pools

Choose **Draft pool** in the local draft setup or the host's online draft setup.
Click to cycle through Default and the JSON files in this folder.
Default keeps Burglar's existing eligible Joker list.

To make your own pool:
1. Copy `example_pool.json` into this same folder with a new name, such as `my_cube.json`.
2. Edit the `name` and the `jokers` array. Use internal Joker IDs (for example `j_joker`), not display names.
3. Keep `version` set to 1. Remove IDs you don't want. Repeat an ID to include multiple draftable copies.
4. In draft setup, cycle **Draft pool** to your file, then choose the pack count and prepare the draft.

Only the online host needs the file. Guests receive and validate the selected list; their own pool setting is ignored. The list is frozen when the host prepares the draft. Reset/prepare again after editing the file. Changing the pool never changes an existing run's shop roster.

Files must have names made of letters, numbers, underscores or hyphens ending in `.json`. Maximum file size: 64 KiB. Names inside the JSON must be 1–40 characters. Invalid JSON, excluded Jokers and unavailable Jokers are rejected. A cube can contain up to 512 entries, including duplicates. This version supports subsets of Burglar's normal eligible vanilla Jokers; modded Jokers are not supported. Existing exclusions and Wraith/Soul exceptions remain in effect.

Each player gets 9 Jokers per pack for packs 1–3, and 8 in pack 4. Required draftable copies:

| Packs | Two players | Four players |
| --- | ---: | ---: |
| 1 | 18 | 36 |
| 2 | 36 | 72 |
| 3 | 54 | 108 |
| 4 | 70 | 140 |

Choose fewer packs if the pool is too small. For example, a custom pool of common Jokers may require one pack per player in a four-player lobby. The game reports the actual eligible count rather than silently adding Jokers or duplicates. Only the shuffled cards dealt into packs enter the draft; the remainder stays out of every player's shop pool.

## Multiple copies

Repeat the ordinary ID in the JSON array. For example, two `"j_blueprint"` entries put two separate Blueprints into the cube. Do not write the internal `#2` suffix yourself. Duplicate cards are independently selectable and may be drafted by different players. Copies omitted when packs are dealt are unavailable to everyone.

For a cube containing duplicates, each player's drafted count controls new Joker availability. Draft two Blueprints and you may own two; a third is blocked unless you drafted three. A player who drafted one copy has a limit of one. Editions do not change this count. Selling or destroying a copy frees its availability again (except the existing Gros Michel extinction rule).

Owned cards, existing shop/pack offers and pending card creations all count so simultaneous offers cannot exceed the limit. Shops, Buffoon packs, Judgment and Riff-Raff respect it; Showman does not bypass these explicit limits. Wraith and Soul remain exceptions, and existing copying effects are not prevented from copying cards. Any extra owned copies still count when deciding whether another shop/generated copy may appear.

If every eligible copy is already owned or offered, a new shop/Buffoon Joker slot falls back to **Jimbo (`j_joker`)**, not a Tarot. Judgment and Riff-Raff also use Jimbo when no eligible Joker remains; Riff-Raff first tries your drafted Commons. Rare/Uncommon Tags first try their promised rarity, then Jimbo. This is an explicit exception: Jimbo need not be drafted and can exceed his copy cap, but he is never added to your roster. Normal Joker-space limits still apply. Default and nonduplicate drafts use the same Jimbo exhaustion fallback. Copy limits are availability caps, not lifetime purchase quotas.
