//
//  TextDisplay.cpp
//  This module implements the TextDisplay class, which displays text on the game window
//	using one of the built-in monospaced fonts.

#include "TextDisplay.h"
#include "compiledData/ScreenFont_png.h"
#include "SimpleVector.h"
#include "SdlUtils.h"
#include "SdlGlue.h"
#include "UnicodeUtil.h"
#include "Color.h"

using namespace MiniScript;
using namespace SdlGlue;

namespace SdlGlue {


// Public data
TextDisplay* mainTextDisplay = nullptr;

// Private data
static SDL_Renderer* mainRenderer = nullptr;
static SDL_Texture* screenFontTexture = nullptr;

// Forward declarations


//--------------------------------------------------------------------------------
// Public method implementations
//--------------------------------------------------------------------------------

TextDisplay::TextDisplay() : rows(26), cols(68) {
	textColor = Color(0, 255, 0);
	backColor = Color(0,0,0,0);
	content.resize(rows);
	for (int row=0; row<rows; row++) content[row].resize(cols);
	Clear();
}

void SetupTextDisplay(SDL_Renderer *renderer) {
	mainRenderer = renderer;
	
	SDL_RWops *stream = SDL_RWFromConstMem(ScreenFont_png, ScreenFont_png_len);
	SdlAssertNotNull(stream);
	SDL_Surface *surf = IMG_Load_RW(stream, 1);
	SdlAssertNotNull(surf);
	screenFontTexture = SDL_CreateTextureFromSurface(mainRenderer, surf);
	SdlAssertNotNull(screenFontTexture);
	SDL_SetTextureBlendMode(screenFontTexture, SDL_BLENDMODE_BLEND);

	mainTextDisplay = new TextDisplay();
}

void ShutdownTextDisplay() {
	SDL_DestroyTexture(screenFontTexture); screenFontTexture = nullptr;
	delete mainTextDisplay;	mainTextDisplay = nullptr;
}

void RenderTextDisplay() {
	mainTextDisplay->Render();
}

void TextDisplay::NoteWindowSizeChange(int newWidth, int newHeight) {
	int prevRows = rows;
	int prevCols = cols;
	rows = newHeight / 22;
	cols = newWidth / 14;
	if (rows == prevRows && cols == prevCols) return;
	content.resize(rows);
	for (int row=0; row<rows; row++) {
		content[row].resize(cols);
		if (row >= prevRows) prevCols = 0;
		for (int col=prevCols; col<cols; col++) content[row][col].Clear();
	}
	if (cursorY >= rows) cursorY = rows-1;
	if (cursorX >= cols) cursorX = cols-1;
}

void TextDisplay::Render() {
	int windowHeight = GetWindowHeight();
	for (int row=0; row<rows; row++) {
		for (int col=0; col<content[row].size(); col++) {
			CellContent cc = content[row][col];
			if (cc.character) {
				Color c = cc.foreColor;
				SDL_SetTextureColorMod(screenFontTexture, c.r, c.g, c.b);
				SDL_SetTextureAlphaMod(screenFontTexture, c.a);
				RenderCharAtPosition(cc.character, row, col, windowHeight);
			}
		}
	}
}

void TextDisplay::Clear() {
	for (int row=0; row<rows; row++) {
		for (int col=0; col<cols; col++) content[row][col].Clear();
	}
	cursorX = 0;
	cursorY = rows - 1;
}

void TextDisplay::SetCharAtPosition(long unicodeChar, int row, int column) {
	if (row >= rows || column >= cols) return;	// out of bounds
	Uint8 character = (Uint8)unicodeChar;

	if (character == 32) character = 0;		// don't draw spaces
	// ToDo: map other special characters

	content[row][column].Set(character, textColor, backColor);
}

//void TextDisplay::SetStringAtPosition(const char *unicodeString, int stringBytes, int row, int column) {
//	unsigned char *c = (unsigned char*)unicodeString;
//	const unsigned char *end = c + stringBytes;
//	while (c < end) {
//		SetCharAtPosition(UTF8DecodeAndAdvance(&c), row, column++);
//		if (column >= cols) {
//			column = 0;
//			row = row - 1;
//			if (row < 0) break;
//		}
//	}
//}
//
//void TextDisplay::SetStringAtPosition(String s, int row, int column) {
//	SetStringAtPosition(s.c_str(), (int)s.LengthB(), row, column);
//}

void TextDisplay::ScrollUp() {
	for (int row=rows-1; row>0; row--) {
		for (int col=0; col<cols; col++) content[row][col] = content[row-1][col];
	}
	for (int col=0; col<cols; col++) content[0][col].Clear();
}

void TextDisplay::PutChar(long unicodeChar) {
	if (unicodeChar == 9) {						// Tab
		cursorX = ((cursorX+3)/4) * 4;
	} else if (unicodeChar == 13) {				// Return
		cursorX = cols + 1;
	} else {
		SetCharAtPosition(unicodeChar, cursorY, cursorX++);
	}
	
	if (cursorX >= cols) {
		cursorX = 0;
		cursorY = cursorY - 1;
		if (cursorY < 0) {
			ScrollUp();
			cursorY = 0;
		}
	}
}

void TextDisplay::Print(String s) {
	if (cursorY >= rows) cursorY = rows-1;
	if (cursorX >= cols) cursorX = cols-1;

	unsigned char *c = (unsigned char*)(s.c_str());
	const unsigned char *end = c + s.LengthB();
	while (c < end) {
		PutChar(UTF8DecodeAndAdvance(&c));
	}
	PutChar(13);
}

//--------------------------------------------------------------------------------
// Private method implementations
//--------------------------------------------------------------------------------

void TextDisplay::RenderCharAtPosition(Uint8 character, int row, int column, int windowHeight) {
	const int srcCellWidth = 16;
	const int srcCellHeight = 24;
	const int destCellWidth = 14;
	const int destCellHeight = 22;
	SDL_Rect srcRect = { (character%16) * srcCellWidth, (character/16) * srcCellHeight, srcCellWidth, srcCellHeight };
	SDL_Rect destRect = { column * destCellWidth, windowHeight - (row+1) * destCellHeight, srcCellWidth, srcCellHeight };
	SDL_RenderCopyEx(mainRenderer, screenFontTexture, &srcRect, &destRect, 0, NULL, SDL_FLIP_NONE);
}


} // namespace SdlGlue

