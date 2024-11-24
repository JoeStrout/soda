//
//  PixelDisplay.cpp
//  This module implements the PixelDisplay class, which wraps a PixelSurface
//	(i.e. 32-bit arbitrary pixel buffer).

#include "PixelDisplay.h"
#include "SdlUtils.h"
#include "SdlGlue.h"
#include "Color.h"
#include "PixelSurface.h"

using namespace MiniScript;
using namespace SdlGlue;

namespace SdlGlue {


// Public data
PixelDisplay* mainPixelDisplay = nullptr;

// Private data
static SDL_Renderer* mainRenderer = nullptr;

// Forward declarations


//--------------------------------------------------------------------------------
// Public method implementations
//--------------------------------------------------------------------------------

PixelDisplay::PixelDisplay() {
	surf = new PixelSurface(GetWindowWidth(), GetWindowHeight());
	drawColor = Color::white;
	Clear();
	SDL_Rect r = {200,200, 400,300};
	surf->FillEllipse(&r, Color::pink);
}

PixelDisplay::~PixelDisplay() {
	delete surf;
	surf = nullptr;
}

void SetupPixelDisplay(SDL_Renderer *renderer) {
	SetupPixelSurface(renderer);
	mainRenderer = renderer;
	mainPixelDisplay = new PixelDisplay();
}

void ShutdownPixelDisplay() {
	delete mainPixelDisplay;	mainPixelDisplay = nullptr;
}

void RenderPixelDisplay() {
	mainPixelDisplay->Render();
}

void PixelDisplay::Clear(Color color) {
	surf->Clear(color);
}

void PixelDisplay::FillRect(int left, int bottom, int width, int height, Color color) {
	SDL_Rect r = {left, surf->totalHeight - bottom - height, width, height};
	surf->FillRect(&r, color);
}

void PixelDisplay::FillEllipse(int left, int bottom, int width, int height, Color color) {
	SDL_Rect r = {left, surf->totalHeight - bottom - height, width, height};
	surf->FillEllipse(&r, color);
}

void PixelDisplay::Render() {
	surf->Render();
}

} // namespace SdlGlue
