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


static void Swap(int& a, int& b) {
	int temp = a;
	a = b;
	b = temp;
}


//--------------------------------------------------------------------------------
// Public method implementations
//--------------------------------------------------------------------------------

PixelDisplay::PixelDisplay() {
	surf = new PixelSurface(GetWindowWidth(), GetWindowHeight());
	drawColor = Color::white;
	Clear();
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

void PixelDisplay::SetPixel(int x, int y, Color color) {
	surf->SetPixel(x, y, color);
}

void PixelDisplay::DrawLine(int x1, int y1, int x2, int y2, Color color ) {
	// Bresenham's line algorithm
	int dx = x2 - x1;
	int dy = y2 - y1;
	int absDx = dx < 0 ? -dx : dx;
	int absDy = dy < 0 ? -dy : dy;

	bool steep = (absDy > absDx);
	if (steep) {
		Swap(x1, y1);
		Swap(x2, y2);
	}
	
	if (x1 > x2) {
		Swap(x1, x2);
		Swap(y1, y2);
	}

	dx = x2 - x1;
	dy = y2 - y1;
	absDy = dy < 0 ? -dy : dy;

	int error = dx / 2;
	int ystep = (y1 < y2) ? 1 : -1;
	int y = y1;
	
	int maxX = (int)x2;
	
	for (int x=(int)x1; x<=maxX; x++) {
		if (steep) surf->SetPixel(y,x, color);
		else surf->SetPixel(x,y, color);

		error -= absDy;
		if (error < 0) {
			y += ystep;
			error += dx;
		}
	}
}

void PixelDisplay::FillRect(int left, int bottom, int width, int height, Color color) {
	SDL_Rect r = {left, bottom, width, height};
	surf->FillRect(&r, color);
}

void PixelDisplay::FillEllipse(int left, int bottom, int width, int height, Color color) {
	SDL_Rect r = {left, bottom, width, height};
	surf->FillEllipse(&r, color);
}

void PixelDisplay::Render() {
	surf->Render();
}

} // namespace SdlGlue
