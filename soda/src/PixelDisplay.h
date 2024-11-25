//
//  PixelDisplay.h
//  soda
//
//	This is the actual Display class that represents a pixel display.  It
//	wraps a PixelSurface (which is a more low-level thing that manages an
//	array of SDL textures).
//
//	ToDo: consider whether this wrapper is actually contributing anything
//	worthwhile.  Maybe PixelDisplay and PixelSurface should be combined into
//	one (sacrificing direct correspondence to the C# code).

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
	
	void SetPixel(int x, int y, Color color);
	void DrawLine(int x1, int y1, int x2, int y2, Color color);
	void FillRect(int left, int bottom, int width, int height, Color color);
	void FillEllipse(int left, int bottom, int width, int height, Color color);
	
	Color drawColor;

private:
	PixelSurface *surf;
};

extern PixelDisplay* mainPixelDisplay;

}

#endif // PIXELDISPLAY_H
