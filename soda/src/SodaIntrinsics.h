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

#endif /* SODAINTRINSICS_H */
