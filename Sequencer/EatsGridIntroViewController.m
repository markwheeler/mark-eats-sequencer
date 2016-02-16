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
        [self createSubViews];
    });
    
    // Size KVO
    [self addObserver:self forKeyPath:@"width" options:NSKeyValueObservingOptionNew context:NULL];
    [self addObserver:self forKeyPath:@"height" options:NSKeyValueObservingOptionNew context:NULL];
    
    [self startAnimation];
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
        [self.animationTimer invalidate];
        self.animationTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 / FRAMERATE
                                                           target:self
                                                         selector:@selector(updateAnimation:)
                                                         userInfo:nil
                                                          repeats:YES];
        [self.animationTimer setTolerance:self.animationTimer.timeInterval * ANIMATION_TIMER_TOLERANCE];
        
        // Make sure we fire even when the UI is tracking mouse down stuff
        NSRunLoop *runloop = [NSRunLoop currentRunLoop];
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
