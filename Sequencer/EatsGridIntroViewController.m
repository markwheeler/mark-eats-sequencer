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

@property BOOL                  logFirst;

@end

@implementation EatsGridIntroViewController

- (void) setupView
{
    NSLog(@"Start setting up GridIntroView");
    
    dispatch_sync(self.gridQueue, ^(void) {
        [self createSubViews];
    });
    
    // Size KVO
    [self addObserver:self forKeyPath:@"width" options:NSKeyValueObservingOptionNew context:NULL];
    [self addObserver:self forKeyPath:@"height" options:NSKeyValueObservingOptionNew context:NULL];
    
    [self startAnimation];
    
    NSLog(@"Done setting up GridIntroView");

}

- (void) dealloc
{
    [self removeObserver:self forKeyPath:@"width"];
    [self removeObserver:self forKeyPath:@"height"];
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context {
    
    [self stopAnimation];
    dispatch_async(self.gridQueue, ^(void) {
        [self createSubViews];
        [self startAnimation];
    });
}

- (void) createSubViews
{
    // Create the sub view
    self.okView = [[EatsGridOKView alloc] init];
    self.okView.delegate = self;
    self.okView.x = 0;
    self.okView.y = 0;
    self.okView.width = self.width;
    self.okView.height = self.height;
    
    self.subViews = [NSMutableSet setWithObject:self.okView];
}

- (void) stopAnimation
{
    [self.animationTimer invalidate];
}

- (void) startAnimation
{
    dispatch_async(dispatch_get_main_queue(), ^(void) {
        NSLog(@"Start intro animation");
        [self.animationTimer invalidate];
        self.animationTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 / FRAMERATE
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
        if( !self.logFirst )
            NSLog(@"First intro view update from timer");
        [self updateView];
        if( !self.logFirst ) {
            NSLog(@"First intro view update from timer is done");
            self.logFirst = YES;
        }
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
