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
