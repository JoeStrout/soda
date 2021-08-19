//
//  Color.cpp
//  Represents a 32-bit color in Soda.

#include "Color.h"

static char hexDigits[] = "0123456789ABCDEF";


static Uint8 HexDigitVal(char c) {
	if (c >= '0' && c <= '9') return c - '0';
	if (c >= 'a' && c <= 'f') return c - 'a' + 10;
	if (c >= 'A' && c <= 'F') return c - 'A' + 10;
	return 0;
}

static Uint8 HexDigitsToByte(MiniScript::String s, size_t indexB=0) {
	if (s.LengthB() < indexB+1) return 0;
	return (HexDigitVal(s[indexB]) << 4) | HexDigitVal(s[indexB+1]);
}


MiniScript::String Color::ToString() {
	char result[] = "#00000000";
	result[1] = hexDigits[r >> 4];
	result[2] = hexDigits[r & 0xF];
	result[3] = hexDigits[g >> 4];
	result[4] = hexDigits[g & 0xF];
	result[5] = hexDigits[b >> 4];
	result[6] = hexDigits[b & 0xF];
	result[7] = hexDigits[a >> 4];
	result[8] = hexDigits[a & 0xF];
	return result;
}

Color ToColor(MiniScript::String s) {
	Color result;
	if (s.LengthB() < 7 || s[0] != '#') return result;
	result.r = HexDigitsToByte(s, 1);
	result.g = HexDigitsToByte(s, 3);
	result.b = HexDigitsToByte(s, 5);
	if (s.LengthB() < 9) result.a = 255;
	else result.a = HexDigitsToByte(s, 7);
	return result;
}
