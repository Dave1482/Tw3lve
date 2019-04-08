//
//  utils.m
//  tw3lve
//
//  Created by Tanay Findley on 4/7/19.
//  Copyright © 2019 Tanay Findley. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <sys/event.h>
#import "kernel_utils.h"
#import "offsetof.h"


#include "OffsetHolder.h"
#include "find_port.h"
#include "machswap.h"


BOOL PatchHostPriv(mach_port_t host) {
    
#define IO_ACTIVE 0x80000000
#define IKOT_HOST_PRIV 4
    
    // locate port in kernel
    uint64_t host_kaddr = FindPortAddress(host);
    
    // change port host type
    uint32_t old = KernelRead_32bits(host_kaddr + 0x0);
    printf("[-] Old host type: 0x%x\n", old);
    
    KernelWrite_32bits(host_kaddr + 0x0, IO_ACTIVE | IKOT_HOST_PRIV);
    
    uint32_t new = KernelRead_32bits(host_kaddr);
    printf("[-] New host type: 0x%x\n", new);
    
    return ((IO_ACTIVE | IKOT_HOST_PRIV) == new) ? YES : NO;
}




uint64_t task_self_addr()
{
    return find_port_address(mach_task_self(), MACH_MSG_TYPE_COPY_SEND);
}


