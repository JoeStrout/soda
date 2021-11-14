//
//  Color.h
//  Represents a 32-bit color in Soda.
//

#ifndef COLOR_H
#define COLOR_H

#include <stdio.h>
#include <SDL2/SDL.h>
#include "MiniScript/SimpleString.h"

struct Color {
	Uint8 r;
	Uint8 g;
	Uint8 b;
	Uint8 a;
	
	Color(Uint8 r=255, Uint8 g=255, Uint8 b=255, Uint8 a=255) : r(r), g(g), b(b), a(a) {}
	MiniScript::String ToString();
};

Color ToColor(MiniScript::String s);

#endif /* COLOR_H */
