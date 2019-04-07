//
//  utils.m
//  tw3lve
//
//  Created by Tanay Findley on 4/7/19.
//  Copyright © 2019 Tanay Findley. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "kernel_utils.h"
#import "offsetof.h"


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

uint64_t unsandbox(pid_t pid) {
    if (!pid) return NO;
    
    printf("[*] Unsandboxing pid %d\n", pid);
    
    uint64_t proc = proc_of_pid(pid); // pid's proccess structure on the kernel
    uint64_t ucred = KernelRead_64bits(proc + off_p_ucred); // pid credentials
    uint64_t cr_label = KernelRead_64bits(ucred + off_ucred_cr_label); // MAC label
    uint64_t orig_sb = KernelRead_64bits(cr_label + off_sandbox_slot);
    
    KernelWrite_64bits(cr_label + off_sandbox_slot /* First slot is AMFI's. so, this is second? */, 0); //get rid of sandbox by nullifying it
    
    return (KernelRead_64bits(KernelRead_64bits(ucred + off_ucred_cr_label) + off_sandbox_slot) == 0) ? orig_sb : NO;
}

