//
//  Sprite.h
//	This file defines the classes that work together to implement the Sprite
//	class in Soda.
//
//  Created by Joe Strout on 10/4/21.
//

#ifndef SPRITE_H
#define SPRITE_H

#include "MiniscriptTypes.h"
#include "BoundingBox.h"

// SpriteHandleData: POD class that contains the extra data we need
// to keep about a Sprite (mostly for efficiency).
class SpriteHandleData {
public:
	// Copies of the data we need to draw the sprite, kept here
	// so we don't have to look it all up from the sprite map
	// every frame.  We can tell when it's stale because the
	// transformChanged flag will be set.
	float x;
	float y;
	float scale;
	float rotation;
	
	// Flag set to true whenever the MiniScript properties corresponding
	// to the values above are changed; cleared when we copy those values
	// out (while drawing the sprite).
	bool transformChanged;
	
	// Flag also set to true when any property that affects the mapping
	// from local to world bounds is changed.  Cleared when we update
	// the world bounds.  This allows us to track changes to the sprite
	// transform.
	bool boundsChanged;
	
	// Value of the change counter on our local bounds when we last
	// updated the world bounds.  This allows us to track changes to
	// the local bounds itself.
	int lastLocalChangeCounter;
	
	MiniScript::Value worldBounds;	// world bounds we computed earlier
};

// SpriteHandle: wraps and reference-counts a SpriteHandleData
// used as the _handle of a Sprite object in MiniScript.
class SpriteHandle : public MiniScript::RefCountedStorage {
public:
	SpriteHandle(SpriteHandleData *inData) : data(inData) {}
	
	virtual ~SpriteHandle() {
		delete data;
		data = nullptr;
	}
	
	SpriteHandleData* data;
};

// Helper method to get the handle data associated with a MiniScript sprite.
// If we don't already have such handle data, create and attach it now.
SpriteHandleData* GetSpriteHandleData(MiniScript::Value spriteMap);

#endif /* SPRITE_H */
