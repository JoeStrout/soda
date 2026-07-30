# Archived SDL Implementation

This is the original C++/SDL implementation of Soda, kept here for reference
while the engine is rewritten as a MiniScript library on top of
[raylib-miniscript](https://github.com/JoeStrout/raylib-miniscript).

**It no longer builds** — the vendored `MiniScript/` and `editline/` sources it
depended on were removed (they live upstream, and remain in this repo's git
history if ever needed). Nothing here is part of the current engine.

This directory is a temporary holding pen. Once the rewrite covers the API in
`../tests`, it will be deleted; git history is the permanent archive.

## What was where

The API was defined in `SodaIntrinsics.cpp` — mostly declarations of the
built-in classes and functions game code calls. The actual work lived in the
`SdlGlue` namespace, split between `SdlGlue.cpp` and `SdlAudio.cpp`. Soda also
used shell intrinsics from command-line MiniScript, in `ShellIntrinsics.cpp`.
