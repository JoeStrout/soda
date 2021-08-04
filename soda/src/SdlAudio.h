//
//  SdlAudio.h
//	This module forms the interface between SDL and the rest of Soda specifically
//	for audio support.
//
//  Created by Joe Strout on 8/1/21.
//

#ifndef SDLAUDIO_H
#define SDLAUDIO_H

#include <stdio.h>
#include "MiniscriptTypes.h"

namespace SdlGlue {

void SetupAudio();

MiniScript::Value LoadSound(MiniScript::String path);
void PlaySound(MiniScript::Value sound, double volume, double pan, double speed);
void StopSound(MiniScript::Value sound);
void StopAllSounds();

void ShutdownAudio();

}

#endif /* SDLAUDIO_H */
