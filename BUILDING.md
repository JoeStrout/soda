# How to Build Soda

Soda is a command-line program written in C++ and using [SDL](https://www.libsdl.org/).  On most systems the build is fairly straightforward once the SDL libraries are setup.

## Build Steps **Windows**

1. Install the [Visual Studio Command-Line Tools](https://visualstudio.microsoft.com/downloads/#build-tools-for-visual-studio-2022).
2. Run the **Developer Command Prompt for VS** from start. 
3. Clone this repository in `C:\` folder or download this repository as a zip, and  extract the contents  to `C:\` drive.
4. Download VC release versions of [**SDL2**](https://github.com/libsdl-org/SDL/releases) , [**SDL2_image**](https://github.com/libsdl-org/SDL_image/releases) and [**SDL2_mixer**](https://github.com/libsdl-org/SDL_mixer/releases) for example sdl-devel-vc.zip. (Make sure to download the SDL2 versions and not SDL3 versions) 
5. Unzip all three libraries.
6. Create a folder named `SDL2` at `C:\` and Copy the contents of the zip files to this folder. for example 
7. For example your directory structure would be something like this.
   - SDL2
      - SDL2_2
      - SDL2_image
      - SDL2_mixer
8.  Place this SDL2 folder in `C:\soda\src`
9.  Type `build_win.bat` in the command prompt to do the build.
10. Place **SDL2.dll**, **SDL2_image.dll**, and **SDL2_mixer.dll** in `C:\soda` and launch either  `soda_x64.exe ".\tests\balls.ms"` or `soda_x86.exe ".\tests\balls.ms"`
    
## Build Steps **Linux**

1. run `sudo apt-get install libsdl2-dev | apt-get install libsdl2-image-dev | apt-get install libsdl2-mixer-dev` in a terminal window. This will install the required libraries.
2. Clone this repository in a folder or download this repository as a zip, and  extract the contents. 
3. `cd soda` to change to the _soda_ subdirectory next to this document. (soda-main\soda)
4. `./configure` to run the _configure_ script. This will make a new build directory.
5. `cd Build` to change to the _soda/Build_ subdirectory.
6. `make` to build the soda executable.  If all goes well, you will now have a _soda_ executable in the Build directory.
7. `sudo make install` to copy the executable into _/usr/local/bin_. This will allow  you  to run soda like any other program by just typing soda in your terminal window.
8. run soda `./tests/balls.ms` to run this built in example (You can browse and test the other examples on your own).

## Build Steps **Mac**
1. Install Homebrew if you don't already have it. Open your terminal and run the command `brew install sdl2 sdl2_image sdl2_mixer`
2. Clone this repository in a folder or download this repository as a zip, and  extract the contents. 
3. `cd soda` to change to the _soda_ subdirectory next to this document. (soda-main\soda)
4. `./configure` to run the _configure_ script. This will make a new build directory.
5. `cd Build` to change to the _soda/Build_ subdirectory.
6. `make` to build the soda executable.  If all goes well, you will now have a _soda_ executable in the Build directory.
7. `sudo make install` to copy the executable into _/usr/local/bin_. This will allow  you  to run soda like any other program by just typing soda in your terminal window.
8. run soda `./tests/balls.ms` to run this built in example (You can browse and test the other examples on your own).