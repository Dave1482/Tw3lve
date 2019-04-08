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
#include "kernel_utils.h"
#include "remap_tfp_set_hsp.h"

#include "voucher_swap.h"

#define KERNEL_SEARCH_ADDRESS 0xfffffff007004000
//ff8ffc000
@interface Tw3lveView ()
{
    IBOutlet UIButton *leButton;
}

@end

@implementation Tw3lveView



uint32_t proc_ucred;
uint64_t kern_ucred;




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

bool voucher_swap_exp = false;

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
        
        if (voucher_swap_exp)
        {
            voucher_swap();
        } else {
            ms_offsets_t *ms_offs = get_machswap_offsets();
            machswap_exploit(ms_offs, &tfp0, &kbase);
            kslide = kbase - KERNEL_SEARCH_ADDRESS;
        }
        
        
        if (!MACH_PORT_VALID(tfp0))
        {
            NSLog(@"Exploit Failed!");
            break;
        }
        
        runOnMainQueueWithoutDeadlocking(^{
            NSLog(@"%@", [NSString stringWithFormat:@"TFP0: %x", tfp0]);
            NSLog(@"%@", [NSString stringWithFormat:@"KERNEL BASE: %llx", kbase]);
            NSLog(@"%@", [NSString stringWithFormat:@"KERNEL SLIDE: %llx", kslide]);
        });
        
        
        //Unsandbox
        setOwO(tfp0);
        KernelWrite_64bits(cr_label + 0x10, 0);
        
        //SetUID shitz
        kern_ucred = get_kernel_addr();
        
        KernelWrite_64bits(ourproc + 0xf8, kern_ucred);
        
        
        
        
        
        //I AM gROOT
        if (getuid() == 0 && getgid() == 0)
        {
            NSLog(@"I AM G(ROOT)!");
        } else {
            NSLog(@"REBOOT ME OH MA GAW THE PAIN!");
            break;
        }
        
        NSLog(@"Writing a test file to UserFS...");
        const char *testFile = [NSString stringWithFormat:@"/var/mobile/test-%lu.txt", time(NULL)].UTF8String;
        _assert(create_file(testFile, 0, 0644), @"Failed!", true);
        _assert(clean_file(testFile), @"Failed!", true);
        NSLog(@"Successfully wrote a test file to UserFS.");
        
        
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
