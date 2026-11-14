# WorldWar

A Roblox territory-conquest game: a fork of lukechatton/roworld (itself a port of OpenFront), owned
by Bruno. The goal of the fork is more engaging, more strategic mechanics.

## Working on it

- Gameplay lives in `src/shared/Core/` (pure Luau, no Instances). Balance numbers go in `Rules.luau`,
  never inline. The Sim is deterministic: use `self.rng`, never `math.random`.
- The AI acts only through the same entry points players use (`intent_attack`, `launch_boat`,
  `try_build`, ...). A new mechanic needs AI logic in `SimAI.luau` too, or the bots ignore it.
- A new field on an attack, unit or event must reach the client: `Ev.luau`, the snapshot rows, and
  `GameState.luau`. Rows without the field must still decode.
- Tests: `.bin/lune run tests/<name>.luau` (Lune 0.10). Add a test for every mechanic. On the
  original code `gameplayfixer_ui`, `simsys_structures` and `uiscreens_logic` already fail.
- UI changes can't be checked by the tests: say so, and ask Bruno to try them in Studio.
- Work on a branch per feature; Bruno merges.

## Not ours

- The game was set up for the original RoWorld experience. Product, subscription, universe and
  place ids are zeroed (`Data/Products`, `Data/Subscription`, `Data/Staging`,
  `ServerMain.PROD_UNIVERSE`, `tools/publish.*`) until Bruno creates his own.
- `LobbyHttp` (the lobby service at rofront.snick.co) is Snick Co.'s server: keep it off.
- DataStore and MemoryStore names (`RofrontPurchases_v1`, ...) keep the old name on purpose: they
  are internal, and renaming one later loses saved data.
- `tools/publish.sh` and other tools assume the original author's Mac setup; publish from Studio.
- Licence: AGPL-3.0. Keep the OpenFront and Snick Co. notices in `HelpOverlay.LEGAL`.
