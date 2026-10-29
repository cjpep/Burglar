# Lovely 0.10 compatibility review — Burglar 0.20.6

Credits: Cjpep and Fantom_Balatro.

Burglar declares Lovely >=0.9.0 and contains no direct Lovely API calls or TOML
patches. Its code still uses the existing Steamodded/Multiplayer interfaces.
The actual Steamodded beta-1814a version parser accepts the supplied mod and
multiplayer dependency constraints with Lovely 0.10.0. Fields in 100 supplied
Steamodded beta-1814a / MultiplayerAPI 1.0.0 / MultiplayerPvP 1.0.0 patch
manifests are present in the pinned Lovely v0.10.0 Rust patch schema.

Official release: https://github.com/ethangreen-dev/lovely-injector/releases/tag/v0.10.0
Pinned schema: https://github.com/ethangreen-dev/lovely-injector/tree/v0.10.0/crates/lovely-core/src/patch

Windows: use the official Windows ZIP. Lovely 0.10 changes the proxy DLL name
from version.dll to winmm.dll. Remove the old Lovely version.dll and place the
new winmm.dll beside Balatro.exe. This mod archive contains neither DLL.

These are source-level checks, not execution of Lovely's patches or a Windows
launch. Other installed mods and different Multiplayer versions can still have
independent compatibility requirements. The existing minimum remains 0.9.0.
