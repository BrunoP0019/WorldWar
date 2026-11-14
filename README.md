# WorldWar

A real-time territory-conquest strategy game for Roblox. WorldWar is a fork of
[RoWorld](https://github.com/lukechatton/roworld) (Snick Co.), which is itself a Roblox port of
[OpenFront](https://github.com/openfrontio/OpenFrontIO). This fork reworks the game's mechanics to
make them more strategic.

## Layout

- `src/shared/Core/`: the match simulation (`Sim*.luau`); every balance number is in `Rules.luau`.
- `src/server/`, `src/client/`: Roblox server and client code (UI in `src/client/UI/`).
- `tests/`: Lune tests for the simulation, protocol and UI logic.
- `default.project.json`: the Rojo project to sync into Roblox Studio.

## Running the tests

Tests run with [Lune](https://github.com/lune-org/lune) (0.10). Put the binary at `.bin/lune`, then:

```sh
.bin/lune run tests/stances.luau
```

## Licence

AGPL-3.0 with additional terms; see `LICENSE`. Keep the copyright notices and credits (in-game:
Help → Credits & licence) and keep the source available to players.
