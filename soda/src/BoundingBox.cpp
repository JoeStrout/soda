//
//  BoundingBox.cpp
//  soda
//
//  Created by Joe Strout on 8/23/21.
//

#include "BoundingBox.h"
#include <math.h>

bool BoundingBox::Contains(Vector2 point) {
	// Start by converting the point into box coordinates.
	point -= center;
	if (rotation != 0.0) {
		float sinAng = sin(-rotation);
		float cosAng = cos(-rotation);
		point = Vector2(point.x * cosAng - point.y * sinAng, point.y * cosAng + point.x * sinAng);
	}
	// Then do a simple bounds check.
	return point.x > -halfSize.x && point.x < halfSize.x && point.y > -halfSize.y && point.y < halfSize.y;
}

bool BoundingBox::Intersects(BoundingBox other) {
	if (rotation == 0.0 && other.rotation == 0.0) {
		// Axis-aligned bounding boxes: special case we can test very quickly.
		if (center.x + halfSize.x < other.center.x - other.halfSize.x) return false;
		if (center.x - halfSize.x > other.center.x + other.halfSize.x) return false;
		if (center.y + halfSize.y < other.center.y - other.halfSize.y) return false;
		if (center.y - halfSize.y > other.center.y + other.halfSize.y) return false;
		return true;
	}
	
	// Otherwise, for now...
	return false;
}

void BoundingBox::Recompute() {
	// rocalculate corner, axis, and origin
}

