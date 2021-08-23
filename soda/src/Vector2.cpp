//
//  Vector2.h
//  Represents a 2d vector in Soda.
//

#include "Vector2.h"

// Binary operators
Vector2 operator+ (const Vector2& v1, const Vector2& v2) {
	return Vector2(v1.x + v2.x, v1.y + v2.y);
}

Vector2 operator- (const Vector2& v1, const Vector2& v2) {
	return Vector2(v1.x - v2.x, v1.y - v2.y);
}

Vector2 operator* (const Vector2& v1, float scalar) {
	return Vector2(v1.x * scalar, v1.y * scalar);
}

Vector2 operator/ (const Vector2& v1, float scalar) {
	return Vector2(v1.x / scalar, v1.y / scalar);
}
