//
//  SdlGlue.cpp
//	This module forms the interface between SDL and the rest of Soda.  It handles all
//	the low-level SDL stuff (except for things complex enough to be split out into
//	their own module, such as audio).
//
//  Created by Joe Strout on 7/29/21.
//

#include "SdlGlue.h"
#include "SdlAudio.h"
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
Value magicHandle("_handle");


// private data
static SDL_Window *mainWindow;
static SDL_Renderer *mainRenderer;
static int windowWidth = 960;
static int windowHeight = 640;
static Color backgroundColor = {0, 0, 100, 255};
static Dictionary<String, Sint32, hashString> keyNameMap;	// maps Soda key names to SDL key codes
static Dictionary<Sint32, bool, hashInt> keyDownMap;	// makes SDL key codes to whether they are currently down

// forward declarations of private methods:
static bool CheckFail(int resultCode, const char *callName);
static bool CheckNotNull(void *ptr, const char *context);
static int RoundToInt(double d);
static void DrawSprites();
static void SetupKeyNameMap();
static Color ToColor(String s);
static Value NewImageFromSurface(SDL_Surface *surf);

class TextureStorage : public RefCountedStorage {
public:
	TextureStorage(SDL_Surface *surf) : surface(surf), texture(nullptr) {}
	
	virtual ~TextureStorage() {
		SDL_FreeSurface(surface);		surface = NULL;
		SDL_DestroyTexture(texture);	texture = NULL;
	}
	
	SDL_Surface *surface;		// pixel buffer -- always valid
	SDL_Texture *texture;		// texture for rendering: may be null until we render
};

//--------------------------------------------------------------------------------
// Public method implementations
//--------------------------------------------------------------------------------

// Initialize SDL and get everything ready to go.
void Setup() {
	if (CheckFail(SDL_Init(SDL_INIT_VIDEO | SDL_INIT_JOYSTICK | SDL_INIT_AUDIO), "SDL_Init")) return;
	
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
	
	SetupAudio();
}


// Clean up and shut down SDL for program exit.
void Shutdown() {
	SDL_DestroyRenderer(mainRenderer); mainRenderer = NULL;
	SDL_DestroyWindow(mainWindow); mainWindow = NULL;
	IMG_Quit();
	ShutdownAudio();
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
	if (keyName.StartsWith("mouse ")) {
		int num = keyName.Substring(6).IntValue();
		return IsMouseButtonPressed(num);
	}
	Sint32 keyCode = keyNameMap.Lookup(keyName, 0);
	if (keyCode == 0) return false;
	return keyDownMap.Lookup(keyCode, false);
}

bool IsMouseButtonPressed(int buttonNum) {
	int buttons = SDL_GetMouseState(NULL, NULL);
	switch (buttonNum) {
		case 0: return (buttons & SDL_BUTTON(SDL_BUTTON_LEFT)) != 0;
		case 1: return (buttons & SDL_BUTTON(SDL_BUTTON_RIGHT)) != 0;
		case 2: return (buttons & SDL_BUTTON(SDL_BUTTON_MIDDLE)) != 0;
		case 3: return (buttons & SDL_BUTTON(SDL_BUTTON_X1)) != 0;
		case 4: return (buttons & SDL_BUTTON(SDL_BUTTON_X2)) != 0;
	}
	return false;
}

int GetMouseX() {
	int x;
	SDL_GetMouseState(&x, NULL);
	return x;
}

int GetMouseY() {
	int y;
	SDL_GetMouseState(NULL, &y);
	return windowHeight - y;
}

Value NewImageFromSurface(SDL_Surface *surf) {
	// Create and return a new Image object from the given pixel buffer.
	if (surf == NULL) return Value::null;
	
	ValueDict inst;
	inst.SetValue(Value::magicIsA, imageClass);
	inst.SetValue(magicHandle, Value::NewHandle(new TextureStorage(surf)));
	inst.SetValue("width", surf->w);
	inst.SetValue("height", surf->h);

	return inst;
}

Value LoadImage(MiniScript::String path) {
	return NewImageFromSurface(IMG_Load(path.c_str()));
}

Value GetSubImage(MiniScript::Value image, int left, int bottom, int width, int height) {
	// Get an Image that represents a rectangular portion of a given image.

	// First, get our image storage out of the handle in the MiniScript object.
	if (image.type != ValueType::Map) return Value::null;
	Value textureH = image.Lookup(magicHandle);
	if (textureH.type != ValueType::Handle) return Value::null;
	
	// ToDo: how do we be sure the data is specifically a TextureStorage?
	// Do we need to enable RTTI, or use some common base class?
	TextureStorage *storage = ((TextureStorage*)(textureH.data.ref));
	if (storage == nullptr) return Value::null;

	// Start by creating a surface of the appropriate size.
	SDL_Surface *newSurf = SDL_CreateRGBSurfaceWithFormat(0,
		  width, height,
		  SDL_BITSPERPIXEL(storage->surface->format->format),
		  storage->surface->format->format);
	if (newSurf == nullptr) {
		printf("GetSubImage: couldn't create sub-surface: %s\n", SDL_GetError());
		return Value::null;
	}
	
	// Then, copy the pixel data out of this one into that one.
	SDL_Rect srcRect = {left, storage->surface->h - bottom - height, width, height};
	SDL_BlitSurface(storage->surface, &srcRect, newSurf, NULL);
	
	// Finally, return the new surface as an Image.
	return NewImageFromSurface(newSurf);
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

int RoundToInt(double d) {
	return (int)round(d);
}

Uint8 HexDigitVal(char c) {
	if (c >= '0' && c <= '9') return c - '0';
	if (c >= 'a' && c <= 'f') return c - 'a' + 10;
	if (c >= 'A' && c <= 'F') return c - 'A' + 10;
	return 0;
}

Uint8 HexDigitsToByte(String s, size_t indexB=0) {
	if (s.LengthB() < indexB+1) return 0;
	return (HexDigitVal(s[indexB]) << 4) | HexDigitVal(s[indexB+1]);
}

Color ToColor(String s) {
	Color result;
	if (s.LengthB() < 7 || s[0] != '#') return result;
	result.r = HexDigitsToByte(s, 1);
	result.g = HexDigitsToByte(s, 3);
	result.b = HexDigitsToByte(s, 5);
	if (s.LengthB() < 9) result.a = 255;
	else result.a = HexDigitsToByte(s, 7);
	return result;
}

void DrawSprites() {
	MiniScript::ValueList sprites = spriteList.GetList();
	for (int i=0; i<sprites.Count(); i++) {
		Value sprite = sprites[i];
		if (sprite.type != MiniScript::ValueType::Map) continue;
		double x = round(sprite.Lookup("x").DoubleValue());
		double y = round(sprite.Lookup("y").DoubleValue());
		double scale = sprite.Lookup("scale").DoubleValue();
		double rotation = sprite.Lookup("rotation").DoubleValue();
		Color c = ToColor(sprite.Lookup("tint").ToString());

		MiniScript::Value image = sprite.Lookup("image");
		TextureStorage *storage = NULL;
		if (image.type == ValueType::Map) {
			Value textureH = image.Lookup(magicHandle);
			if (textureH.type == ValueType::Handle) {
				// ToDo: how do we be sure the data is specifically a TextureStorage?
				// Do we need to enable RTTI, or use some common base class?
				storage = ((TextureStorage*)(textureH.data.ref));
			}
		}
		if (storage == nullptr) continue;
		
		if (storage->texture == nullptr) {
			storage->texture = SDL_CreateTextureFromSurface(mainRenderer, storage->surface);
			if (storage->texture == nullptr) continue;
			SDL_SetTextureBlendMode(storage->texture, SDL_BLENDMODE_BLEND);
		}
		double w = storage->surface->w*scale, h = storage->surface->h*scale;
		
		SDL_Rect destRect = { RoundToInt(x-w/2), windowHeight-RoundToInt(y+h/2), RoundToInt(w), RoundToInt(h) };

		SDL_SetTextureColorMod(storage->texture, c.r, c.g, c.b);
		SDL_SetTextureAlphaMod(storage->texture, c.a);
		SDL_RenderCopyEx(mainRenderer, storage->texture, NULL, &destRect, rotation, NULL, SDL_FLIP_NONE);
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
