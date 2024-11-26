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
#include "Vector2.h"

struct SDL_Renderer;

namespace SdlGlue {

void SetupPixelDisplay(SDL_Renderer* renderer);
void ShutdownPixelDisplay();
void RenderPixelDisplay();

struct CachedPixels {
    Color* pixels;
};

class PointInPolyPrecalc;

class PixelDisplay {
public:
    PixelDisplay();
    ~PixelDisplay();
    void Clear(Color color=Color(0,0,0,0));
    void Render();
    
    int Height() { return totalHeight; }
    int Width() { return totalWidth; }
    
    void SetPixel(int x, int y, Color color);
    void DrawLine(int x1, int y1, int x2, int y2, Color color, float width=1);
    void FillRect(int left, int bottom, int width, int height, Color color);
    void FillEllipse(int left, int bottom, int width, int height, Color color);
 	void FillPolygon(const SimpleVector<Vector2>& points, Color color);
   
    Color drawColor;

private:
    // width and height of each tile, in pixels
    int tileWidth = 64;
    int tileHeight = 64;
    
    // total surface size, in pixels
    int totalWidth = 384;
    int totalHeight = 256;
    
    // how many rows and columns of tiles we have
    int tileRows;
    int tileCols;
    
    SDL_Texture* *tileTex;
    bool *textureInUse;
    Color *tileColor;
    bool *tileNeedsUpdate;
    CachedPixels *pixelCache;
    
    void AllocArrays();
    void DeallocArrays();
    bool EnsureTextureInUse(int tileIndex, Color unlessColor);
    void EnsureTextureInUse(int tileIndex);
    void SetPixelRun(int x0, int x1, int y, Color color);
	void DrawThinLine(int x1, int y1, int x2, int y2, Color color);
    bool TileRangeWithin(SDL_Rect *rect, int* tileCol0, int* tileCol1, int* tileRow0, int* tileRow1);
    bool IsTileWithinEllipse(int col, int row, SDL_Rect* ellipse);
	bool IsTileWithinPolygon(int col, int row, const PointInPolyPrecalc* precalc);
};

extern PixelDisplay* mainPixelDisplay;

}

#endif // PIXELDISPLAY_H
