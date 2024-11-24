//
//  PixelDisplay.h
//  soda
//
//	This is the actual Display class that represents a pixel display.  It
//	wraps a PixelSurface (which is a more low-level thing that manages an
//	array of SDL textures).

#ifndef PIXELDISPLAY_H
#define PIXELDISPLAY_H

#include "Color.h"
#include "SimpleVector.h"

struct SDL_Renderer;

namespace SdlGlue {

void SetupPixelDisplay(SDL_Renderer* renderer);
void ShutdownPixelDisplay();
void RenderPixelDisplay();

class PixelDisplay {
public:
	PixelDisplay();
	void Clear();
	void Render();
	
	void NoteWindowSizeChange(int newWidth, int newHeight);

	Color drawColor;

private:
};

extern PixelDisplay* mainPixelDisplay;

}

#endif // PIXELDISPLAY_H
