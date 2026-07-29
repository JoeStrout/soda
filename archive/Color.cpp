//
//  Color.cpp
//  Represents a 32-bit color in Soda.

#include "Color.h"

static char hexDigits[] = "0123456789ABCDEF";

Color Color::clear =	Color(0x00000000);
Color Color::black =	Color(0x000000FF);
Color Color::white =	Color(0xFFFFFFFF);
Color Color::gray =	 	Color(0x808080FF);
Color Color::silver =	Color(0xC0C0C0FF);
Color Color::maroon =	Color(0x800000FF);
Color Color::red =	 	Color(0xFF0000FF);
Color Color::olive =	Color(0x808000FF);
Color Color::yellow =	Color(0xFFFF00FF);
Color Color::orange =	Color(0xFF8000FF);
Color Color::green =	Color(0x008000FF);
Color Color::lime =	 	Color(0x00FF00FF);
Color Color::teal =	 	Color(0x008080FF);
Color Color::aqua =	 	Color(0x00FFFFFF);
Color Color::navy =	 	Color(0x000080FF);
Color Color::blue =		Color(0x0000FFFF);
Color Color::purple =	Color(0x800080FF);
Color Color::fuchsia =	Color(0xFF00FFFF);
Color Color::brown =	Color(0x996633FF);
Color Color::pink =		Color(0xFF8080FF);

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
