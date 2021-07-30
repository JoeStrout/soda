//
//  SdlGlue.hpp
//  soda
//
//  Created by Joe Strout on 7/29/21.
//

#ifndef SDLGLUE_H
#define SDLGLUE_H

#include <stdio.h>
#include "MiniScript/String.h"

namespace SdlGlue {

void Setup();
void Service();
void Shutdown();

void DoSdlTest();
bool IsKeyPressed(MiniScript::String keyName);

// flag set to true when the user tries to quit the app (by closing the window, cmd-Q, etc.)
extern bool quit;

}

#endif /* SDLGLUE_H */
