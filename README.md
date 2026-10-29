# Burglar

**A two- or four-player Joker draft for Balatro.**

Burglar brings Magic: The Gathering-style drafting to Balatro multiplayer. Before the run, you and your friends open packs of Jokers, pick what you want, and pass the rest around the table. The Jokers you draft become your personal shop pool for that match.

You don't get those Jokers immediately—you still have to find and buy them. The draft gives you a plan, and the run is where you find out whether it was a good one.

Made by **cjpep**, based on **Fantom_Balatro's original idea**. A lot of the changes came from playing it with friends and figuring out what worked.

## Downloads

Get a player ZIP from this repository's **Releases** page:

| Edition | What you get |
| --- | --- |
| **Burglar v0.21.1 — Standard** | The complete draft and multiplayer mode, with spectator code removed. Start here if you don't need spectating. |
| **Burglar v0.21.1 — Spectator** | The same game, plus an experimental delayed view of surviving players after you're eliminated. |

Install **one edition only**. Everyone in the lobby should use the same version and edition. Switch editions between matches by replacing the entire Burglar folder. The GitHub source includes spectating; use a release download for Standard.

## What you need

- Balatro. The development baseline is **1.0.1o** on Windows.
- **Steamodded 1.0.0-beta-1814a or later**.
- **Lovely 0.10.0 or later**. Multiplayer 1.0.3 requires this newer minimum.
- **MultiplayerAPI** and **MultiplayerPvP**, both **1.0.3 or later**. This release was checked against 1.0.3; later releases may need another compatibility review.

MultiplayerSpeedrunning is optional. Remove the old Multiplayer and MultiplayerExperimental mods from active Mods. These downloads don't include Balatro, Lovely DLLs, or the multiplayer dependencies.

## Install or update

1. Close Balatro.
2. Press **Win + R**, enter `%AppData%\Balatro\Mods`, and open that folder.
3. Move any old **Draftout** or **Burglar** installation somewhere outside `Mods`.
4. Extract your chosen player ZIP and place its **Burglar** folder in `Mods`.
5. Check that the path is `Mods\Burglar\Burglar.json`, without another Burglar folder inside it.
6. Start Balatro and check that **Burglar** appears in the Mods list.

Replace the whole folder when updating or changing editions. Don't merge editions or keep backup copies anywhere inside `Mods`.

## Start a match

1. Open **Multiplayer PvP → Create Lobby → Burglar → CREATE**.
2. Share the lobby code. Burglar supports **two or four players**.
3. The host clicks the **deck/stake button below Open draft** to use PvP's native deck picker. Choose balance rules under **Lobby Options**.
4. Everyone clicks **Open draft**. The host's button prepares the draft; if preparation hasn't started, use **Prepare draft** inside the draft screen.
5. The host chooses the draft settings, waits for all players to connect to the draft, then clicks **Start drafting**. Allow the initial two-second connection check to finish.
6. Pick your Jokers and confirm. Hover cards to read them, and use the team tray to keep track of your roster.
7. After the draft, return to the lobby. Guests ready up, and the host clicks **Start Game**.

**F8** still opens the draft screen. A completed draft is kept if the host changes the deck or balance before starting the match. **Restart draft** starts over, so don't use it just to review your roster.

## How the draft works

The default is **three packs of nine Jokers per player**, with **one pick per turn**. Pick a Joker, pass the pack, and repeat until the packs are empty. Everyone finishes with **27 Jokers in their pool**.

Passing direction alternates between packs: packs 1 and 3 go one way; packs 2 and 4 go the other. The draft is shuffled fresh each time. Jokers that weren't included in the draft are unavailable through the normal roster-restricted sources for everyone.

The host can choose **1–4 packs**, **1 or 2 picks per turn**, and a pick timer. Packs 1–3 contain nine Jokers each; the optional fourth pack contains eight, giving each player a 35-Joker roster. Your pool is a list of Jokers you can find during the run—you don't start with all of them equipped.

## How the match works

- Everyone starts with **four lives**.
- **Ante 1** uses the normal Small Blind, Big Blind, and Boss Blind.
- From **Ante 2 onward**, each ante ends with PvP after the Small and Big Blinds.
- With **three or four players remaining**, anyone below the final average PvP score loses a life. Meeting the average is enough.
- Once only **two players remain**, the match uses normal **1v1 scoring**, including the multiplayer mod's early-finish behavior.
- The last player with lives wins.

## Your Joker pool

**Shops, Buffoon packs, Judgment, and Riff-Raff** draw from your drafted roster. View and sort your roster through the **Joker Collection** during a Burglar run.

A few deliberate exceptions:

- **Wraith** can give any Rare Joker, even one you didn't draft.
- **The Soul** keeps its usual Legendary behavior.
- **Showman** is Rare and isn't draftable, so Wraith can still find it.
- **Matador, Mr. Bones, and Luchador** aren't in the draft.
- Once **Gros Michel** goes extinct, it won't return to that player's shop pool.

Getting a Joker through Wraith or The Soul doesn't add it to your drafted shop pool.

## Try the draft by yourself

Open **Mods → Burglar → Config → Local development draft**. Choose two or four seats and start a draft. You control each seat in turn, so you can try the picks, pack passing, timers, and roster controls without getting a group together.

Afterward, you can assign a seat's pool to a **new normal run outside multiplayer lobbies**. Use **Disarm future runs** when you're finished testing so future solo runs return to normal. This mode doesn't test online connections or multiplayer scoring.

## Spectating — Spectator edition only

After losing all your lives in a four-player match, **stay in the lobby** and click **Watch remaining players** on the results screen. **F9** is also a shortcut. Choose a survivor with the Previous/Next controls.

The feed starts at a shop or blind-selection checkpoint and uses a delay of at least five seconds. It shows the watched player's board, hand, shop offers, packs, and changing card areas. Survivors don't have to press anything.

This is a reconstructed view from game snapshots, not a screen share or full replay. Some quick actions and animations may not appear. It is still experimental. Two-player matches end when someone is eliminated, so there's nobody left to spectate. The viewer doesn't support saved-roster bracket matches.

For a scripted preview: **Mods → Burglar → Config → Local spectator preview**. It demonstrates the layout, not a live connection.

## Tournament Mode: draft once, play separate 1v1s, winners face each other. 

After a four-player draft, each player opens **Save roster / bracket 1v1 → Save latest draft roster**. Leave the draft lobby and make separate private **Nemesis** lobbies. Both players must open **Saved-roster 1v1 / bracket → Enable for this lobby**.

Wait for **Rosters confirmed**, then ready up and start. Each match is a fresh run with four lives; only the drafted pool carries over. Pairings are manual. Ordinary PvP doesn't automatically inherit your roster—both players must enable this mode for each lobby.

## Reporting a bug

Include your version and edition, dependency versions, a screenshot or crash report, the ante, how many players were left, and what happened just before the problem. Mention whether you were hosting.

For more detail, turn on **Mods → Burglar → Config → Diagnostics**, reproduce the issue, and use **Copy diagnostic log**. Logs are local and aren't uploaded automatically. The existing folder remains `%AppData%\Balatro\draftout-diagnostics` for compatibility.

## Credits

- **Cjpep** — development and implementation (kappa).
- **Fantom_Balatro** — the original idea for bringing a Magic-style Joker draft to Balatro. Burglar started with his concept.
- **NightmareBalatro, AustereGenie388, PatientEscape38, and UnseenExplosion** — playtesting, feedback, and helping find the things that broke.
- **GPT-6 Astra** — Made literally all of this.

Thanks to the developers of **MultiplayerAPI, MultiplayerPvP, Steamodded, and Lovely** for the tools this runs on. The draft takes inspiration from **Magic: The Gathering**; the runs are still very much Balatro.

## Source and releases

The code uses the MIT license. The bundled Bungee font retains its license in `assets/fonts/OFL.txt`.

Run `python tools/build_release.py` from a source checkout to build both player editions and the source ZIP. The source bundle includes a release guide and validation notes in `docs/`.

The public name, install folder, manifest filename, and module folder are **Burglar**. Internal `Draftout`/`draftout` identifiers remain where used by saves, asset keys, callbacks, and multiplayer messages. They are intentional; renaming them isn't necessary to install or play.
