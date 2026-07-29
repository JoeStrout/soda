# Contributing to Soda

Contributions are very welcome.  See TODO.md for a prioritized wish list.

## Code Overview

Soda is written in MiniScript.  There is no compiler and no build step — edit a
file in `lib/`, re-run your game, and you're testing your change.

- **lib/** — the engine.  `soda.ms` is the entry point users get via
  `import "soda"`; it shadows `yield` and `wait` so that ordinary Mini
  Micro-style code updates and renders each frame, even though raylib
  underneath is immediate-mode.
- **demos/** — example games.
- **tests/** — scripts exercising the API.  These came from the SDL
  implementation and serve as the spec for the rewrite.  Never name one after a
  module in `lib/`; it would shadow it (see BUILDING.md).
- **assets/** — images and sounds shipped with Soda.
- **archive/** — the retired C++/SDL implementation, kept for reference until
  the rewrite catches up.  Don't send patches for it.

See [BUILDING.md](BUILDING.md) for how to set up the raylib-miniscript host and
run a game, including why `lib/` has to sit next to the script being run.

## Coding Standards

Follow the formatting and style of the existing code.  In particular:

1. Indent with tabs, not spaces.  How wide these tabs appear in your editor is
   up to you.

2. **All APIs should mimic [Mini Micro](https://miniscript.org/wiki/Mini_Micro)
   wherever possible.**  When in doubt about a name, a parameter order, or a
   default, do what Mini Micro does — even if you'd have designed it otherwise.
   Compatibility is the point of the project.

3. Comment the *why*, not the *what*.  MiniScript is readable enough that
   restating the code adds noise.
