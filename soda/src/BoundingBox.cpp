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

bool BoundingBox::Intersects(BoundingBox& other) {
	if (rotation == 0.0 && other.rotation == 0.0) {
		// Axis-aligned bounding boxes: special case we can test very quickly.
		if (center.x + halfSize.x < other.center.x - other.halfSize.x) return false;
		if (center.x - halfSize.x > other.center.x + other.halfSize.x) return false;
		if (center.y + halfSize.y < other.center.y - other.halfSize.y) return false;
		if (center.y - halfSize.y > other.center.y + other.halfSize.y) return false;
		return true;
	}
	
	// Non-axis-aligned bounding boxes, we need to do Separation Axis Test.
	// Reference: http://flipcode.com/archives/2D_OBB_Intersection.shtml
	// (although that implementation fails to check all 4 required axes)
	if (dirty) Recompute();
	if (other.dirty) other.Recompute();
	
	for (int a = 0; a < 2; ++a) {

		// Find the extent of box 2 on axis a
		double t = Vector2::Dot(other.corner[0], axis[a]);
		double tMin = t, tMax = t;
		for (int c = 1; c < 4; ++c) {		// (starting at 1 because we handled 0 above)
			t = Vector2::Dot(other.corner[c], axis[a]);
			if (t < tMin) tMin = t;
			else if (t > tMax) tMax = t;
		}

		// We have to subtract off the origin.  Then,
		// see if [tMin, tMax] intersects [0, 1]
		if ((tMin > 1 + origin[a]) || (tMax < origin[a])) {
			// There was no intersection along this dimension;
			// the boxes cannot possibly overlap.
			//Debug.Log("Separation found on axis " + a + ": tMin=" + tMin + ", tMax=" + tMax + ", origin[a]=" + origin[a]);
			return false;
		}
	}
	
	// No overlap yet; but if the boxes have different rotations, then we
	// still have two more axes to check from the other box.
	if (rotation != other.rotation) {
		for (int a = 0; a < 2; ++a) {
			double t = Vector2::Dot(corner[0], other.axis[a]);

			// Find the extent of box 2 on axis a
			double tMin = t, tMax = t;
			for (int c = 0; c < 4; ++c) {
				t = Vector2::Dot(corner[c], other.axis[a]);
				if (t < tMin) tMin = t;
				else if (t > tMax) tMax = t;
			}

			// We have to subtract off the origin.  Then,
			// see if [tMin, tMax] intersects [0, 1]
			if ((tMin > 1 + other.origin[a]) || (tMax < other.origin[a])) {
				// There was no intersection along this dimension;
				// the boxes cannot possibly overlap.
				//Debug.Log("Separation found on axis " + (a+2) + ": tMin=" + tMin + ", tMax=" + tMax + ", origin[a]=" + other.origin[a]);
				return false;
			}
			//Debug.Log("No separation on axis " + (a+2) + ": tMin=" + tMin + ", tMax=" + tMax + ", origin[a]=" + other.origin[a]);
		}
	}

	// There was no dimension along which there is no intersection.
	// Therefore the boxes overlap.
	return true;
}

void BoundingBox::Recompute() {
	// rocalculate corner, axis, and origin
	float cosAng = cos(rotation);
	float sinAng = sin(rotation);
	float vx = halfSize.x;
	float vy = halfSize.y;
	
	corner[0] = Vector2(center.x - vx * cosAng + vy * sinAng, center.y - vy * cosAng - vx * sinAng);
	corner[1] = Vector2(center.x - vx * cosAng - vy * sinAng, center.y + vy * cosAng - vx * sinAng);
	corner[2] = Vector2(center.x + vx * cosAng - vy * sinAng, center.y + vy * cosAng + vx * sinAng);
	corner[3] = Vector2(center.x + vx * cosAng + vy * sinAng, center.y - vy * cosAng + vx * sinAng);
	
	axis[0] = corner[1] - corner[0];
	axis[1] = corner[3] - corner[0];

	// Make the length of each axis 1/edge length so we know any
	// dot product must be less than 1 to fall within the edge.
	for (int a = 0; a < 2; ++a) {
		axis[a] /= axis[a].SqrMagnitude();
		origin[a] = Vector2::Dot(corner[0], axis[a]);
	}
	
	dirty = false;
}

