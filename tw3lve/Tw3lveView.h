//
//  ViewController.h
//  tw3lve
//
//  Created by Tanay Findley on 4/7/19.
//  Copyright © 2019 Tanay Findley. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface Tw3lveView : UIViewController

@property (readonly) Tw3lveView *sharedController;

+ (Tw3lveView*)sharedController;

@end

