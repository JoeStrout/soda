// Header file for the "PixelSurface" class, which represents a pixel buffer.
// This may actually be composed of several texture tiles under the hood
// (for performance reasons), but presents as if it is just one big unified
// pixel buffer.

#ifndef PIXELSURFACE_H
#define PIXELSURFACE_H

#include "SdlUtils.h"
#include "Color.h"

namespace SdlGlue {

void SetupPixelSurface(SDL_Renderer *renderer);
void RenderPixelSurface();
void ShutdownPixelSurface();

struct CachedPixels {
	Color* pixels;
};

class PixelSurface {
public:
	PixelSurface(int width=512, int height=384, Color color=Color::clear);
	~PixelSurface();
	void Clear(Color color = Color(0,0,0,0));
	void Render();

	void FillRect(SDL_Rect *rect, Color color);
	void FillEllipse(SDL_Rect* rect, Color color);

	// width and height of each tile, in pixels
	int tileWidth = 64;
	int tileHeight = 64;
	
	// total surface size, in pixels
	int totalWidth = 384;
	int totalHeight = 256;
	
private:
	// how many rows and columns of tiles we have
	int tileRows;
	int tileCols;
	
	// Arrays of data for each tile.  Use Index(col,row) to index into these.
	SDL_Texture* *tileTex;		// tile textures by column, row
	bool *textureInUse;			// true where tiles are actually using textures
	Color *tileColor;			// color to use where textureInUse[i] == false
	bool *tileNeedsUpdate;			// whether we have locked each tile for writing
	CachedPixels *pixelCache;	// cached pixels for each tile
	
	// Handy function to index into the above.
	int Index(int col, int row) { return row * tileCols + col; }
	
	bool anyLocked;				// whether ANY tile is locked for writing
	
	
	void AllocArrays();
	void DeallocArrays();
	bool EnsureTextureInUse(int tileIndex, Color unlessColor);
	void EnsureTextureInUse(int tileIndex);
	void SetPixelRun(int x0, int x1, int y, Color color);
	bool TileRangeWithin(SDL_Rect *rect, int* tileCol0, int* tileCol1, int* tileRow0, int* tileRow1);
	bool IsTileWithinEllipse(int col, int row, SDL_Rect* ellipse);
};



}

#endif /* PIXELSURFACE_H */
