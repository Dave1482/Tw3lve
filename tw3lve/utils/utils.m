//
//  utils.m
//  tw3lve
//
//  Created by Tanay Findley on 4/9/19.
//  Copyright © 2019 Tanay Findley. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "utils.h"
#import "kernel_memory.h"
#import "kernel_slide.h"
#include "parameters.h"
#include "patchfinder64.h"
#include "offsets.h"

void setGID(gid_t gid, uint64_t proc) {
    if (getgid() == gid) return;
    uint64_t ucred = kernel_read64(proc + off_p_ucred);
    kernel_write32(proc + off_p_gid, gid);
    kernel_write32(proc + off_p_rgid, gid);
    kernel_write32(ucred + off_ucred_cr_rgid, gid);
    kernel_write32(ucred + off_ucred_cr_svgid, gid);
    NSLog(@"Overwritten GID to %i for proc 0x%llx", gid, proc);
}

void setUID (uid_t uid, uint64_t proc) {
    if (getuid() == uid) return;
    uint64_t ucred = kernel_read64(proc + off_p_ucred);
    kernel_write32(proc + off_p_uid, uid);
    kernel_write32(proc + off_p_ruid, uid);
    kernel_write32(ucred + off_ucred_cr_uid, uid);
    kernel_write32(ucred + off_ucred_cr_ruid, uid);
    kernel_write32(ucred + off_ucred_cr_svuid, uid);
    NSLog(@"Overwritten UID to %i for proc 0x%llx", uid, proc);
}

uint64_t selfproc() {
    static uint64_t proc = 0;
    if (!proc) {
        proc = kernel_read64(current_task + OFFSET(task, bsd_info));
        NSLog(@"Found proc 0x%llx for PID %i", proc, getpid());
    }
    return proc;
}

void rootMe (int both, uint64_t proc) {
    setUID(both, proc);
    setGID(both, proc);
}

void unsandbox (uint64_t proc) {
    NSLog(@"Unsandboxed proc 0x%llx", proc);
    uint64_t ucred = kernel_read64(proc + off_p_ucred);
    uint64_t cr_label = kernel_read64(ucred + off_ucred_cr_label);
    kernel_write64(cr_label + off_sandbox_slot, 0);
}



