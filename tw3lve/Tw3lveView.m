//
//  ViewController.m
//  tw3lve
//
//  Created by Tanay Findley on 4/7/19.
//  Copyright © 2019 Tanay Findley. All rights reserved.
//

#import "Tw3lveView.h"


#include "OffsetHolder.h"

#include "ms_offsets.h"
#include "machswap.h"
#include "VarHolder.h"
#include "patchfinder64.h"
#include "utils.h"

#include "voucher_swap.h"
#include "kernel_slide.h"
#include "kernel_memory.h"

#include "offsets.h"

#define KERNEL_SEARCH_ADDRESS 0xfffffff007004000
//ff8ffc000
@interface Tw3lveView ()
{
    IBOutlet UIButton *leButton;
}

@end

@implementation Tw3lveView



Tw3lveView *sharedController = nil;

- (void)viewDidLoad {
    [super viewDidLoad];
    sharedController = self;
}

+ (Tw3lveView *)sharedController {
    return sharedController;
}

/***
 Thanks Conor
 **/
void runOnMainQueueWithoutDeadlocking(void (^block)(void))
{
    if ([NSThread isMainThread])
    {
        block();
    }
    else
    {
        dispatch_sync(dispatch_get_main_queue(), block);
    }
}






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



/***********
 
    MAGIC
 
 ***********/

bool restoreFS = false;

bool voucher_swap_exp = false;

void jelbrek()
{
    while (true)
    {
        //Init Offsets
        offs_init();

        NSLog(@"Jailbreak Thread Started!");
        
        
        //Init Exploit
        if (voucher_swap_exp)
        {
            voucher_swap();
            tfp0 = kernel_task_port;
            kernel_slide_init();
            kbase = (kernel_slide + KERNEL_SEARCH_ADDRESS);
            
            //GET ROOT
            rootMe(0, selfproc());
            unsandbox(selfproc());
            
            
        } else {
            ms_offsets_t *ms_offs = get_machswap_offsets();
            machswap_exploit(ms_offs, &tfp0, &kbase);
            kernel_slide = (kbase - KERNEL_SEARCH_ADDRESS);
            //Machswap and Machswap2 already gave us undandboxing and root. Thanks! <3
            
        }
        

        //Log
        NSLog(@"%@", [NSString stringWithFormat:@"TFP0: %x", tfp0]);
        NSLog(@"%@", [NSString stringWithFormat:@"KERNEL BASE: %llx", kbase]);
        NSLog(@"%@", [NSString stringWithFormat:@"KERNEL SLIDE: %llx", kernel_slide]);
        
        NSLog(@"UID: %u", getuid());
        NSLog(@"GID: %u", getgid());
        
        const char *testFile = [NSString stringWithFormat:@"/var/mobile/test-%lu.txt", time(NULL)].UTF8String;
        _assert(create_file(testFile, 0, 0644), @"OWO This Is Bad!", true);
        _assert(clean_file(testFile), @"OWO This Is VERY Bad!", true);
        
        
        
        break;
        
    }
}



- (IBAction)jelbrekClik:(id)sender {

    runOnMainQueueWithoutDeadlocking(^{
        NSLog(@"Jailbreak Button Clicked!");
    });
    
    
    
    jelbrek();
}

- (IBAction)jelbrekA12Clik:(id)sender {
    
    runOnMainQueueWithoutDeadlocking(^{
        NSLog(@"Jailbreak Button Clicked! A12");
    });
    
    
    voucher_swap_exp = true;
    
    jelbrek();
}



@end
