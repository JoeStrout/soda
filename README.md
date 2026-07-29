# Welcome to Soda
![Soda logo](assets/images/soda-128.png)

The Soda Game Engine is an open-source cross-platform game engine built around the [MiniScript](https://miniscript.org) programming language.

Soda is intended to be _easy_ and _fun_, just like MiniScript itself.

### Status

**Soda is being rewritten.**

The original Soda was a C++ program built on SDL, which proved more difficult
than expected — hard to build, hard to extend, and hard to ship.  As of 2026 we
are rebuilding Soda as a library of MiniScript files running on
[raylib-miniscript](https://github.com/JoeStrout/raylib-miniscript), a
MiniScript host with raylib bindings.  The result will be more feature-rich,
far easier to build, and easier to contribute to — a bug in the sprite system
is now a bug in a `.ms` file you can edit and re-run instantly.

The SDL implementation has moved to [archive/](archive/) and no longer builds.
The rewrite is just beginning; `lib/` is where it lives, and the scripts in
[tests/](tests/) define the API it has to reproduce.

The feature set we are rebuilding toward, all of which the SDL version reached:

* loading sprite images or sheets from disk
* sprite scaling, rotation, tint
* text display
* keyboard and game controller input
* window size, background color, and fullscreen switch
* sounds/music, including volume, pitch, stereo pan, and looping

...plus the major features still on the [To-Do list](TODO.md): tile display,
pixel-level drawing, and networking.

### Documentation

Want to write your first Soda game?  That's great!  Be sure you have the [MiniScript Quick Reference](https://miniscript.org/files/MiniScript-QuickRef.pdf), and then see the [Soda category at the MiniScript wiki](https://miniscript.org/wiki/Category:Soda) for information about the additional functions used with Soda.

Because Soda is so new, documentation is a bit thin.  So check out the community resources at [MiniScript.org](https://miniscript.org/) to find others who will be more than happy to help as you develop your game.

### Soda Design Objectives

* easy to install: ideally, a single prebuilt binary on most systems
* easy to use: just `soda myGame.ms` to run
* good performance: hardware acceleration, even on Raspberry Pi
* supported platforms: at least Windows, Mac, Linux (PC), and Raspberry Pi
* support for both text-based console games, and graphical games
* support for keyboard, mouse, and gamepad input
* support for audio in WAV or OGG format, with control over volume, pan, and speed
* shared APIs with [Mini Micro](https://miniscript.org/MiniMicro) wherever possible

### Underlying Technologies

Soda is written in MiniScript itself, on top of
[raylib-miniscript](https://github.com/JoeStrout/raylib-miniscript) — MiniScript
bindings for [raylib](https://www.raylib.com), a well-supported game library
covering graphics, audio, and input across desktop and the web.

### How to Help

We need developers!  We also need designers, potential users, and even people who just want to offer words of encouragement.  Contact me (Joe Strout) through any of the community links on the [MiniScript web site](https://miniscript.org), and let's see what we can do together!
