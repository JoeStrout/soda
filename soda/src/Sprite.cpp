//
//  Sprite.cpp
//  soda
//
//  Created by Joe Strout on 10/4/21.
//

#include "Sprite.h"
#include "SodaIntrinsics.h"
#include "SdlGlue.h"

using namespace MiniScript;

static bool spriteAssignOverride(ValueDict& spriteMap, MiniScript::Value key, Value value) {
	// If the value hasn't changed, do nothing.
	Value curVal = spriteMap.Lookup(key, Value::null);
	if (curVal == value) return not value.IsNull();	// (block the assignment, unless actually assigning null)
	
	String keyStr = key.ToString();
	if (keyStr == "x" || keyStr == "y" || keyStr == "rotation" || keyStr == "scale") {
		// The sprite transform has changed.  That means we need to invalidate
		// both the sprite handle data, and the local bounds.
		MiniScript::Value handle = spriteMap.Lookup(SdlGlue::magicHandle, Value::null);
		SpriteHandleData *data = nullptr;
		if (handle.type == ValueType::Handle) {
			// ToDo: how do we be sure the data is specifically a SoundStorage?
			// Do we need to enable RTTI, or use some common base class?
			data = ((SpriteHandleData*)(handle.data.ref));
		}
		if (data) data->boundsChanged = data->transformChanged = true;
	} else if (keyStr == "localBounds") {
		// ToDo: DRY this out.
		MiniScript::Value handle = spriteMap.Lookup(SdlGlue::magicHandle, Value::null);
		SpriteHandleData *data = nullptr;
		if (handle.type == ValueType::Handle) {
			// ToDo: how do we be sure the data is specifically a SoundStorage?
			// Do we need to enable RTTI, or use some common base class?
			data = ((SpriteHandleData*)(handle.data.ref));
		}
		if (data) data->boundsChanged = true;
	}
	
	return false;	// allow the assignment
}

// Helper method to get the handle data associated with a MiniScript sprite.
// If we don't already have such handle data, create and attach it now.
SpriteHandleData* GetSpriteHandleData(MiniScript::Value spriteMap) {
	// Get the handle associated with this sprite.
	// Note that we do NOT want to get some inherited handle — only look at a handle
	// defined on this map itself.
	ValueDict dict = spriteMap.GetDict();
	MiniScript::Value handle = dict.Lookup(SdlGlue::magicHandle, Value::null);	// does not walk __isa chain
	SpriteHandleData *data = nullptr;
	if (handle.IsNull()) {
		data = new SpriteHandleData();
		data->transformChanged = true;
		spriteMap.SetElem(SdlGlue::magicHandle, handle);
		spriteMap.GetDict().SetAssignOverride(spriteAssignOverride);
	} else {
		// ToDo: how do we be sure the data is specifically a SoundStorage?
		// Do we need to enable RTTI, or use some common base class?
		data = (SpriteHandleData*)(handle.data.ref);
	}
	if (data->transformChanged) {
		// Update the data with current values from the map.
		data->x = spriteMap.Lookup(xStr).DoubleValue();
		data->y = spriteMap.Lookup(yStr).DoubleValue();
		data->scale = spriteMap.Lookup(scaleStr).DoubleValue();
		data->scale = spriteMap.Lookup(rotationStr).DoubleValue();
		data->transformChanged = false;
	}
	return data;
}
