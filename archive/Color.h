//
//  Color.h
//  Represents a 32-bit color in Soda.
//

#ifndef COLOR_H
#define COLOR_H

#include <stdio.h>
#include "SdlUtils.h"
#include "MiniScript/SimpleString.h"

union Color;

// toBigEndian: swap a 32-bit value from native to big-endian order.
#if (SDL_BYTEORDER == SDL_BIG_ENDIAN)
#define toBigEndian(x) (x)
#else
#define toBigEndian(x) SDL_Swap32(x)
#endif

// toNative: swap a 32-bit value from big-endian to native byte order.
#if (SDL_BYTEORDER == SDL_BIG_ENDIAN)
#define toNative(x) (x)
#else
#define toNative(x) SDL_Swap32(x)
#endif


union Color {
	// Note on pixel format and byte order: in memory, 4-byte pixels are always
	// stored in the order R, G, B, and A (i.e. big-endian order).
	// But if you write these as a 4-byte word (Uint32), on a little-endian machine,
	// these will be swapped; in source code form, you would write 0xAABBGGRR. 
	// However, that's a PITA, so we have a constructor (below) that takes a value 
	// in standard 0xRRGGBBAA order and swaps it around as needed.
	struct {
	Uint8 r;
	Uint8 g;
	Uint8 b;
	Uint8 a;
	};
	Uint32 asUint32;	// NOTE: in native order, i.e. ARGB on little-endian machines
	
	// Constructor taking separate R, G, B, and A values, all in range 0-255
	Color(Uint8 r, Uint8 g, Uint8 b, Uint8 a=255) : r(r), g(g), b(b), a(a) {}
	
	// Constructor taking a Uint32 hex code, 0xRRGGBBAA in source code form. 
	// This will be byte-swapped before storage on little-endian machines.
	Color(Uint32 rgba) : asUint32(toBigEndian(rgba)) {}
	
	// Default constructor: clear black.
	Color() : asUint32(0x00000000) {}
	
	MiniScript::String ToString();
	
	// Some standard colors (as in Mini Micro):
	static Color clear;
	static Color black;
	static Color white;
	static Color gray;
	static Color silver;
	static Color maroon;
	static Color red;
	static Color olive;
	static Color yellow;
	static Color orange;
	static Color green;
	static Color lime;
	static Color teal;
	static Color aqua;
	static Color navy;
	static Color blue;
	static Color purple;
	static Color fuchsia;
	static Color brown;
	static Color pink;
};

inline bool operator==(const Color& lhs, const Color& rhs) {
	return lhs.asUint32 == rhs.asUint32;
}

inline bool operator!=(const Color& lhs, const Color& rhs) {
	return lhs.asUint32 != rhs.asUint32;
}

Color ToColor(MiniScript::String s);

#endif /* COLOR_H */
