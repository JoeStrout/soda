# How to Build Soda

Soda is a library of MiniScript files. **There is nothing to compile.**

What you do need is the *host*: the raylib-miniscript executable that runs
MiniScript code with raylib bindings attached. During development the `./soda`
launcher finds that host through a symlink and runs your game with it.

## Quick start

```
./soda demos/whatever.ms
```

The first time, if the host isn't set up yet, the launcher will say so and
offer to link an existing binary, download a prebuilt one, or build it from a
sibling checkout. Take whichever option applies and re-run.

## Setting up the host by hand

The launcher looks for a `raylib-miniscript` symlink in this directory pointing
directly at the host executable. To make it yourself:

```
ln -s /path/to/raylib-miniscript/build/raylib-miniscript raylib-miniscript
```

The symlink is gitignored, since the right target differs per machine.

## Building the host from source

Only needed if you're also working on the host itself, or no prebuilt binary
exists for your platform. Clone
[raylib-miniscript](https://github.com/JoeStrout/raylib-miniscript) next to
this repo and follow its README — it needs a `MiniScript2` symlink, the raylib
submodule, and a transpile step, then `scripts/build-desktop.sh`. Once
`build/raylib-miniscript` exists, `./soda` will offer to link it for you.

## Why `lib/` has to sit next to your game

The host's import search path is fixed at startup and cannot be overridden from
the shell or from script. It is:

1. `$MS_SCRIPT_DIR` — the directory of the script being run
2. `$MS_SCRIPT_DIR/lib`
3. `$MS_EXE_DIR/assets/lib`

So `import "soda"` resolves only when `lib/` is a sibling of the running
script. `demos/` and `tests/` each hold a `lib` symlink back to `../lib` for
this reason, and a distribution package ships `lib/` alongside the game. If you
start a game in a new directory, give it a `lib` symlink too.

**Watch out for name collisions.** Because entry 1 comes first, a script
sitting next to your game *shadows* the engine module of the same name. A file
called `mouse.ms` in `tests/` means that every `import "mouse"` anywhere in the
engine gets your test instead of `lib/mouse.ms` — and the failure surfaces
somewhere else entirely, as an undefined identifier deep in an unrelated
module.  (This is why the key and mouse tests are named `testKey.ms` and
`testMouse.ms`.)  Don't name a demo or test after a module in `lib/`.

You will also see one `WARNING: FILEIO: ... Failed to open text file` per
import, for the miss on entry 1 before the hit on entry 2. That is normal and
not an error.

## The old SDL build

The C++/SDL implementation and its makefiles now live in `archive/`, and no
longer build. See `archive/README.md`.
