//
//  TextDisplay.h
//  soda

#ifndef TEXTDISPLAY_H
#define TEXTDISPLAY_H

#include "Color.h"
#include "SimpleVector.h"

struct SDL_Renderer;

namespace SdlGlue {

void SetupTextDisplay(SDL_Renderer* renderer);
void ShutdownTextDisplay();
void RenderTextDisplay();

struct CellContent {
	Uint8 character;
	Color foreColor;
	Color backColor;
	
	void Set(Uint8 aCharacter, Color aForeColor, Color aBackColor) {
		character = aCharacter;
		foreColor = aForeColor;
		backColor = aBackColor;
	}
	
	void Clear() { character = 0; }
};

class TextDisplay {
public:
	TextDisplay();
	void Clear();
	void SetCharAtPosition(long unicodeChar, int row, int column);
	void PutChar(long unicodeChar);
	void Print(MiniScript::String s, bool addLineBreak=true);
	void Render();
	
	void NoteWindowSizeChange(int newWidth, int newHeight);
	
	int GetRow() const { return cursorY; }
	void SetRow(int value) { cursorY = value < 0 ? 0 : (value >= rows ? rows-1 : value); }
	int GetColumn() const { return cursorX; }
	void SetColumn(int value) { cursorX = value < 0 ? 0 : (value >= cols ? cols-1 : value); }
	
	int rows;
	int cols;
	Color textColor;
	Color backColor;
	SimpleVector<SimpleVector<CellContent>> content;		// indexed by [row][column]

private:
//	void SetStringAtPosition(const char* s, int stringBytes, int row, int column);
//	void SetStringAtPosition(MiniScript::String s, int row, int column);
	void RenderCharAtPosition(Uint8 character, int row, int column, int windowHeight);
	void ScrollUp();
	
	int cursorX;
	int cursorY;
};

extern TextDisplay* mainTextDisplay;

}


#endif // TEXTDISPLAY_H
