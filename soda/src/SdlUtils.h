//	SdlUtils.h
//
//	This file defines SDL-related utilities for the Soda project.
//	Other files should always #include this one; don't try to
//	include SDL headers directly.


// Include the SDL headers.  This is much thornier than you might
// expect, as they are under a subfolder in the system path on
// some platforms but not others.

#include <SDL2/SDL.h>

#if _WIN32 || _WIN64
	#include <SDL2/SDL_image.h>
#else
	#include <SDL_image.h>
#endif

#include <SDL2/SDL_gamecontroller.h>

#include "QA.h"

// Error checking/trapping macros.

// Check a numeric result code from SDL.  These are < 0 in case of error.
#define SdlAssertOK(resultCode) MiniScript::_ErrorIf((resultCode)<0, SDL_GetError(), __FILE__, __LINE__)

// Use this only for the return values of SDL calls.
// If the value is null, we print the SDL_GetError message
// (which should be filled in by whatever caused the null result).
#define SdlAssertNotNull(ptr) MiniScript::_ErrorIf((ptr)==nullptr, SDL_GetError(), __FILE__, __LINE__)


// Use this for any other (non-SDL) null checks.
#define AssertNotNull(ptr) MiniScript::_ErrorIf((ptr)==nullptr, "Unexpected nullptr", __FILE__, __LINE__)
