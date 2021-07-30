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
			Sint32 keyCode = e.key.keysym.sym;
			if (keyCode == SDLK_KP_PERIOD) keyCode = SDLK_KP_DECIMAL;	// (normalize this inconsistency)
			keyDownMap.SetValue(keyCode, true);
		} else if (e.type == SDL_KEYUP) {
			Sint32 keyCode = e.key.keysym.sym;
			if (keyCode == SDLK_KP_PERIOD) keyCode = SDLK_KP_DECIMAL;	// (normalize this inconsistency)
			keyDownMap.SetValue(keyCode, false);
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
	keyNameMap.SetValue("[1]", SDLK_KP_1);
	keyNameMap.SetValue("[2]", SDLK_KP_2);
	keyNameMap.SetValue("[3]", SDLK_KP_3);
	keyNameMap.SetValue("[4]", SDLK_KP_4);
	keyNameMap.SetValue("[5]", SDLK_KP_5);
	keyNameMap.SetValue("[6]", SDLK_KP_6);
	keyNameMap.SetValue("[7]", SDLK_KP_7);
	keyNameMap.SetValue("[8]", SDLK_KP_8);
	keyNameMap.SetValue("[9]", SDLK_KP_9);
	keyNameMap.SetValue("[0]", SDLK_KP_0);
	keyNameMap.SetValue("[+]", SDLK_KP_PLUS);
	keyNameMap.SetValue("[-]", SDLK_KP_MINUS);
	keyNameMap.SetValue("[*]", SDLK_KP_MULTIPLY);
	keyNameMap.SetValue("[/]", SDLK_KP_DIVIDE);
	keyNameMap.SetValue("[clear]", SDLK_KP_CLEAR);
	keyNameMap.SetValue("[=]", SDLK_KP_EQUALS);
	keyNameMap.SetValue("[.]", SDLK_KP_DECIMAL);	// tricky case: could be KP_PERIOD on some systems! (normalized in Service())
	keyNameMap.SetValue("[clear]", SDLK_KP_CLEAR);
	keyNameMap.SetValue("f1", SDLK_F1);
	keyNameMap.SetValue("f2", SDLK_F2);
	keyNameMap.SetValue("f3", SDLK_F3);
	keyNameMap.SetValue("f4", SDLK_F4);
	keyNameMap.SetValue("f5", SDLK_F5);
	keyNameMap.SetValue("f6", SDLK_F6);
	keyNameMap.SetValue("f7", SDLK_F7);
	keyNameMap.SetValue("f8", SDLK_F8);
	keyNameMap.SetValue("f9", SDLK_F9);
	keyNameMap.SetValue("f10", SDLK_F10);
	keyNameMap.SetValue("f11", SDLK_F11);
	keyNameMap.SetValue("f12", SDLK_F12);
	keyNameMap.SetValue("f13", SDLK_F13);
	keyNameMap.SetValue("f14", SDLK_F14);
	keyNameMap.SetValue("f15", SDLK_F15);
	keyNameMap.SetValue("left shift", SDLK_LSHIFT);
	keyNameMap.SetValue("right shift", SDLK_RSHIFT);
	keyNameMap.SetValue("left ctrl", SDLK_LCTRL);
	keyNameMap.SetValue("right ctrl", SDLK_RCTRL);
	keyNameMap.SetValue("left alt", SDLK_LALT);
	keyNameMap.SetValue("right alt", SDLK_RALT);
	keyNameMap.SetValue("left cmd", SDLK_LGUI);
	keyNameMap.SetValue("right cmd", SDLK_RGUI);
	keyNameMap.SetValue("backspace", SDLK_BACKSPACE);
	keyNameMap.SetValue("tab", SDLK_TAB);
	keyNameMap.SetValue("return", SDLK_RETURN);
	keyNameMap.SetValue("escape", SDLK_ESCAPE);
	keyNameMap.SetValue("space", SDLK_SPACE);
	keyNameMap.SetValue("delete", SDLK_DELETE);
	keyNameMap.SetValue("enter", SDLK_KP_ENTER);
	keyNameMap.SetValue("insert", SDLK_INSERT);
	keyNameMap.SetValue("home", SDLK_HOME);
	keyNameMap.SetValue("end", SDLK_END);
	keyNameMap.SetValue("page up", SDLK_PAGEUP);
	keyNameMap.SetValue("page down", SDLK_PAGEDOWN);
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
