//
//  EatsGridIntroViewController.m
//  Sequencer
//
//  Created by Mark Wheeler on 19/08/2013.
//  Copyright (c) 2013 Mark Eats. All rights reserved.
//

#import "EatsGridIntroViewController.h"
#import "EatsGridNavigationController.h"

#define FRAMERATE 60

@interface EatsGridIntroViewController ()

@property EatsGridOKView        *okView;
@property NSTimer               *animationTimer;

@end

@implementation EatsGridIntroViewController

- (void) setupView
{
    dispatch_sync(self.gridQueue, ^(void) {
        // Create the sub view
        self.okView = [[EatsGridOKView alloc] init];
        self.okView.delegate = self;
        self.okView.x = 0;
        self.okView.y = 0;
        self.okView.width = self.width;
        self.okView.height = self.height;
        
        self.subViews = [NSSet setWithObject:self.okView];
    });
    
    [self startAnimation];

}

- (void) stopAnimation
{
    [_animationTimer invalidate];
}

- (void) startAnimation
{
    dispatch_async(dispatch_get_main_queue(), ^(void) {
        
        [_animationTimer invalidate];
        _animationTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 / FRAMERATE
                                                           target:self
                                                         selector:@selector(updateAnimation:)
                                                         userInfo:nil
                                                          repeats:YES];
        NSRunLoop *runloop = [NSRunLoop currentRunLoop];
        
        // Make sure we fire even when the UI is tracking mouse down stuff
        [runloop addTimer:_animationTimer forMode: NSRunLoopCommonModes];
        [runloop addTimer:_animationTimer forMode: NSEventTrackingRunLoopMode];
    });
}

- (void) updateAnimation:(NSTimer *)timer
{
    dispatch_async(self.gridQueue, ^(void) {
        self.okView.currentFrame ++;
        [self updateView];
    });
    
    // Commented this out so that OK keeps pulsing
    //if ( self.okView.currentFrame > self.okView.width + self.okView.height - 2 + self.okView.trailLength )
    //    [self stopAnimation];
}


- (void) eatsGridOKViewPressAt:(NSDictionary *)xyDown sender:(EatsGridOKView *)sender
{
    [self showView:[NSNumber numberWithInt:EatsGridViewType_Sequencer]];
}

@end
