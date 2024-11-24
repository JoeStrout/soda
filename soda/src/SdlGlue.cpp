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
#include "TextDisplay.h"
#include <stdlib.h>
#include "SodaIntrinsics.h"
#include "Color.h"
#include "TextDisplay.h"
#include "PixelDisplay.h"

using namespace MiniScript;

namespace SdlGlue {

// public data
bool quit;
Value magicHandle("_handle");


// private data
static SDL_Window *mainWindow;
static SDL_Renderer *mainRenderer;
static int windowWidth = 960;
static int windowHeight = 640;
static bool isFullScreen = false;
static Color backgroundColor = Color::black;//{0, 0, 100, 255};
static Dictionary<String, Sint32, hashString> keyNameMap;	// maps Soda key names to SDL key codes
static Dictionary<Sint32, bool, hashInt> keyDownMap;	// makes SDL key codes to whether they are currently down
static SimpleVector<SDL_GameController*> gameControllers;

// forward declarations of private methods:
static int RoundToInt(double d);
static void DrawSprites();
static void SetupKeyNameMap();
static Value NewImageFromSurface(SDL_Surface *surf);
static double GetControllerAxis(SDL_GameController* controller, SDL_GameControllerAxis axis);
void HandleWindowSizeChange(int newWidth, int newHeight);

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
	int init = SDL_Init(SDL_INIT_VIDEO | SDL_INIT_JOYSTICK | SDL_INIT_GAMECONTROLLER | SDL_INIT_AUDIO);
	SdlAssertOK(init);
	if (init < 0) return;
	
	if (!SDL_SetHint( SDL_HINT_RENDER_SCALE_QUALITY, "0")) {
		printf( "Warning: Render scale quality not set!" );
	}

	// Initialize PNG loading
	int imgFlags = IMG_INIT_PNG | IMG_INIT_JPG;
	if (!(IMG_Init(imgFlags) & imgFlags)) {
		printf( "SDL_image could not initialize! SDL_image Error: %s\n", IMG_GetError());
	}

	mainWindow = SDL_CreateWindow( "Soda", SDL_WINDOWPOS_UNDEFINED, SDL_WINDOWPOS_UNDEFINED, windowWidth, windowHeight, SDL_WINDOW_SHOWN );
	SdlAssertNotNull(mainWindow);

	// Create renderer (hardware-accelerated and vsync'd) for the window
	mainRenderer = SDL_CreateRenderer(mainWindow, -1, SDL_RENDERER_ACCELERATED | SDL_RENDERER_PRESENTVSYNC);
	SdlAssertNotNull(mainRenderer);
	
	SetupKeyNameMap();
	for (int i=0; i<SDL_NumJoysticks(); i++) {
		gameControllers.push_back(SDL_GameControllerOpen(i));
		if (gameControllers[i] != nullptr) printf("Opened controller %d\n", i);
	}
	
	SetupAudio();
	SetupTextDisplay(mainRenderer);
	SetupPixelDisplay(mainRenderer);
}


// Clean up and shut down SDL for program exit.
void Shutdown() {
	SDL_DestroyRenderer(mainRenderer); mainRenderer = NULL;
	SDL_DestroyWindow(mainWindow); mainWindow = NULL;
	IMG_Quit();
	ShutdownAudio();
	ShutdownTextDisplay();
	ShutdownPixelSurface();
	VecIterate(i, gameControllers) SDL_GameControllerClose(gameControllers[i]);
	gameControllers.deleteAll();
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
		} else if (e.type == SDL_WINDOWEVENT) {
			if (e.window.event == SDL_WINDOWEVENT_RESIZED || e.window.event == SDL_WINDOWEVENT_SIZE_CHANGED) {
				HandleWindowSizeChange(e.window.data1, e.window.data2);
			}
		}
	}
	
	// Update mouse position
	// (we store mouse x and y as values, rather than functions, so they can be used
	// in any context that needs an XY map, such as Bounds.contains)
	mouseModule.SetValue(xStr, Value(GetMouseX()));
	mouseModule.SetValue(yStr, Value(GetMouseY()));

	// Update screen
	SDL_SetRenderDrawColor(mainRenderer, backgroundColor.r, backgroundColor.g, backgroundColor.b, backgroundColor.a);
	SDL_RenderClear(mainRenderer);
	DrawSprites();
	mainPixelDisplay->Render();
	RenderTextDisplay();
	SDL_RenderPresent(mainRenderer);
}

bool IsKeyPressed(String keyName) {
	if (keyName.StartsWith("mouse ")) {
		int num = keyName.Substring(6).IntValue();
		return IsMouseButtonPressed(num);
	}
	if (keyName.StartsWith("joystick ")) {
		long pos = keyName.LastIndexOfB(" ");
		int buttonNum = keyName.SubstringB(pos+1).IntValue();
		if (buttonNum < 0 || buttonNum >= (int)SDL_CONTROLLER_BUTTON_MAX) return false;
		if (keyName.StartsWith("joystick button ")) { // Check all game controllers!
			VecIterate(i, gameControllers) {
				if (SDL_GameControllerGetButton(gameControllers[i], (SDL_GameControllerButton)buttonNum)) return true;
			}
			return false;
		}
		int joyNum = keyName.SubstringB(9).IntValue() - 1;
		if (joyNum < 0 || joyNum >= gameControllers.size()) return 0;
		SDL_GameController* gc = gameControllers[joyNum];
		if (gc == nullptr) return 0;
		return SDL_GameControllerGetButton(gc, (SDL_GameControllerButton)buttonNum);
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

double GetAxis(String axisName) {
	if (axisName == "Horizontal") {
		// Check arrow keys, then WASD, then all joysticks.
		if (IsKeyPressed("left")) return -1;
		if (IsKeyPressed("a")) return -1;
		if (IsKeyPressed("right")) return 1;
		if (IsKeyPressed("d")) return 1;
		return GetAxis("JoyAxis1");
	}
	if (axisName == "Vertical") {
		// Check arrow keys, then WASD, then all joysticks.
		if (IsKeyPressed("down")) return -1;
		if (IsKeyPressed("s")) return -1;
		if (IsKeyPressed("up")) return 1;
		if (IsKeyPressed("w")) return 1;
		return GetAxis("JoyAxis2");
	}
	if (axisName.StartsWith("JoyAxis")) {
		int axisNum = axisName.SubstringB(7).IntValue() - 1;
		if (axisNum < 0 || axisNum >= (int)SDL_CONTROLLER_AXIS_MAX) return 0;
		double result = 0;
		VecIterate(i, gameControllers) {
			double val = GetControllerAxis(gameControllers[i], (SDL_GameControllerAxis)axisNum);
			if (abs(val) > abs(result)) result = val;
		}
		return result;
	}
	if (axisName.StartsWith("Joy") && axisName.Contains("Axis")) {
		long p = axisName.IndexOfB("Axis");
		int joyNum = axisName.SubstringB(3, p-3).IntValue() - 1;
		if (joyNum < 0 || joyNum >= gameControllers.size()) return 0;
		SDL_GameController* gc = gameControllers[joyNum];
		if (gc == nullptr) return 0;

		int axisNum = axisName.SubstringB(p+4).IntValue() - 1;
		if (axisNum < 0 || axisNum >= (int)SDL_CONTROLLER_AXIS_MAX) return 0;

		return GetControllerAxis(gc, (SDL_GameControllerAxis)axisNum);
	}
	return 0;
}

// Helper method to get a controller axis -- but checking the dpad for LEFTX and LEFTY
// too, which SDL doesn't naturally do, and applying a small dead zone to analog axes.
double GetControllerAxis(SDL_GameController* controller, SDL_GameControllerAxis axis) {
	if (controller == nullptr) return 0;
	if (axis == SDL_CONTROLLER_AXIS_LEFTX) {
	   int dpad = SDL_GameControllerGetButton(controller, SDL_CONTROLLER_BUTTON_DPAD_RIGHT)
		        - SDL_GameControllerGetButton(controller, SDL_CONTROLLER_BUTTON_DPAD_LEFT);
	   if (dpad != 0) return dpad;
   }
   if (axis == SDL_CONTROLLER_AXIS_LEFTY) {
	   int dpad = SDL_GameControllerGetButton(controller, SDL_CONTROLLER_BUTTON_DPAD_UP)
				- SDL_GameControllerGetButton(controller, SDL_CONTROLLER_BUTTON_DPAD_DOWN);
	   if (dpad != 0) return dpad;
   }
	Sint16 value = SDL_GameControllerGetAxis(controller, axis);
	if (value > -300 && value < 300) value = 0;	// (minimal dead zone)
	return value / 32767.0;
}

int GetWindowWidth() {
	int w;
	SDL_GetWindowSize(mainWindow, &w, NULL);
	return w;
}

int GetWindowHeight() {
	int h;
	SDL_GetWindowSize(mainWindow, NULL, &h);
	return h;
}

void SetWindowWidth(int width) {
	windowWidth = width;
	SDL_SetWindowFullscreen(mainWindow, 0);
	SDL_SetWindowSize(mainWindow, windowWidth, windowHeight);
}

void SetWindowHeight(int height) {
	windowHeight = height;
	SDL_SetWindowFullscreen(mainWindow, 0);
	SDL_SetWindowSize(mainWindow, windowWidth, windowHeight);
}

bool GetFullScreen() {
	return isFullScreen;
}

void SetFullScreen(bool fullScreen) {
	if (fullScreen) {
		SDL_SetWindowFullscreen(mainWindow, SDL_WINDOW_FULLSCREEN);
	} else {
		SDL_SetWindowFullscreen(mainWindow, 0);
		SDL_SetWindowSize(mainWindow, windowWidth, windowHeight);
	}
	isFullScreen = fullScreen;
	SDL_GetWindowSize(mainWindow, &windowWidth, &windowHeight);
}

String GetBackgroundColor() {
	return backgroundColor.ToString();
}

void SetBackgroundColor(String colorStr) {
	backgroundColor = ToColor(colorStr);
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

Value GetImagePixel(Value image, int x, int y) {
	if (x < 0 || y < 0) return Value::null;
	
	// First, get our image storage out of the handle in the MiniScript object.
	if (image.type != ValueType::Map) return Value::null;
	Value textureH = image.Lookup(magicHandle);
	if (textureH.type != ValueType::Handle) return Value::null;
	
	// ToDo: how do we be sure the data is specifically a TextureStorage?
	// Do we need to enable RTTI, or use some common base class?
	TextureStorage *storage = ((TextureStorage*)(textureH.data.ref));
	if (storage == nullptr) return Value::null;

	if (x >= storage->surface->w || y >= storage->surface->h) return Value::null;
	y = storage->surface->h - 1 - y;
	
	int bpp = storage->surface->format->BytesPerPixel;
	Uint8 *p = (Uint8 *)storage->surface->pixels + y * storage->surface->pitch + x * bpp;
	Uint32 data = 0;
	switch (bpp) {
		case 1:
			data = *p;
			break;

		case 2:
			data = *(Uint16 *)p;
			break;

		case 3:
			if (SDL_BYTEORDER == SDL_BIG_ENDIAN) data = p[0] << 16 | p[1] << 8 | p[2];
			else data = p[0] | p[1] << 8 | p[2] << 16;
			break;

		case 4:
			// I guess we're assuming native order here?!  (ToDo)
			data = *(Uint32 *)p;
			break;
	}

	Color color;
	SDL_GetRGBA(data, storage->surface->format, &color.r, &color.g, &color.b, &color.a);
	return color.ToString();
}
	
void SetImagePixel(Value image, int x, int y, String colorStr) {
	if (x < 0 || y < 0) return;
	
	// First, get our image storage out of the handle in the MiniScript object.
	if (image.type != ValueType::Map) return;
	Value textureH = image.Lookup(magicHandle);
	if (textureH.type != ValueType::Handle) return;
	
	// ToDo: how do we be sure the data is specifically a TextureStorage?
	// Do we need to enable RTTI, or use some common base class?
	TextureStorage *storage = ((TextureStorage*)(textureH.data.ref));
	if (storage == nullptr) return;

	if (x >= storage->surface->w || y >= storage->surface->h) return;
	y = storage->surface->h - 1 - y;
	
	Color color = ToColor(colorStr);
	Uint32 data = SDL_MapRGBA(storage->surface->format, color.r, color.g, color.b, color.a);
	
	int bpp = storage->surface->format->BytesPerPixel;
	Uint8 *p = (Uint8 *)storage->surface->pixels + y * storage->surface->pitch + x * bpp;
	switch (bpp) {
		case 1:
			*p = (Uint8)data;
			break;

		case 2:
			*(Uint16 *)p = (Uint16)data;
			break;

		case 3:
			if (SDL_BYTEORDER == SDL_BIG_ENDIAN) {
				p[0] = (data >> 16) & 0xFF;
				p[1] = (data >> 8) & 0xFF;
				p[2] = data & 0xFF;
			} else {
				p[2] = (data >> 16) & 0xFF;
				p[1] = (data >> 8) & 0xFF;
				p[0] = data & 0xFF;
			}
			break;

		case 4:
			// I guess we're assuming native order here?!  (ToDo)
			*(Uint32 *)p = data;
			break;
	}
	
	// clear the texture associated with this image, if any, so it will get recreated on next use
	SDL_DestroyTexture(storage->texture); storage->texture = nullptr;
}

Value GetSubImage(Value image, int left, int bottom, int width, int height) {
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

void Print(MiniScript::String s, bool addLineBreak) {
	if (mainTextDisplay) mainTextDisplay->Print(s, addLineBreak);
}

void Clear() {
	mainTextDisplay->Clear();
	MiniScript::ValueList sprites = spriteList.GetList();
	sprites.Clear();
}

//--------------------------------------------------------------------------------
// Private method implementations
//--------------------------------------------------------------------------------

void SetupKeyNameMap() {
	// most printable keys are the same in SDLK...
	for (char c=' '; c < 'A'; c++) keyNameMap.SetValue(String(c), c);
	for (char c='['; c <= '~'; c++) keyNameMap.SetValue(String(c), c);
	
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
			SDL_SetTextureScaleMode(storage->texture, SDL_ScaleModeNearest);
		}
		double w = storage->surface->w*scale, h = storage->surface->h*scale;
		
		SDL_Rect destRect = { RoundToInt(x-w/2), windowHeight-RoundToInt(y+h/2), RoundToInt(w), RoundToInt(h) };

		SDL_SetTextureColorMod(storage->texture, c.r, c.g, c.b);
		SDL_SetTextureAlphaMod(storage->texture, c.a);
		SDL_RenderCopyEx(mainRenderer, storage->texture, NULL, &destRect, rotation, NULL, SDL_FLIP_NONE);
	}
}

void HandleWindowSizeChange(int newWidth, int newHeight) {
	mainTextDisplay->NoteWindowSizeChange(newWidth, newHeight);
}

}	// end of namespace SdlGlue
