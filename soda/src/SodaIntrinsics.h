//
//  SodaIntrinsics.hpp
//  soda
//
//  Created by Joe Strout on 7/29/21.
//

#ifndef SODAINTRINSICS_H
#define SODAINTRINSICS_H

#include <stdio.h>
#include "MiniScript/MiniscriptTypes.h"

void AddSodaIntrinsics();

extern MiniScript::Value spriteList;
extern MiniScript::Value mouse;
extern MiniScript::ValueDict imageClass;
extern MiniScript::ValueDict soundClass;
extern MiniScript::ValueDict window;

extern MiniScript::Value white;
extern MiniScript::Value xStr;
extern MiniScript::Value yStr;
extern MiniScript::Value widthStr;
extern MiniScript::Value heightStr;
extern MiniScript::Value rotationStr;
extern MiniScript::Value scaleStr;

#endif /* SODAINTRINSICS_H */
