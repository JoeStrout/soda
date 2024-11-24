# How to Build Soda

Soda is a command-line program written in C++ and using SDL.  On most systems the build is fairly straightforward once the prerequisites are met.

## Prerequisites

1. Make sure you have a C++ toolchain installed.  Currently, the Linux/Mac makefile assumes this is accessed via a `gcc` command.  You can use `gcc -v` to verify that such a compiler is installed, and check the version number.  On Windows, install the [Visual Studio Command-Line Tools](https://docs.microsoft.com/en-us/cpp/build/walkthrough-compiling-a-native-cpp-program-on-the-command-line?view=vs-2019).

2. Install the **SDL2** and **SDL2_image** development libraries.  For details, see:
- https://wiki.libsdl.org/Installation
- https://github.com/libsdl-org/SDL_image

## Build Steps (Mac/Linux)

1. `cd soda` to change to the _soda_ subdirectory (next to this document).
2. `./configure` to run the _configure_ script.  This will detect what platform you are on, and copy the appropriate makefile to the Build directory.
3. `cd Build` to change to the _soda/Build_ subdirectory.
4. `make` to build the soda executable.  If all goes well, you will now have a _soda_ executable in the Build directory.
5. (optional) `sudo make install` to copy the executable into _/usr/local/bin_, making it easily accessible from any directory (assuming this is in your PATH, as is usually the case).
6. (optional) `make clean` to clean intermediate products out of the Build directory.

## Build Steps (Windows)

0. Run the **Developer Command Prompt for VS**.
1. `cd soda` to change to the _soda_ subdirectory (next to this document).
2. `cd src` to move to the _soda\src_ directory.
3. `cl /EHsc /wd4068 *.cpp MiniScript/*.cpp /Fesoda.exe`

That should do it _if_ the SDL paths are all sorted out.  Which they probably aren't.  This is a work in progress.
