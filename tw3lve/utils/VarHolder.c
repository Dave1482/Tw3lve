//
//  VarHolder.c
//  tw3lve
//
//  Created by Tanay Findley on 4/7/19.
//  Copyright © 2019 Tanay Findley. All rights reserved.
//
#include <mach/port.h>
#include "VarHolder.h"

mach_port_t tfp0 = MACH_PORT_NULL;
uint64_t kslide = -1;
uint64_t kbase;
uint64_t cr_label2;

uint64_t newUcred;
uint64_t owoproc;

void setCR(uint64_t set)
{
    cr_label2 = set;
}

void setOwOProc(uint64_t set)
{
    owoproc = set;
}

void setUcred(uint64_t set)
{
    newUcred = set;
}

