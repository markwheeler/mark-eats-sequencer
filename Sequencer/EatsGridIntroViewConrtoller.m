//
//  EatsGridIntroViewController.m
//  Sequencer
//
//  Created by Mark Wheeler on 04/03/2013.
//  Copyright (c) 2013 Mark Eats. All rights reserved.
//

#import "EatsGridIntroViewController.h"
#import "EatsGridNavigationController.h"

@interface EatsGridIntroViewController ()

#define FRAMERATE 60
#define TRAIL_LENGTH 6 // Won't show past 15

@property NSTimer               *animationTimer;
@property uint                  currentFrame;

@property NSArray               *okArray;
@property long                  okLeftMargin;
@property long                  okTopMargin;
@property NSMutableDictionary   *particleA;
@property NSMutableDictionary   *particleB;
@property NSMutableArray        *particleATrail;
@property NSMutableArray        *particleBTrail;

@end

@implementation EatsGridIntroViewController

#pragma mark - Public methods

- (id) initWithDelegate:(id)delegate width:(uint)w height:(uint)h
{
    self = [super init];
    if (self) {
        
        _delegate = delegate;
        _width = w;
        _height = h;
        
        _currentFrame = 0;
        
        // Generate the OK
        NSNumber *y = [NSNumber numberWithUnsignedInt:15];;
        NSNumber *n = [NSNumber numberWithUnsignedInt:0];
        _okArray = [NSArray arrayWithObjects:[NSArray arrayWithObjects: y, y, y, y, nil],
                                                 [NSArray arrayWithObjects: y, n, n, y, nil],
                                                 [NSArray arrayWithObjects: y, y, y, y, nil],
                                                 [NSArray arrayWithObjects: n, n, n, n, nil],
                                                 [NSArray arrayWithObjects: n, n, n, n, nil],
                                                 [NSArray arrayWithObjects: y, y, y, y, nil],
                                                 [NSArray arrayWithObjects: n, y, n, n, nil],
                                                 [NSArray arrayWithObjects: y, n, y, y, nil],
                                                 nil];
        
        _okLeftMargin = (_width - [_okArray count]) / 2;
        _okTopMargin = (_height - [[_okArray objectAtIndex:0] count]) / 2;
        
        // Set the particle start positions
        _particleA = [NSMutableDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithUnsignedInt:0], @"x", [NSNumber numberWithUnsignedInt:(_height / 2) - 1], @"y", nil];
        _particleB = [NSMutableDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithUnsignedInt:0], @"x", [NSNumber numberWithUnsignedInt:(_height / 2)], @"y", nil];
        _particleATrail = [NSMutableArray arrayWithCapacity:TRAIL_LENGTH];
        _particleBTrail = [NSMutableArray arrayWithCapacity:TRAIL_LENGTH];

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(gridInput:)
                                                     name:@"GridInput"
                                                   object:nil];
        
        
        [self startAnimation];
        
    }
    return self;
}

- (void) dealloc
{
    [self stopAnimation];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void) updateView
{
    [self updateAnimation:nil];
}

- (void) stopAnimation
{
    [_animationTimer invalidate];
}



#pragma mark - Private methods

- (void) updateAnimation:(NSTimer *)sender
{
    // Generate the array
    NSMutableArray *gridArray = [NSMutableArray arrayWithCapacity:_height * _width];
    for(uint x = 0; x < _width; x++) {
        [gridArray insertObject:[NSMutableArray arrayWithCapacity:_height] atIndex:x];
        for(uint y = 0; y < _height; y++) {
            // Put OK in
            if(x >= _okLeftMargin && x < _okLeftMargin + [_okArray count] && y >= _okTopMargin && y < _okTopMargin + [[_okArray objectAtIndex:0] count]) {
                if(!_particleA || x <= [[_particleA valueForKey:@"x"] unsignedIntValue])
                    [[gridArray objectAtIndex:x] insertObject:[[_okArray objectAtIndex:x - _okLeftMargin] objectAtIndex:y - _okTopMargin] atIndex:y];
                else
                    [[gridArray objectAtIndex:x] insertObject:[NSNumber numberWithUnsignedInt:0] atIndex:y];
            } else {
                [[gridArray objectAtIndex:x] insertObject:[NSNumber numberWithUnsignedInt:0] atIndex:y];
            }
        }
    }
    
    // Add particle A
    if(_particleA)
        [[gridArray objectAtIndex:[[_particleA valueForKey:@"x"] unsignedIntValue]] replaceObjectAtIndex:[[_particleA valueForKey:@"y"] unsignedIntValue]
                                                                                                  withObject:[NSNumber numberWithUnsignedInt:15]];
    // Add particle B
    if(_particleB)
        [[gridArray objectAtIndex:[[_particleB valueForKey:@"x"] unsignedIntValue]] replaceObjectAtIndex:[[_particleB valueForKey:@"y"] unsignedIntValue]
                                                                                                  withObject:[NSNumber numberWithUnsignedInt:15]];
    // Draw trails
    for(int i = 0; i < [_particleATrail count]; i++) {
        // startFix ensure the trails are correct when they first appear (before they are full length)
        int startFix = 0;
        if([_particleATrail count] < TRAIL_LENGTH && _particleA)
            startFix = TRAIL_LENGTH - (int)[_particleATrail count];
        
        // The +1s in this maths make sure we don't end up setting 0 brightness
        NSNumber *brightness = [NSNumber numberWithFloat:floor((15.0 / (TRAIL_LENGTH + 1) ) * (i + 1 + startFix))];
        
        // Draw A
        uint x = [[[_particleATrail objectAtIndex:i] valueForKey:@"x"] unsignedIntValue];
        uint y = [[[_particleATrail objectAtIndex:i] valueForKey:@"y"] unsignedIntValue];
        if([[[gridArray objectAtIndex:x] objectAtIndex:y] integerValue] < [brightness integerValue]){
            [[gridArray objectAtIndex:x] replaceObjectAtIndex:y withObject:brightness];
        }
        
        // Draw B
        x = [[[_particleBTrail objectAtIndex:i] valueForKey:@"x"] unsignedIntValue];
        y = [[[_particleBTrail objectAtIndex:i] valueForKey:@"y"] unsignedIntValue];
        if([[[gridArray objectAtIndex:x] objectAtIndex:y] integerValue] < [brightness integerValue]){
            [[gridArray objectAtIndex:x] replaceObjectAtIndex:y withObject:brightness];
        }

    }
    
    // Update via delegate
    if([_delegate respondsToSelector:@selector(updateGridWithArray:)])
        [_delegate performSelector:@selector(updateGridWithArray:) withObject:gridArray];
    
    // Advance the frame counter
    _currentFrame++;
    
    // Save trail info
    //if(_particleA) [_particleATrail insertObject:[_particleA copy] atIndex:0];
    //if(_particleB) [_particleBTrail insertObject:[_particleB copy] atIndex:0];
    if(_particleA) [_particleATrail addObject:[_particleA copy]];
    if(_particleB) [_particleBTrail addObject:[_particleB copy]];
    
    if([_particleATrail count] > TRAIL_LENGTH || (!_particleA && [_particleATrail count] > 0) ) {
        //[_particleATrail removeLastObject];
        //[_particleBTrail removeLastObject];
        [_particleATrail removeObjectAtIndex:0];
        [_particleBTrail removeObjectAtIndex:0];
    }
    
    // Move the particles
    if (_currentFrame <= _height / 2 - 1) {
        [_particleA setObject:[NSNumber numberWithUnsignedInt:[[_particleA valueForKey:@"y"] unsignedIntValue] - 1]  forKey:@"y"];
        [_particleB setObject:[NSNumber numberWithUnsignedInt:[[_particleB valueForKey:@"y"] unsignedIntValue] + 1]  forKey:@"y"];
    } else if (_currentFrame <= (_height / 2) + _width - 2) {
        [_particleA setObject:[NSNumber numberWithUnsignedInt:[[_particleA valueForKey:@"x"] unsignedIntValue] + 1]  forKey:@"x"];
        [_particleB setObject:[NSNumber numberWithUnsignedInt:[[_particleB valueForKey:@"x"] unsignedIntValue] + 1]  forKey:@"x"];
    } else if (_currentFrame <= _width + _height - 3) {
        [_particleA setObject:[NSNumber numberWithUnsignedInt:[[_particleA valueForKey:@"y"] unsignedIntValue] + 1]  forKey:@"y"];
        [_particleB setObject:[NSNumber numberWithUnsignedInt:[[_particleB valueForKey:@"y"] unsignedIntValue] - 1]  forKey:@"y"];
    } else {
        _particleA = nil;
        _particleB = nil;
    }
    
    if (_currentFrame > _width + _height - 2 + TRAIL_LENGTH) [self stopAnimation];
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

- (void) gridInput:(NSNotification *)notification
{
    // Ignore input if we're not active
    if( ![_delegate performSelector:@selector(isActive)] )
        return;
    
    if( ![[notification.userInfo valueForKey:@"down"] boolValue] ) {
        // Tell the delegate we're done
        if([_delegate respondsToSelector:@selector(showView:)])
            [_delegate performSelector:@selector(showView:) withObject:[NSNumber numberWithInt:EatsGridViewType_Sequencer]];
    }
}

@end
