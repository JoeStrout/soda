//
//  PixelDisplay.h
//  soda
//
//	This is the actual Display class that represents a pixel display.  It
//	wraps a PixelSurface (which is a more low-level thing that manages an
//	array of SDL textures).
//
//	Note that it's PixelDisplay that converts from Soda's bottom-up
//	coordinate system, to PixelSurface's top-down one.

#ifndef PIXELDISPLAY_H
#define PIXELDISPLAY_H

#include "Color.h"
#include "SimpleVector.h"
#include "PixelSurface.h"

struct SDL_Renderer;

namespace SdlGlue {

void SetupPixelDisplay(SDL_Renderer* renderer);
void ShutdownPixelDisplay();
void RenderPixelDisplay();

class PixelDisplay {
public:
	PixelDisplay();
	~PixelDisplay();
	void Clear(Color color=Color(0,0,0,0));
	void Render();
	
	int Height() { return surf->totalHeight; }
	int Width() { return surf->totalWidth; }
	
	void FillRect(int left, int bottom, int width, int height, Color color);
	void FillEllipse(int left, int bottom, int width, int height, Color color);
	
	Color drawColor;

private:
	PixelSurface *surf;
};

extern PixelDisplay* mainPixelDisplay;

}

#endif // PIXELDISPLAY_H
