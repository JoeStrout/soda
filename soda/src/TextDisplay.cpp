//
//  TextDisplay.cpp
//  This module implements the TextDisplay class, which displays text on the game window
//	using one of the built-in monospaced fonts.

#include "TextDisplay.h"
#include "ScreenFont_png.h"
#include "SimpleVector.h"
#include "SdlGlue.h"
#include "UnicodeUtil.h"
#include "String.h"
#include <SDL2/SDL.h>
#include <SDL2_image/SDL_image.h>

using namespace MiniScript;

// Helper classes
struct CellContent {
	Uint8 character;
	// ToDo: cell colors, etc.
	
	void Clear() { character = 0; }
};

// Private data
SDL_Renderer* mainRenderer = NULL;
SDL_Texture* screenFontTexture = NULL;
int rows;
int cols;
SimpleVector<SimpleVector<CellContent>> content;		// indexed by [row][column]

// Forward declarations
void Clear();
void SetCharAtPosition(long unicodeChar, int row, int column);
void SetStringAtPosition(const char* s, int stringBytes, int row, int column);
void SetStringAtPosition(String s, int row, int column);
void RenderCharAtPosition(Uint8 character, int row, int column, int windowHeight);


//--------------------------------------------------------------------------------
// Public method implementations
//--------------------------------------------------------------------------------

void SetupTextDisplay(SDL_Renderer *renderer) {
	mainRenderer = renderer;
	SDL_RWops *stream = SDL_RWFromConstMem(ScreenFont_png, ScreenFont_png_len);
	SDL_Surface *surf = IMG_Load_RW(stream, 1);
	screenFontTexture = SDL_CreateTextureFromSurface(mainRenderer, surf);
	SDL_SetTextureBlendMode(screenFontTexture, SDL_BLENDMODE_BLEND);
	rows = 26;
	cols = 68;
	content.resize(rows);
	for (int row=0; row<rows; row++) content[row].resize(cols);
	Clear();
	
	SetStringAtPosition("Hello world!", 1, 0);
	SetStringAtPosition("Welcome to Soda.", 0, 0);
}

void RenderTextDisplay() {
	int windowHeight = SdlGlue::GetWindowHeight();
	for (int row=0; row<rows; row++) {
		for (int col=0; col<content[row].size(); col++) {
			CellContent cc = content[row][col];
			if (cc.character) RenderCharAtPosition(cc.character, row, col, windowHeight);
		}
	}
}

//--------------------------------------------------------------------------------
// Private method implementations
//--------------------------------------------------------------------------------

void Clear() {
	for (int row=0; row<rows; row++) {
		for (int col=0; col<cols; col++) content[row][col].Clear();
	}
}

void SetCharAtPosition(long unicodeChar, int row, int column) {
	Uint8 character = (Uint8)unicodeChar;	// ToDo: map special characters
	content[row][column].character = character;
}

void SetStringAtPosition(const char *unicodeString, int stringBytes, int row, int column) {
	unsigned char *c = (unsigned char*)unicodeString;
	const unsigned char *end = c + stringBytes;
	while (c < end) {
		SetCharAtPosition(UTF8DecodeAndAdvance(&c), row, column++);
		if (column >= cols) {
			column = 0;
			row = row - 1;
			if (row < 0) break;
		}
	}
}

void SetStringAtPosition(String s, int row, int column) {
	SetStringAtPosition(s.c_str(), (int)s.LengthB(), row, column);
}

void RenderCharAtPosition(Uint8 character, int row, int column, int windowHeight) {
	const int srcCellWidth = 16;
	const int srcCellHeight = 24;
	const int destCellWidth = 14;
	const int destCellHeight = 22;
	SDL_Rect srcRect = { (character%16) * srcCellWidth, (character/16) * srcCellHeight, srcCellWidth, srcCellHeight };
	SDL_Rect destRect = { column * destCellWidth, windowHeight - (row+1) * destCellHeight, srcCellWidth, srcCellHeight };
	SDL_RenderCopyEx(mainRenderer, screenFontTexture, &srcRect, &destRect, 0, NULL, SDL_FLIP_NONE);
}
