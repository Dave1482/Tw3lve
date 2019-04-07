//
//  utils.h
//  tw3lve
//
//  Created by Tanay Findley on 4/7/19.
//  Copyright © 2019 Tanay Findley. All rights reserved.
//
#import <Foundation/Foundation.h>


BOOL PatchHostPriv(mach_port_t host);
uint64_t unsandbox(pid_t pid);
