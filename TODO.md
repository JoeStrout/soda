Our current goal is to get Soda to a state where it can be used to create real 2D games, probably retro-style arcade games that rely entirely on sprites, as quickly as possible.  The High Priority features below will get us there.  The subsequent Medium and Low priority features are ones we want to have, but are less urgent.

Note that **all APIs should mimic [Mini Micro](https://miniscript.org/wiki/Mini_Micro)** wherever possible.

# High Priority

- ~~basic sprite support~~
- ~~basic sound support~~
- ~~key.pressed~~
- ~~mouse.x, mouse.y, mouse.button~~
- ~~joystick/gamepad support, including key.axis and buttons~~
- ~~make file.loadImage return an actual `Image` object~~
- ~~Image.getImage (so you can carve up a sprite sheet)~~
- ~~full support for Sprite.tint including alpha~~
- ~~Sound.loop, Sound.stop, Sound.stopAll~~
- ~~basic screen handling: fullscreen mode, window size, window.backColor~~
- manual builds for Mac, Windows, Linux (PC), and Raspberry Pi

# Medium Priority

- Display class, display(n),  Display.install
- ~~Bounds class, with its connections to Sprite~~
- ~~Image.pixel, Image.setPixel~~
- SolidColor display
- Text display (done?)
- PixelDisplay (in progress)
- TileDisplay
- import
- sound synthesis (Sound.init, Sound.mix, etc.)
- clear/simple build system for Windows and RPi
- Linux (especially RPi) builds that work without X11
- allow control-C to break a running program and drop you into the REPL

# Low Priority

- font class, with loading from truetype and bitmap font files (or maybe just support BmfFont?)
- `http` class
- loading a script from a URL
- build for the web (see [this thread](https://discourse.libsdl.org/t/more-info-needed-on-converting-sdl2-to-web-encripten/28584/6), [this write-up](http://main.lv/writeup/web_assembly_sdl_example.md), and [this useful series](https://www.jamesfmackenzie.com/2019/11/30/whats-is-webassembly-hello-world/)).

# Future Features

- real-time networking
