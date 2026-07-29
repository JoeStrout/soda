# Soda Library

This is the heart of Soda: a set of MiniScript modules implementing a
[Mini Micro](https://miniscript.org/MiniMicro)-compatible API on top of the
[raylib-miniscript](https://github.com/JoeStrout/raylib-miniscript) host.

A game gets the whole engine with one line:

```
import "soda"
```

Among other things, that shadows `yield` and `wait` so that they update all
object state and render the display stack — which is what lets ordinary Mini
Micro-style code (`while true; yield; end while`) work unchanged, even though
raylib itself is immediate-mode.

## How this directory gets found

The host's import search path is fixed (see `MoreIntrinsics.cpp` in
raylib-miniscript):

1. `$MS_SCRIPT_DIR` — the directory of the script being run
2. `$MS_SCRIPT_DIR/lib`
3. `$MS_EXE_DIR/assets/lib`

It cannot be overridden from the shell or from script. So **`lib/` must sit
next to the game being run.** That is why `demos/` and `tests/` each contain a
`lib` symlink back to this directory, and why a distribution package ships
`lib/` alongside the game.
