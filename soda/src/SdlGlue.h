//
//  SdlGlue.h
//	This module forms the interface between SDL and the rest of Soda.  It handles all
//	the low-level SDL stuff (except for things complex enough to be split out into
//	their own module, such as audio).
//
//  Created by Joe Strout on 7/29/21.
//

#ifndef SDLGLUE_H
#define SDLGLUE_H

#include <stdio.h>
#include "MiniScript/String.h"
#include "MiniscriptTypes.h"

namespace SdlGlue {

void Setup();
void Service();
void Shutdown();

void DoSdlTest();
bool IsKeyPressed(MiniScript::String keyName);
bool IsMouseButtonPressed(int buttonNum);
int GetMouseX();
int GetMouseY();
double GetAxis(MiniScript::String axisName);
MiniScript::Value LoadImage(MiniScript::String path);
MiniScript::Value GetSubImage(MiniScript::Value image, int left, int bottom, int width, int height);

// flag set to true when the user tries to quit the app (by closing the window, cmd-Q, etc.)
extern bool quit;

extern MiniScript::Value magicHandle;	// "_handle" (used for several intrinsic classes)

}

#endif /* SDLGLUE_H */
