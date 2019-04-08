//
//  VarHolder.h
//  tw3lve
//
//  Created by Tanay Findley on 4/7/19.
//  Copyright © 2019 Tanay Findley. All rights reserved.
//

#ifndef VarHolder_h
#define VarHolder_h

#include <stdio.h>

extern mach_port_t tfp0;
extern uint64_t kslide;
extern uint64_t kbase;
extern uint64_t cr_label2;

extern uint64_t owoproc;
extern uint64_t newUcred;

void setCR(uint64_t set);
void setOwOProc(uint64_t set);
void setUcred(uint64_t set);

#endif /* VarHolder_h */
