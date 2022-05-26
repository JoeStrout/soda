# Welcome to Soda
![Soda logo](soda/images/soda-128.png)

The Soda Game Engine is an open-source cross-platform game engine built around the [MiniScript](https://miniscript.org) programming language.

Soda is intended to be _easy_ and _fun_, just like MiniScript itself.

### Status

Soda is in the "early prototype" stage.  It works, but building it requires a fair bit of expertise.  Current functionality is good enough to start building sprite-based games, including:

* loading sprite images or sheets from disk
* sprite scaling, rotation, tint
* text display
* keyboard and game controller input
* window size, background color, and fullscreen switch
* sounds/music, including volume, pitch, stereo pan, and looping

You can build just about any 80s-style game with this feature set!  However it's worth pointing out the major features still on the [To-Do list](TODO.md):

* tile display
* pixel-level drawing
* networking

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

Soda is built on top of SDL, the same framework used in many commercial games.

### How to Help

We need developers!  We also need designers, potential users, and even people who just want to offer words of encouragement.  Contact me (Joe Strout) through any of the community links on the [MiniScript web site](https://miniscript.org), and let's see what we can do together!
