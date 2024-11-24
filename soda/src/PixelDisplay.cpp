//
//  PixelDisplay.cpp
//  This module implements the PixelDisplay class, which wraps a PixelSurface
//	(i.e. 32-bit arbitrary pixel buffer).

#include "PixelDisplay.h"
#include "SdlUtils.h"
#include "SdlGlue.h"
#include "Color.h"

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
	drawColor = Color::white;
	Clear();
}

void SetupPixelDisplay(SDL_Renderer *renderer) {
	mainRenderer = renderer;
	mainPixelDisplay = new PixelDisplay();
}

void ShutdownPixelDisplay() {
	delete mainPixelDisplay;	mainPixelDisplay = nullptr;
}

void RenderPixelDisplay() {
	mainPixelDisplay->Render();
}

void PixelDisplay::Clear() {
}

void PixelDisplay::Render() {
}

} // namespace SdlGlue
