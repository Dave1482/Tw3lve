//
//  utils.h
//  tw3lve
//
//  Created by Tanay Findley on 4/7/19.
//  Copyright © 2019 Tanay Findley. All rights reserved.
//
#import <Foundation/Foundation.h>


BOOL PatchHostPriv(mach_port_t host);
void unsandbox(pid_t pid);

static inline bool create_file_data(const char *file, int owner, mode_t mode, NSData *data) {
    return [[NSFileManager defaultManager] createFileAtPath:@(file) contents:data attributes:@{
                                                                                               NSFileOwnerAccountID: @(owner),
                                                                                               NSFileGroupOwnerAccountID: @(owner),
                                                                                               NSFilePosixPermissions: @(mode)
                                                                                               }
            ];
}

static inline bool create_file(const char *file, int owner, mode_t mode) {
    return create_file_data(file, owner, mode, nil);
}

static inline bool clean_file(const char *file) {
    NSString *path = @(file);
    if ([[NSFileManager defaultManager] attributesOfItemAtPath:path error:nil]) {
        return [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
    }
    return YES;
}

