Our current goal is to get Soda to a state where it can be used to create real 2D games, probably retro-style arcade games that rely entirely on sprites, as quickly as possible.  The High Priority features below will get us there.  The subsequent Medium and Low priority features are ones we want to have, but are less urgent.

Note that **all APIs should mimic Mini Micro](https://miniscript.org/wiki/Mini_Micro)** wherever possible.

# High Priority

- ~~basic sprite support~~
- ~~basic sound support~~
- ~~key.pressed~~
- ~~mouse.x, mouse.y, mouse.button~~
- joystick/gamepad support
- changing background color
- make `file.loadImage` return an actual `Image` object
- Image.getImage (so you can carve up a sprite sheet)
- Sound.playLooping, Sound.stop, Sound.stopAll

# Medium Priority

- `Display` class, `display(n)`,  Display.install
- SolidColor display
- Text display
- `import`

# Low Priority

- `http` class
- loading a script from a URL
