//
//  SdlGlue.cpp
//  soda
//
//  Created by Joe Strout on 7/29/21.
//

#include "SdlGlue.h"
#include <SDL2/SDL.h>
#include <SDL2_image/SDL_image.h>
#include <stdlib.h>
#include "SodaIntrinsics.h"

using namespace MiniScript;

struct Color {
	Uint8 r;
	Uint8 g;
	Uint8 b;
	Uint8 a;
};

namespace SdlGlue {

// public data
bool quit;

// private data
static SDL_Window *mainWindow;
static SDL_Renderer *mainRenderer;
static int windowWidth = 960;
static int windowHeight = 640;
static Color backgroundColor = {0, 0, 100, 255};
static Dictionary<String, Sint32, hashString> keyNameMap;	// maps Soda key names to SDL key codes
static Dictionary<Sint32, bool, hashInt> keyDownMap;	// makes SDL key codes to whether they are currently down

// forward declarations of private methods:
bool CheckFail(int resultCode, const char *callName);
bool CheckNotNull(void *ptr, const char *context);
void DrawSprites();
void SetupKeyNameMap();

//--------------------------------------------------------------------------------
// Public method implementations
//--------------------------------------------------------------------------------

// Initialize SDL and get everything ready to go.
void Setup() {
	if (CheckFail(SDL_Init(SDL_INIT_VIDEO | SDL_INIT_JOYSTICK), "SDL_Init")) return;
	
	if (!SDL_SetHint( SDL_HINT_RENDER_SCALE_QUALITY, "1")) {
		printf( "Warning: Linear texture filtering not enabled!" );
	}

	// Initialize PNG loading
	int imgFlags = IMG_INIT_PNG | IMG_INIT_JPG;
	if (!(IMG_Init(imgFlags) & imgFlags)) {
		printf( "SDL_image could not initialize! SDL_image Error: %s\n", IMG_GetError());
	}

	mainWindow = SDL_CreateWindow( "Soda", SDL_WINDOWPOS_UNDEFINED, SDL_WINDOWPOS_UNDEFINED, windowWidth, windowHeight, SDL_WINDOW_SHOWN );
	if (CheckNotNull(mainWindow, "mainWindow")) return;

	// Create renderer (hardware-accelerated and vsync'd) for the window
	mainRenderer = SDL_CreateRenderer(mainWindow, -1, SDL_RENDERER_ACCELERATED | SDL_RENDERER_PRESENTVSYNC);
	if (CheckNotNull(mainRenderer, "mainRenderer")) return;
	
	SetupKeyNameMap();
}


// Clean up and shut down SDL for program exit.
void Shutdown() {
	SDL_DestroyRenderer(mainRenderer); mainRenderer = NULL;
	SDL_DestroyWindow(mainWindow); mainWindow = NULL;
//	IMG_Quit();
	SDL_Quit();
}


// Pump events and otherwise service whatever's going on in SDL land.
void Service() {
	// Handle events
	SDL_Event e;
	while (SDL_PollEvent(&e) != 0) {
		if (e.type == SDL_QUIT) quit = true;
		else if (e.type == SDL_KEYDOWN) {
			keyDownMap.SetValue(e.key.keysym.sym, true);
		} else if (e.type == SDL_KEYUP) {
			keyDownMap.SetValue(e.key.keysym.sym, false);
		}
	}

	// Update screen
	SDL_SetRenderDrawColor(mainRenderer, backgroundColor.r, backgroundColor.g, backgroundColor.b, backgroundColor.a);
	SDL_RenderClear(mainRenderer);
	DrawSprites();
	SDL_RenderPresent(mainRenderer);
}

bool IsKeyPressed(MiniScript::String keyName) {
	Sint32 keyCode = keyNameMap.Lookup(keyName, 0);
	if (keyCode == 0) return false;
	return keyDownMap.Lookup(keyCode, false);
}

//--------------------------------------------------------------------------------
// Private method implementations
//--------------------------------------------------------------------------------

void SetupKeyNameMap() {
	// most printable keys are the same in SDLK...
	for (char c=' '; c < 'A'; c++) keyNameMap.SetValue(String(c), c);
	for (char c='['; c <= '~'; c++) keyNameMap.SetValue(String(c), 0);
	
	// then we have all the special keys
	keyNameMap.SetValue("left", SDLK_LEFT);
	keyNameMap.SetValue("right", SDLK_RIGHT);
	keyNameMap.SetValue("up", SDLK_UP);
	keyNameMap.SetValue("down", SDLK_DOWN);
	// (etc.)
}

void DoSdlTest() {
	printf("DoSdlTest()\n");
	
	// Clear screen to a random color
	backgroundColor.r = (Uint8)(rand() & 0xFF);
	backgroundColor.g = (Uint8)(rand() & 0xFF);
	backgroundColor.b = (Uint8)(rand() & 0xFF);
}

void DrawSprites() {
	MiniScript::ValueList sprites = spriteList.GetList();
	for (int i=0; i<sprites.Count(); i++) {
		MiniScript::Value spVal = sprites[i];
		if (spVal.type != MiniScript::ValueType::Map) continue;
		MiniScript::ValueDict spMap = spVal.GetDict();
		int x = round(spMap.Lookup("x", MiniScript::Value::zero).DoubleValue());
		int y = round(spMap.Lookup("y", MiniScript::Value::zero).DoubleValue());
		
		SDL_Rect fillRect = { x-50, windowHeight-y-50, 100, 100 };
		SDL_SetRenderDrawColor(mainRenderer, 0xCC, 0xCC, 0x00, 0xFF);
		SDL_RenderFillRect(mainRenderer, &fillRect);
	}
}

bool CheckFail(int resultCode, const char *context) {
	if (resultCode >= 0) return false;
	printf("Failed: %s (result code %d)\n", context, resultCode);
	return true;
}

bool CheckNotNull(void *ptr, const char *context) {
	if (ptr != NULL) return false;
	printf("Unexpected NULL: %s\n", context);
	return true;
}

}	// end of namespace SdlGlue
