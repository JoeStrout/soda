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
#include <SDL2/SDL.h>
#include "MiniScript/String.h"
#include "MiniScript/MiniscriptTypes.h"

namespace SdlGlue {

void Setup();
void Service();
void Shutdown();

void DoSdlTest();
bool IsKeyPressed(MiniScript::String keyName);
bool IsMouseButtonPressed(int buttonNum);
int GetMouseX();
int GetMouseY();
int GetWindowWidth();
void SetWindowWidth(int width);
int GetWindowHeight();
void SetWindowHeight(int height);
bool GetFullScreen();
void SetFullScreen(bool fullScreen);
MiniScript::String GetBackgroundColor();
void SetBackgroundColor(MiniScript::String colorStr);

double GetAxis(MiniScript::String axisName);
MiniScript::Value LoadImage(MiniScript::String path);
MiniScript::Value GetSubImage(MiniScript::Value image, int left, int bottom, int width, int height);
MiniScript::Value GetImagePixel(MiniScript::Value image, int x, int y);
void SetImagePixel(MiniScript::Value image, int x, int y, MiniScript::String colorStr);

void Print(MiniScript::String s);
void Clear();

// flag set to true when the user tries to quit the app (by closing the window, cmd-Q, etc.)
extern bool quit;

extern MiniScript::Value magicHandle;	// "_handle" (used for several intrinsic classes)

}

#endif /* SDLGLUE_H */
