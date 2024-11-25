#include "PixelSurface.h"

namespace SdlGlue {

static const Color clear32 = Color(0, 0, 0, 0);

// ceilDiv: return x / y, rounded up to the nearest integer.
int ceilDiv(int x, int y) {
	if (x == 0) return 0;
	return 1 + ((x - 1) / y);
}

//SDL_Texture *tex = nullptr;
static PixelSurface *surface = nullptr;
static SDL_Renderer *renderer = nullptr;

void SetupPixelSurface(SDL_Renderer  *renderer) {
	SdlGlue::renderer = renderer;
}

void RenderPixelSurface() {
	surface->Render();
}

void ShutdownPixelSurface() {
	delete surface;
}

/// <summary>
/// Return whether the given point is within the axis-aligned
/// ellipse inscribed in the given rectangle.
/// </summary>
/// <param name="x">point of interest, x coordinate</param>
/// <param name="y">point of interest, y coordinate</param>
/// <param name="ellipse">ellipse bounds</param>
/// <returns>true if point is within the ellipse; false otherwise</returns>
static bool IsPointWithinEllipse(float x, float y, SDL_Rect* ellipse) {
	float halfWidth = ellipse->w/2;
	float dx = x - (ellipse->x + halfWidth);
	float term1 = (dx * dx) / (halfWidth * halfWidth);
	
	float halfHeight = ellipse->h/2;
	float dy = y - (ellipse->y + halfHeight);
	float term2 = (dy * dy) / (halfHeight * halfHeight);
	
	return term1 + term2 <= 1;
}

PixelSurface::PixelSurface(int width, int height, Color color) {
	totalWidth = width;
	totalHeight = height;
	AllocArrays();
	Clear(color);
}

PixelSurface::~PixelSurface() {
	DeallocArrays();
}

void PixelSurface::AllocArrays() {
	tileCols = ceilDiv(totalWidth, tileWidth);
	tileRows = ceilDiv(totalHeight, tileHeight);
	int qtyTiles = tileCols * tileRows;
	
	tileTex = new SDL_Texture*[qtyTiles];
	textureInUse = new bool[qtyTiles];
	tileColor = new Color[qtyTiles];
	tileNeedsUpdate = new bool[qtyTiles];
	pixelCache = new CachedPixels[qtyTiles];
	for (int i=0; i<qtyTiles; i++) {
		SDL_Texture *tex = SDL_CreateTexture(renderer, 
			SDL_PIXELFORMAT_RGBA32, 
			SDL_TEXTUREACCESS_STREAMING,
			tileWidth, tileHeight);
		SDL_SetTextureBlendMode(tex, SDL_BLENDMODE_BLEND);
		tileTex[i] = tex;
		textureInUse[i] = false;
		tileColor[i] = clear32;
		tileNeedsUpdate[i] = false;
		pixelCache[i].pixels = nullptr;		// (these will be allocated when needed)
	}
}

void PixelSurface::DeallocArrays() {
	int qtyTiles = tileCols * tileRows;
	for (int i=0; i<qtyTiles; i++) {
		SDL_DestroyTexture(tileTex[i]);
		if (pixelCache[i].pixels) delete[] pixelCache[i].pixels;
	}

	delete[] tileTex;			tileTex = nullptr;
	delete[] textureInUse;		textureInUse = nullptr;
	delete[] tileColor;			tileColor = nullptr;
	delete[] tileNeedsUpdate;	tileNeedsUpdate = nullptr;
	delete[] pixelCache;		pixelCache = nullptr;
}

void PixelSurface::Clear(Color color) {
	int qtyTiles = tileCols * tileRows;
	for (int i=0; i<qtyTiles; i++) {
		textureInUse[i] = false;
		tileColor[i] = color;
	}
}

/// <summary>
/// Render this PixelSurface to the screen, bottom-up from the bottom-left
/// corner of the window.
/// </summary>
void PixelSurface::Render() {
    int i = 0;
    int windowHeight = tileRows * tileHeight;  // Need total height for y-coord calculation
    
    for (int row=0; row < tileRows; row++) {
        // Calculate y position from bottom instead of top
        int yPos = windowHeight - (row + 1) * tileHeight;
        
        for (int col=0; col < tileCols; col++) {
            SDL_Rect destRect = { col*tileWidth, yPos, tileWidth, tileHeight };
            if (textureInUse[i]) {
                if (tileNeedsUpdate[i]) {
                    void* pixels;
                    int pitch;
                    int err = SDL_LockTexture(tileTex[i], NULL, &pixels, &pitch);
                    if (err) {
                        printf("Error in SDL_LockTexture: %s\n", SDL_GetError());
                        continue;
                    }
                    
                    // Copy pixels in reverse row order to flip vertically
                    Color* srcP = pixelCache[i].pixels + (tileHeight - 1) * tileWidth;
                    Uint8* destP = (Uint8*)pixels;
                    int bytesToCopy = tileWidth * 4;
                    
                    if (bytesToCopy == pitch) {
                        for (int y = 0; y < tileHeight; y++) {
                            memcpy(destP + y * pitch, srcP - y * tileWidth, bytesToCopy);
                        }
                    } else {
                        for (int y = 0; y < tileHeight; y++) {
                            memcpy(destP, srcP, bytesToCopy);
                            srcP -= tileWidth;
                            destP += pitch;
                        }
                    }
                    
                    SDL_UnlockTexture(tileTex[i]);
                    tileNeedsUpdate[i] = false;
                }
                
                SDL_RenderCopy(renderer, tileTex[i], NULL, &destRect);
            } else {
                Color c = tileColor[i];
                if (c.a > 0) {
                    SDL_SetRenderDrawColor(renderer, c.r, c.g, c.b, c.a);
                    SDL_RenderFillRect(renderer, &destRect);
 					// For debugging: outline and "X" the tile instead of filling it.
//					SDL_RenderDrawRect(renderer, &destRect);
//					SDL_RenderDrawLine(renderer, destRect.x, destRect.y, destRect.x+destRect.w, destRect.y+destRect.h);
//					SDL_RenderDrawLine(renderer, destRect.x, destRect.y+destRect.h, destRect.x+destRect.w, destRect.y);
               }
            }
            i++;
        }
    }
}


/// <summary>
/// Get the range of tiles contained entirely within the given rectangle.
/// </summary>
/// <param name="rect">rectangular region of interest</param>
/// <param name="tileCol0">receives leftmost tile column within the rect</param>
/// <param name="tileCol1">receives rightmost tile column within the rect</param>
/// <param name="tileRow0">receives minimum tile row within the rect</param>
/// <param name="tileRow1">receives maximum tile row within the rect</param>
/// <returns>true if the resulting range contains any tiles; false otherwise</returns>
bool PixelSurface::TileRangeWithin(SDL_Rect *rect, int* tileCol0, int* tileCol1, int* tileRow0, int* tileRow1) {
	bool ok = true;
	int maxTileCol = tileCols - 1;
	*tileCol0 = ceilDiv(rect->x, tileWidth);
	*tileCol1 = ((rect->x + rect->w + 1) / tileWidth) - 1;
	if (*tileCol0 < 0) *tileCol0 = 0;
	else if (*tileCol0 > maxTileCol) ok = false;
	if (*tileCol1 < 0) ok = false;
	else if (*tileCol1 > maxTileCol) *tileCol1 = maxTileCol;
	
	int maxTileRow = tileRows - 1;
	*tileRow0 = ceilDiv(rect->y, tileHeight);
	*tileRow1 = ((rect->y + rect->h + 1) / tileHeight) - 1;
	if (*tileRow0 < 0) *tileRow0 = 0;
	else if (*tileRow0 > maxTileRow) ok = false;
	if (*tileRow1 < 0) ok = false;
	else if (*tileRow1 > maxTileRow) *tileRow1 = maxTileRow;
	
	if (ok) ok = (*tileCol0 <= *tileCol1 && *tileRow0 <= *tileRow1);
	return ok;
}

// Make sure we're ready to draw in the given tile, UNLESS the whole
// tile color is already the given color.  Return true if the texture
// is ready for drawing; return false if we're not using a texture 
// here, but the tile color matches the given color.
bool PixelSurface::EnsureTextureInUse(int tileIndex, Color unlessColor) {
	if (textureInUse[tileIndex]) return true;		// already ready to draw
	if (tileColor[tileIndex] == unlessColor) return false;	// whole tile is correct color
	EnsureTextureInUse(tileIndex);
	return true;		// NOW ready to draw
}

// Make sure we're actually using the texture for the given tile,
// and have a cache of the pixels therein so we can do drawing.
void PixelSurface::EnsureTextureInUse(int tileIndex) {
	if (textureInUse[tileIndex]) return;		// already ready to draw
	int pixPerTile = tileWidth * tileHeight;
	if (!pixelCache[tileIndex].pixels) pixelCache[tileIndex].pixels = new Color[pixPerTile];
	Color* pixels = pixelCache[tileIndex].pixels;
	Color c = tileColor[tileIndex];
	for (int i=0; i<pixPerTile; i++) *pixels++ = c;
	textureInUse[tileIndex] = true;
}

// Set a single pixel of color in the surface, as quickly as possible.
void PixelSurface::SetPixel(int x, int y, Color color) {
	
	if (x < 0 || y < 0 || x >= totalWidth || y >= totalHeight) return;
	int col = x / tileWidth, row = y / tileHeight;
	
	int tileIndex = Index(col, row);
	if (!EnsureTextureInUse(tileIndex, color)) return;
	
	int localX = x % tileWidth;
	int localY = y % tileHeight;
	Color* p = pixelCache[tileIndex].pixels + localY*tileWidth + localX;
	if (*p == color) return;	// already the right color
	*p = color;
	tileNeedsUpdate[tileIndex] = true;
}

// Set a horizontal run of pixels to the given color.
// All coordinates should be already range-checked (i.e. not exceed
// the surface dimensions).  Note that the span is semi-open, i.e.,
// it will include x0 but not include x1.
void PixelSurface::SetPixelRun(int x0, int x1, int y, Color color) {
	int col = x0 / tileWidth, row = y / tileHeight;
	int localY = y - row*tileHeight;	// y % tileHeight?
	int x = x0;
	while (x < x1) {
		int endX = (col+1) * tileWidth;
		if (endX > x1) endX = x1;
		// OK, set pixels from x to endX to the given color.
		int tileIndex = Index(col, row);
		int localX = x % tileWidth;
		if (EnsureTextureInUse(tileIndex, color)) {
			Color* p = pixelCache[tileIndex].pixels + localY*tileWidth + localX;
			for (; x < endX; x++) *p++ = color;
			tileNeedsUpdate[tileIndex] = true;
		}
		// Next tile column!
		col++;
		x = col * tileWidth;
	}
}

/// Fill a rectangular region with a color.
void PixelSurface::FillRect(SDL_Rect *rect, Color color) {
	if (!rect) return;
	int y0 = rect->y;
	if (y0 < 0) y0 = 0; else if (y0 >= totalHeight) y0 = totalHeight;
	int y1 = rect->y + rect->h;
	if (y1 < 0) y1 = 0; else if (y1 >= totalHeight) y1 = totalHeight;

	int x0 = rect->x;
	if (x0 < 0) x0 = 0; else if (x0 >= totalWidth) x0 = totalWidth;
	int x1 = rect->x + rect->w;
	if (x1 < 0) x1 = 0; else if (x1 >= totalWidth) x1 = totalWidth;

	// Start by filling complete tiles that are contained within the rectangle.
	int tileCol0, tileCol1, tileRow0, tileRow1;
	if (TileRangeWithin(rect, &tileCol0, &tileCol1, &tileRow0, &tileRow1)) {
		for (int tileRow = tileRow0; tileRow <= tileRow1; tileRow++) {
			for (int tileCol = tileCol0; tileCol <= tileCol1; tileCol++) {
				// Because this entire tile is going to be one color,
				// we don't need to use the texture at all.
				int tileIndex = Index(tileCol, tileRow);
				textureInUse[tileIndex] = false;
				tileColor[tileIndex] = color;
			}
		}
	}

	// Then, fill spans (which will efficiently skip filled tiles).
	for (int y=y0; y<y1; y++) SetPixelRun(x0, x1, y, color);
}

/// <summary>
/// Figure out whether the given tile is completely contained
/// in an ellipse inscribed in the given rectangle.
/// </summary>
/// <param name="col">tile column</param>
/// <param name="row">tile row</param>
/// <param name="ellipse">ellipse bounds</param>
/// <returns>true if tile is within ellipse; false otherwise</returns>
bool PixelSurface::IsTileWithinEllipse(int col, int row, SDL_Rect* ellipse) {
	int x = col * tileWidth;
	int y = row * tileHeight;
	return IsPointWithinEllipse(x, y, ellipse)
		&& IsPointWithinEllipse(x + tileWidth, y, ellipse)
		&& IsPointWithinEllipse(x + tileWidth, y + tileHeight, ellipse)
		&& IsPointWithinEllipse(x, y + tileHeight, ellipse);
}

void PixelSurface::FillEllipse(SDL_Rect* rect, Color color) {
	if (rect->w <= 2 || rect->h <= 2) {
		// If the width or height is less than 2, then we can't draw
		// any round shape anyway; a rect fill is a decent approximation.
		FillRect(rect, color);
		return;
	}

	int y0 = rect->y;
	if (y0 < 0) y0 = 0; else if (y0 >= totalHeight) y0 = totalHeight-1;
	int y1 = rect->y + rect->h;
	if (y1 < 0) y1 = 0; else if (y1 >= totalHeight) y1 = totalHeight;
	
	// Start by filling complete tiles that are contained within the bounds.
	int tileCol0, tileCol1, tileRow0, tileRow1;
	if (TileRangeWithin(rect, &tileCol0, &tileCol1, &tileRow0, &tileRow1)) {
		for (int tileRow = tileRow0; tileRow <= tileRow1; tileRow++) {
			for (int tileCol = tileCol0; tileCol <= tileCol1; tileCol++) {
				if (IsTileWithinEllipse(tileCol, tileRow, rect)) {
					int tileIndex = Index(tileCol, tileRow);
					textureInUse[tileIndex] = false;
					tileColor[tileIndex] = color;					
				}
			}
		}
	}
	
	// Then, fill each row of the ellipse using SetPixelRun,
	// which efficiently skips filled tiles.
	float r = rect->h * 0.5f;
	float rsqr = r*r;
	float aspect = (float)rect->w / rect->h;
	float rectCenterX = rect->x + rect->w * 0.5f;
	float rectCenterY = rect->y + rect->h * 0.5f;
	for (int y=y0; y<y1; y++) {
		float cy = rectCenterY - y - 0.5f;
		float cx = sqrt(rsqr - cy*cy) * aspect;
		int x0 = (rectCenterX - cx + 0.5f);
		if (x0 < 0) x0 = 0; else if (x0 >= totalWidth) x0 = totalWidth;
		int x1 = (rectCenterX + cx + 0.5f);
		if (x1 < 0) x1 = 0; else if (x1 >= totalWidth) x1 = totalWidth;
		SetPixelRun(x0, x1, y, color);
	}
}


} // namespace SdlGlue