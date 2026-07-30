# PORTING YOUR GAME TO SODA

## From "Old" (pre-July 2026) Soda

Prior to July 2026, Soda was a native binary for each platform, written in C++, and built atop SDL.  Now, Soda is built on top of raylib-miniscript, with all the high-level APIs written in MiniScript itself.  The raylib-miniscript executable is typically launched via the `soda` shell script, which will verify the presence of raylib-miniscript and try to help you get it properly downloaded or linked if you don't have it.

But as for your older Soda code, it should pretty much "just work" in the new version, with these exceptions:

1. **You must `import "soda"` at the start of your program.**  This can just go at the top of whatever script is run first when your game begins.  Without it, all of the Soda/Mini Micro APIs will be undefined.  The `soda` module also creates the window, initializes audio output, etc.

2. **`sprites` is no longer a global list.**  Instead, like Mini Micro, you can have multiple SpriteDisplays, so you need to access the sprite list of the display you want.  Typically you could just put `sprites = display(4).sprites` right after the `import "soda"` line if you want it to work like before; or you could embrace the flexibility of referencing the `sprites` list of the desired display wherever you need it.

3. **`print` no longer prints to the text display by default.**  In most games, you're more likely to want `print` to go just to the console, for debugging, than to go to the display players see.  So that's what `print` now does.  If you really do want to print to the game screen, just use `text.print` instead (or assign `print = @text.print` to make `print` do that).

## From Mini Micro

The Soda implementation of the Mini Micro API is much more complete than it was prior to July 2026.  However, it's written in MiniScript 2, which doesn't support intercepting assignments to map keys.  So you'll need to make these adjustments:

- Instead of setting `Display.mode = m`, call `Display.setMode m`.
- Instead of setting `text.row` and/or `text.column`, call `text.setCursor row, col`.
- Instead of setting `TileDisplay.extent`, call `TileDisplay.setExtent`.

Unfortunately if you set those values instead of calling the proper setter methods, it will just silently fail to do what you wanted.  You might want to search for `.mode =`, `.row =`, `.column =`, and `.extent =` in your project and update them accordingly.

## From Some Other Game Engine

It's awesome that you're wanting to rewrite your game in Soda!  Just be aware that Soda (and raylib-miniscript, and MiniScript 2 which these all depend on) is still very new.  We haven't yet made a lot of docs and examples for it.  You might be better off first learning and using [Mini Micro](https://miniscript.org/MiniMicro), which is much more mature.

Documentation for all the Mini Micro/Soda APIs can be found in the [MiniScript wiki](https://miniscript.org/wiki).
