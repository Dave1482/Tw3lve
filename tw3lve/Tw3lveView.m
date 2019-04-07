//
//  ViewController.m
//  tw3lve
//
//  Created by Tanay Findley on 4/7/19.
//  Copyright © 2019 Tanay Findley. All rights reserved.
//

#import "Tw3lveView.h"

#include "ms_offsets.h"
#include "machswap.h"
#include "VarHolder.h"
#include "patchfinder64.h"
#include "utils.h"
#include "kernel_utils.h"

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


/***********
 
    MAGIC
 
 ***********/

bool restoreFS = false;



void jelbrek()
{
    while (true)
    {
        runOnMainQueueWithoutDeadlocking(^{
            NSLog(@"Jailbreak Thread Started!");
        });
        
        if ((kslide = kbase - KERNEL_SEARCH_ADDRESS) != -1) {
            runOnMainQueueWithoutDeadlocking(^{
                NSLog(@"%@", [NSString stringWithFormat:@"TFP0: %x", tfp0]);
                NSLog(@"%@", [NSString stringWithFormat:@"KERNEL BASE: %llx", kbase]);
                NSLog(@"%@", [NSString stringWithFormat:@"KERNEL SLIDE: %llx", kslide]);
            });
        }
        
        ms_offsets_t *ms_offs = get_machswap_offsets();
        machswap_exploit(ms_offs, &tfp0, &kbase);
        kslide = kbase - KERNEL_SEARCH_ADDRESS;
        
        
        if (tfp0 == 0 || kbase == 0)
        {
            NSLog(@"Exploit Failed!");
            break;
        }
        
        init_kernel_utils(tfp0);
        
        runOnMainQueueWithoutDeadlocking(^{
            NSLog(@"%@", [NSString stringWithFormat:@"TFP0: %x", tfp0]);
            NSLog(@"%@", [NSString stringWithFormat:@"KERNEL BASE: %llx", kbase]);
            NSLog(@"%@", [NSString stringWithFormat:@"KERNEL SLIDE: %llx", kslide]);
        });
        
        
        //PATCHFINDER64
        InitPatchfinder(kbase, NULL);
        unsandbox(getpid());
        
        
        break;
        
    }
}



- (IBAction)jelbrekClik:(id)sender {

    runOnMainQueueWithoutDeadlocking(^{
        NSLog(@"Jailbreak Button Clicked!");
    });
    
    
    
    jelbrek();
}


@end
