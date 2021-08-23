//
//  BoundingBox.h
//	Represents a rectangular (possibly rotated) area, with support for
//	hit testing, intersection/overlap testing, etc.
//
//  Created by Joe Strout on 8/23/21.
//

#ifndef BOUNDINGBOX_H
#define BOUNDINGBOX_H

#include "Vector2.h"

class BoundingBox {
public:
	Vector2 center;
	Vector2 halfSize;
	double rotation;	// rotation angle in RADIANS
	
	int changeCounter;	// change counter
	bool dirty;			// true if corner, axis, and origin need recalculated
	
	Vector2 corner[4];	// corners of the box, where 0 is the lower left
	Vector2 axis[2];	// two edges of the box extended away from corner[0]
	double origin[2];	// origin[a] = corner[a].dot(axis[a])
	
	BoundingBox(Vector2 center, Vector2 halfSize, double rotation=0)
	: center(center), halfSize(halfSize), rotation(rotation), dirty(true) {}

	
	bool Contains(Vector2 point);
	bool Intersects(BoundingBox other);

	const Vector2* Corners() {
		if (dirty) Recompute();
		return corner;
	}
	
private:
	void Recompute();		// rocalculate corner, axis, and origin	
};


#endif // BOUNDINGBOX_H
