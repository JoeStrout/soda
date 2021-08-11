//
//  Color.cpp
//  Represents a 32-bit color in Soda.

#include "Color.h"

static char hexDigits[] = "0123456789ABCDEF";

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

