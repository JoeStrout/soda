#include "PixelDisplay.h"
#include "SdlUtils.h"
#include "SdlGlue.h"
#include "Color.h"
#include <cmath>

using namespace MiniScript;
using namespace SdlGlue;

namespace SdlGlue {

PixelDisplay* mainPixelDisplay = nullptr;
static SDL_Renderer* mainRenderer = nullptr;

static int ceilDiv(int x, int y) {
    if (x == 0) return 0;
    return 1 + ((x - 1) / y);
}

static void Swap(int& a, int& b) {
    int temp = a;
    a = b;
    b = temp;
}

static bool IsPointWithinEllipse(double x, double y, SDL_Rect* ellipse) {
    double halfWidth = ellipse->w * 0.5;
    double dx = x - (ellipse->x + halfWidth);
    double term1 = (dx * dx) / (halfWidth * halfWidth);
    
    double halfHeight = ellipse->h * 0.5;
    double dy = y - (ellipse->y + halfHeight);
    double term2 = (dy * dy) / (halfHeight * halfHeight);
    
    return term1 + term2 <= 1;
}

// Little class of precomputed data used for point-in-polygon tests.
class PointInPolyPrecalc {
public:
	PointInPolyPrecalc(const SimpleVector<Vector2>& inPoly) 
	: polygon(inPoly) {
		constants.resizeBuffer(polygon.size());
		multiples.resizeBuffer(polygon.size());
	}

	const SimpleVector<Vector2>& polygon;	// (valid only as long as polygon remains)
	SimpleVector<double> constants;
	SimpleVector<double> multiples;	
};

static PointInPolyPrecalc* PrecalcPointInPoly(const SimpleVector<Vector2>& polygon) {
	PointInPolyPrecalc* result = new PointInPolyPrecalc(polygon);

	int j = polygon.size() - 1;
	for (int i=0; i<polygon.size(); i++) {
		if (polygon[j].y == polygon[i].y) {
			result->constants.push_back(polygon[i].x);
			result->multiples.push_back(0);
		} else {
			result->constants.push_back(polygon[i].x-(polygon[i].y*polygon[j].x)/(polygon[j].y-polygon[i].y)+(polygon[i].y*polygon[i].x)/(polygon[j].y-polygon[i].y));
			result->multiples.push_back((polygon[j].x-polygon[i].x)/(polygon[j].y-polygon[i].y)); 
		}
		j=i;
	}

	return result;
}

static bool PointInPoly(const PointInPolyPrecalc* precalc, double x, double y) {
	unsigned long polyCorners = precalc->polygon.size();
	bool oddNodes = false;
	bool current = precalc->polygon[polyCorners-1].y > y;
	for (unsigned long i=0; i < polyCorners; i++) {
		bool previous = current;
		current = precalc->polygon[i].y > y; 
		if (current != previous) oddNodes ^= y * precalc->multiples[i] + precalc->constants[i] < x; 
	}
	return oddNodes;
}

static double LineSegIntersectFraction(Vector2 p1, Vector2 p2, Vector2 p3, Vector2 p4) {
	// Look for an intersection between line p1-p2 and line p3-p4.
	// Return the fraction of the way from p1 to p2 where this
	// intersection occurs.  If the two lines are parallel, and
	// there is no intersection, then this returns NaN.
	// Reference: http://paulbourke.net/geometry/lineline2d/
	double num = (p4.x - p3.x) * (p1.y - p3.y) - (p4.y - p3.y) * (p1.x - p3.x);
	double denom=(p4.y - p3.y) * (p2.x - p1.x) - (p4.x - p3.x) * (p2.y - p1.y);
	if (denom == 0.0f) return 0.0f / 0.0f;
	return num / denom;
}

static bool LineSegmentsIntersect(Vector2 p1, Vector2 p2, Vector2 p3, Vector2 p4) {
	// Return whether the line segment p1-p2 intersects segment p3-p4.
	double ua = LineSegIntersectFraction(p1, p2, p3, p4);
	if (std::isnan(ua)) return false;  // the line segments are parallel
	if (ua < 0.0f || ua > 1.0f) return false;  // intersection out of bounds
	double ub = LineSegIntersectFraction(p3, p4, p1, p2);
	if (ub < 0.0f || ub > 1.0f) return false;  // intersection out of bounds
	return true;
}

PixelDisplay::PixelDisplay() {
    totalWidth = GetWindowWidth();
    totalHeight = GetWindowHeight();
    drawColor = Color::white;
    AllocArrays();
    Clear();
}

PixelDisplay::~PixelDisplay() {
    DeallocArrays();
}

void SetupPixelDisplay(SDL_Renderer *renderer) {
    mainRenderer = renderer;
    mainPixelDisplay = new PixelDisplay();
}

void ShutdownPixelDisplay() {
    delete mainPixelDisplay;
    mainPixelDisplay = nullptr;
}

void RenderPixelDisplay() {
    mainPixelDisplay->Render();
}

void PixelDisplay::AllocArrays() {
    tileCols = ceilDiv(totalWidth, tileWidth);
    tileRows = ceilDiv(totalHeight, tileHeight);
    int qtyTiles = tileCols * tileRows;
    
    tileTex = new SDL_Texture*[qtyTiles];
    textureInUse = new bool[qtyTiles];
    tileColor = new Color[qtyTiles];
    tileNeedsUpdate = new bool[qtyTiles];
    pixelCache = new CachedPixels[qtyTiles];
    for (int i=0; i<qtyTiles; i++) {
        SDL_Texture *tex = SDL_CreateTexture(mainRenderer, 
            SDL_PIXELFORMAT_RGBA32, 
            SDL_TEXTUREACCESS_STREAMING,
            tileWidth, tileHeight);
        SDL_SetTextureBlendMode(tex, SDL_BLENDMODE_BLEND);
        tileTex[i] = tex;
        textureInUse[i] = false;
        tileColor[i] = Color(0,0,0,0);
        tileNeedsUpdate[i] = false;
        pixelCache[i].pixels = nullptr;
    }
}

void PixelDisplay::DeallocArrays() {
    int qtyTiles = tileCols * tileRows;
    for (int i=0; i<qtyTiles; i++) {
        SDL_DestroyTexture(tileTex[i]);
        if (pixelCache[i].pixels) delete[] pixelCache[i].pixels;
    }
    delete[] tileTex;
    delete[] textureInUse;
    delete[] tileColor;
    delete[] tileNeedsUpdate;
    delete[] pixelCache;
}

void PixelDisplay::Clear(Color color) {
    int qtyTiles = tileCols * tileRows;
    for (int i=0; i<qtyTiles; i++) {
        textureInUse[i] = false;
        tileColor[i] = color;
    }
}

void PixelDisplay::Render() {
    int i = 0;
    int windowHeight = tileRows * tileHeight;
    
    for (int row=0; row < tileRows; row++) {
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
                SDL_RenderCopy(mainRenderer, tileTex[i], NULL, &destRect);
            } else {
                Color c = tileColor[i];
                if (c.a > 0) {
                    SDL_SetRenderDrawColor(mainRenderer, c.r, c.g, c.b, c.a);
                    SDL_RenderFillRect(mainRenderer, &destRect);
                }
            }
            i++;
        }
    }
}

bool PixelDisplay::TileRangeWithin(SDL_Rect *rect, int* tileCol0, int* tileCol1, int* tileRow0, int* tileRow1) {
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

bool PixelDisplay::EnsureTextureInUse(int tileIndex, Color unlessColor) {
    if (textureInUse[tileIndex]) return true;
    if (tileColor[tileIndex] == unlessColor) return false;
    EnsureTextureInUse(tileIndex);
    return true;
}

void PixelDisplay::EnsureTextureInUse(int tileIndex) {
    if (textureInUse[tileIndex]) return;
    int pixPerTile = tileWidth * tileHeight;
    if (!pixelCache[tileIndex].pixels) pixelCache[tileIndex].pixels = new Color[pixPerTile];
    Color* pixels = pixelCache[tileIndex].pixels;
    Color c = tileColor[tileIndex];
    for (int i=0; i<pixPerTile; i++) *pixels++ = c;
    textureInUse[tileIndex] = true;
}

void PixelDisplay::SetPixel(int x, int y, Color color) {
    if (x < 0 || y < 0 || x >= totalWidth || y >= totalHeight) return;
    int col = x / tileWidth, row = y / tileHeight;
    
    int tileIndex = row * tileCols + col;
    if (!EnsureTextureInUse(tileIndex, color)) return;
    
    int localX = x % tileWidth;
    int localY = y % tileHeight;
    Color* p = pixelCache[tileIndex].pixels + localY*tileWidth + localX;
    if (*p == color) return;
    *p = color;
    tileNeedsUpdate[tileIndex] = true;
}

void PixelDisplay::SetPixelRun(int x0, int x1, int y, Color color) {
    int col = x0 / tileWidth, row = y / tileHeight;
    int localY = y - row*tileHeight;
    int x = x0;
    while (x < x1) {
        int endX = (col+1) * tileWidth;
        if (endX > x1) endX = x1;
        int tileIndex = row * tileCols + col;
        int localX = x % tileWidth;
        if (EnsureTextureInUse(tileIndex, color)) {
            Color* p = pixelCache[tileIndex].pixels + localY*tileWidth + localX;
            for (; x < endX; x++) *p++ = color;
            tileNeedsUpdate[tileIndex] = true;
        }
        col++;
        x = col * tileWidth;
    }
}

void PixelDisplay::DrawLine(int x1, int y1, int x2, int y2, Color color, double width) {
	if (width < 1.01f) {
		DrawThinLine(x1, y1, x2, y2, color);
	} else {
		// Draw a thick line, by computing a polygon.
		Vector2 tangent(y2-y1, x1-x2);
		double tm = tangent.Magnitude();
		if (tm == 0) return;
		tangent = tangent * width * 0.5f / tm;
		SimpleVector<Vector2> points(4);
		points.push_back(Vector2(x1-tangent.x, y1-tangent.y));
		points.push_back(Vector2(x1+tangent.x, y1+tangent.y));
		points.push_back(Vector2(x2+tangent.x, y2+tangent.y));
		points.push_back(Vector2(x2-tangent.x, y2-tangent.y));
		FillPolygon(points, color);		
	}
}

void PixelDisplay::DrawThinLine(int x1, int y1, int x2, int y2, Color color) {
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
        if (steep) SetPixel(y,x, color);
        else SetPixel(x,y, color);

        error -= absDy;
        if (error < 0) {
            y += ystep;
            error += dx;
        }
    }
}

void PixelDisplay::FillRect(int left, int bottom, int width, int height, Color color) {
    SDL_Rect rect = {left, bottom, width, height};
    
    int y0 = rect.y;
    if (y0 < 0) y0 = 0; else if (y0 >= totalHeight) y0 = totalHeight;
    int y1 = rect.y + rect.h;
    if (y1 < 0) y1 = 0; else if (y1 >= totalHeight) y1 = totalHeight;

    int x0 = rect.x;
    if (x0 < 0) x0 = 0; else if (x0 >= totalWidth) x0 = totalWidth;
    int x1 = rect.x + rect.w;
    if (x1 < 0) x1 = 0; else if (x1 >= totalWidth) x1 = totalWidth;

    int tileCol0, tileCol1, tileRow0, tileRow1;
    if (TileRangeWithin(&rect, &tileCol0, &tileCol1, &tileRow0, &tileRow1)) {
        for (int tileRow = tileRow0; tileRow <= tileRow1; tileRow++) {
            for (int tileCol = tileCol0; tileCol <= tileCol1; tileCol++) {
                int tileIndex = tileRow * tileCols + tileCol;
                textureInUse[tileIndex] = false;
                tileColor[tileIndex] = color;
            }
        }
    }

    for (int y=y0; y<y1; y++) SetPixelRun(x0, x1, y, color);
}

bool PixelDisplay::IsTileWithinEllipse(int col, int row, SDL_Rect* ellipse) {
    int x = col * tileWidth;
    int y = row * tileHeight;
    return IsPointWithinEllipse(x, y, ellipse)
        && IsPointWithinEllipse(x + tileWidth, y, ellipse)
        && IsPointWithinEllipse(x + tileWidth, y + tileHeight, ellipse)
        && IsPointWithinEllipse(x, y + tileHeight, ellipse);
}

/// <summary>
/// Figure out whether the given tile is completely contained
/// in the given polygon.
/// </summary>
/// <param name="col">tile column</param>
/// <param name="row">tile row</param>
/// <param name="point">points defining a polygon</param>
/// <returns>true if tile is within poly; false otherwise</returns>
bool PixelDisplay::IsTileWithinPolygon(int col, int row, const PointInPolyPrecalc* precalc) {
	// First check the corners; if they're not in it, the tile is definitely not.
	if (!PointInPoly(precalc, col * tileWidth, row * tileHeight)) return false;
	if (!PointInPoly(precalc, (col+1) * tileWidth-1, row * tileHeight)) return false;
	if (!PointInPoly(precalc, (col+1) * tileWidth-1, (row+1) * tileHeight - 1)) return false;
	if (!PointInPoly(precalc, col * tileWidth, (row+1) * tileHeight - 1)) return false;
	
	// OK, since it passed those tests,  we now need to check whether any
	// polygon edge intersects any edge of the tile.
	Vector2 t0(col * tileWidth, row * tileHeight);
	Vector2 t1((col+1) * tileWidth-1, row * tileHeight);
	Vector2 t2((col+1) * tileWidth-1, (row+1) * tileHeight - 1);
	Vector2 t3(col * tileWidth, (row+1) * tileHeight - 1);
	for (int i=0; i<precalc->polygon.size(); i++) {
		Vector2 p0 = precalc->polygon[i];
		Vector2 p1 = precalc->polygon[i>0 ? i-1 : precalc->polygon.size()-1];
		if (LineSegmentsIntersect(p0, p1, t0, t1)) return false;
		if (LineSegmentsIntersect(p0, p1, t1, t2)) return false;
		if (LineSegmentsIntersect(p0, p1, t2, t3)) return false;
		if (LineSegmentsIntersect(p0, p1, t3, t0)) return false;
	}
	
	// all tests passed!
	return true;
}

void PixelDisplay::FillEllipse(int left, int bottom, int width, int height, Color color) {
    SDL_Rect rect = {left, bottom, width, height};
    if (rect.w <= 2 || rect.h <= 2) {
        FillRect(left, bottom, width, height, color);
        return;
    }

    int y0 = rect.y;
    if (y0 < 0) y0 = 0; else if (y0 >= totalHeight) y0 = totalHeight-1;
    int y1 = rect.y + rect.h;
    if (y1 < 0) y1 = 0; else if (y1 >= totalHeight) y1 = totalHeight;
    
    int tileCol0, tileCol1, tileRow0, tileRow1;
    if (TileRangeWithin(&rect, &tileCol0, &tileCol1, &tileRow0, &tileRow1)) {
        for (int tileRow = tileRow0; tileRow <= tileRow1; tileRow++) {
            for (int tileCol = tileCol0; tileCol <= tileCol1; tileCol++) {
                if (IsTileWithinEllipse(tileCol, tileRow, &rect)) {
                    int tileIndex = tileRow * tileCols + tileCol;
                    textureInUse[tileIndex] = false;
                    tileColor[tileIndex] = color;                    
                }
            }
        }
    }
    
    double r = rect.h * 0.5f;
    double rsqr = r*r;
    double aspect = (double)rect.w / rect.h;
    double rectCenterX = rect.x + rect.w * 0.5f;
    double rectCenterY = rect.y + rect.h * 0.5f;
    for (int y=y0; y<y1; y++) {
        double cy = rectCenterY - y - 0.5f;
        double cx = sqrt(rsqr - cy*cy) * aspect;
        int x0 = (rectCenterX - cx + 0.5f);
        if (x0 < 0) x0 = 0; else if (x0 >= totalWidth) x0 = totalWidth;
        int x1 = (rectCenterX + cx + 0.5f);
        if (x1 < 0) x1 = 0; else if (x1 >= totalWidth) x1 = totalWidth;
        SetPixelRun(x0, x1, y, color);
    }
}

void PixelDisplay::FillPolygon(const SimpleVector<Vector2>& points, Color color) {
    // Reference: http://alienryderflex.com/polygon_fill/
    if (points.size() < 3) return;
	int* nodeX = new int[points.size()];

    // Find the bounding box of the polygon (constrained to our dimensions)
    double minY = points[0].y, maxY = minY, minX = points[0].x, maxX = minX;
    for (unsigned long i = 1; i < points.size(); i++) {
        if (points[i].y < minY) minY = points[i].y;
        if (points[i].y > maxY) maxY = points[i].y;
        if (points[i].x < minX) minX = points[i].x;
        if (points[i].x > maxX) maxX = points[i].x;
    }
    
    if (minY < 0) minY = 0;
    if (maxY >= totalHeight) maxY = totalHeight - 1;
    if (minX < 0) minX = 0;
    if (maxX >= totalWidth) maxX = totalWidth - 1;

    // Fill any complete tiles within the polygon
    int tileCol0, tileCol1, tileRow0, tileRow1;
    SDL_Rect rect = {(int)minX, (int)minY, (int)(maxX - minX), (int)(maxY - minY)};
    if (TileRangeWithin(&rect, &tileCol0, &tileCol1, &tileRow0, &tileRow1)) {
        PointInPolyPrecalc* precalc = PrecalcPointInPoly(points);
        for (int tileRow = tileRow0; tileRow <= tileRow1; tileRow++) {
            for (int tileCol = tileCol0; tileCol <= tileCol1; tileCol++) {
                if (IsTileWithinPolygon(tileCol, tileRow, precalc)) {
					int tileIndex = tileRow * tileCols + tileCol;
					textureInUse[tileIndex] = false;
					tileColor[tileIndex] = color;
                }
            }
        }
        delete precalc;
    }

    for (int pixelY = static_cast<int>(minY); pixelY <= static_cast<int>(maxY); pixelY++) {
        // Build a list of nodes (points where polygon edges cross this Y value)
        int nodes = 0;
        unsigned long j = points.size() - 1;
        
        for (unsigned long i = 0; i < points.size(); i++) {
            if ((points[i].y < pixelY && points[j].y >= pixelY)
             || (points[j].y < pixelY && points[i].y >= pixelY)) {
				nodeX[nodes++] = static_cast<int>(points[i].x + (pixelY - points[i].y) /
					 (points[j].y - points[i].y) * (points[j].x - points[i].x));
            }
            j = i;
        }

        // Sort the nodes (by X position)
		std::sort(nodeX, nodeX + nodes);
        
        // Fill the pixels between node pairs
        for (int i = 0; i < nodes; i += 2) {
            if (nodeX[i] >= totalWidth) continue;
            if (nodeX[i + 1] <= 0) continue;
            if (nodeX[i] < 0) nodeX[i] = 0;
            if (nodeX[i + 1] > totalWidth) nodeX[i + 1] = totalWidth;
            SetPixelRun(nodeX[i], nodeX[i + 1], pixelY, color);
        }
    }
}

} // namespace SdlGlue
