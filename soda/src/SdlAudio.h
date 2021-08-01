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

namespace SdlGlue {

void SetupAudio();

void ShutdownAudio();

}

#endif /* SDLAUDIO_H */
