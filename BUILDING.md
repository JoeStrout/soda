# How to Build Soda

Soda is a command-line program written in C++ and using SDL.  On most systems the build is fairly straightforward once the prerequisites are met.

## Prerequisites

1. Make sure you have a C++ toolchain installed.  Currently, the makefile assumes this is accessed via a `gcc` command.  Unix-like systems can use `gcc -v` to verify that such a compiler is installed, and check the version number.

2. Install the SDL2 libraries.  See https://wiki.libsdl.org/Installation for details.

## Build Steps (Mac/Linux)

1. `cd soda` to change to the _soda_ subdirectory
2. `./configure` to run the _configure_ script.  This will detect what platform you are on, and copy the appropriate makefile to the Build directory.
3. `cd Build` to change to the _soda/Build_ subdirectory.
4. `make` to build the soda executable.  If all goes well, you will now have a _soda_ executable in the Build directory.
5. (optional) `sudo make install` to copy the executable into _/usr/local/bin_, making it easily accessible from any directory (assuming this is in your PATH, as is usually the case).
6. (optional) `make clean` to clean intermediate products out of the Build directory.

## Build Steps (Windows)

- ToDo.
