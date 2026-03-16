# How to Build Soda

Soda is a command-line program written in C++ and using SDL.  On most systems the build is fairly straightforward once the prerequisites are met.

## Prerequisites

1. Make sure you have a C++ toolchain installed.  Currently, the Linux/Mac makefile assumes this is accessed via a `gcc` command.  You can use `gcc -v` to verify that such a compiler is installed, and check the version number.  On Windows, install the [Visual Studio Command-Line Tools](https://docs.microsoft.com/en-us/cpp/build/walkthrough-compiling-a-native-cpp-program-on-the-command-line?view=vs-2019).

2. Install the **SDL2** , **SDL2_image** and **SDL2_mixer** development libraries.  For details, see:
- https://wiki.libsdl.org/SDL2/Installation
- https://github.com/libsdl-org/SDL_image
- https://github.com/libsdl-org/SDL_mixer

## Build Steps (Mac/Linux)

1. `cd soda` to change to the _soda_ subdirectory (next to this document).
2. `./configure` to run the _configure_ script.  This will detect what platform you are on, and copy the appropriate makefile to the Build directory.
3. `cd Build` to change to the _soda/Build_ subdirectory.
4. `make` to build the soda executable.  If all goes well, you will now have a _soda_ executable in the Build directory.
5. (optional) `sudo make install` to copy the executable into _/usr/local/bin_, making it easily accessible from any directory (assuming this is in your PATH, as is usually the case).
6. (optional) `make clean` to clean intermediate products out of the Build directory.

## Build Steps (Windows)

1. Install build tools .
2. Please store the SDL include file and library file in a location that is compatible with the DeveloperCommandPrompt.
This procedure depends on the environment of the person building it, so I can't go into detail.
However, here are some hints:
If you store the SDL files in the storage location for include files and library files associated with the environment variable "VCToolsInstallDir", they will be recognized.
Alternatively, you may want to store your include and library files in "soda/src".
In either case, the include files should be placed in the SDL2 folder.
3. Launch **DeveloperCommandPrompt for VC 20xx**
4. command `cd soda` to change to the _soda_ subdirectory (next to this document).
5. command `build_win.bat`
6. The executable file will be written into the soda folder.

When you run this program, it will display the execution location of the tool 
and the bitness of the exe file it will generate.
If an include or library cannot be loaded during the build, 
look at the message that is displayed and check whether the library 
or include file exists in the folder associated with the executable file.

### Launch Soda
Place SDL2.dll, SDL2_image.dll, and SDL2_mixer.dll in the same folder as the executable file and launch either soda_x86.exe or soda_x64.exe.

### Warning. 
That should do it _if_ the SDL paths are all sorted out.  
Which they probably aren't.  This is a work in progress.
