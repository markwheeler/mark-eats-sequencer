//
//  EatsGridIntroView.m
//  Sequencer
//
//  Created by Mark Wheeler on 04/03/2013.
//  Copyright (c) 2013 Mark Eats. All rights reserved.
//

#import "EatsGridIntroView.h"

@interface EatsGridIntroView ()

#define FRAMERATE 60
#define TRAIL_LENGTH 6 // Won't show past 15
#define PAUSE_AT_END 10

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

@implementation EatsGridIntroView

#pragma mark - Public methods

- (id) initWithDelegate:(id)delegate width:(uint)w height:(uint)h
{
    self = [super init];
    if (self) {
        
        self.delegate = delegate;
        self.width = w;
        self.height = h;
        
        self.currentFrame = 0;
        
        // Generate the OK
        NSNumber *y = [NSNumber numberWithUnsignedInt:15];;
        NSNumber *n = [NSNumber numberWithUnsignedInt:0];
        self.okArray = [NSArray arrayWithObjects:[NSArray arrayWithObjects: y, y, y, y, nil],
                                                 [NSArray arrayWithObjects: y, n, n, y, nil],
                                                 [NSArray arrayWithObjects: y, y, y, y, nil],
                                                 [NSArray arrayWithObjects: n, n, n, n, nil],
                                                 [NSArray arrayWithObjects: n, n, n, n, nil],
                                                 [NSArray arrayWithObjects: y, y, y, y, nil],
                                                 [NSArray arrayWithObjects: n, y, n, n, nil],
                                                 [NSArray arrayWithObjects: y, n, y, y, nil],
                                                 nil];
        
        self.okLeftMargin = (self.width - [self.okArray count]) / 2;
        self.okTopMargin = (self.height - [[self.okArray objectAtIndex:0] count]) / 2;
        
        // Set the particle start positions
        self.particleA = [NSMutableDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithUnsignedInt:0], @"x", [NSNumber numberWithUnsignedInt:(self.height / 2) - 1], @"y", nil];
        self.particleB = [NSMutableDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithUnsignedInt:0], @"x", [NSNumber numberWithUnsignedInt:(self.height / 2)], @"y", nil];
        self.particleATrail = [NSMutableArray arrayWithCapacity:TRAIL_LENGTH];
        self.particleBTrail = [NSMutableArray arrayWithCapacity:TRAIL_LENGTH];

        [self startAnimation];
        
    }
    return self;
}

- (void) updateView
{
    [self updateAnimation:nil];
}

- (void) stopAnimation
{
    [self.animationTimer invalidate];
}



#pragma mark - Private methods

- (void) updateAnimation:(NSTimer *)sender
{
    // Generate the array
    NSMutableArray *gridArray = [NSMutableArray arrayWithCapacity:self.height * self.width];
    for(uint x = 0; x < self.width; x++) {
        [gridArray insertObject:[NSMutableArray arrayWithCapacity:self.height] atIndex:x];
        for(uint y = 0; y < self.height; y++) {
            // Put OK in
            if(x >= self.okLeftMargin && x < self.okLeftMargin + [self.okArray count] && y >= self.okTopMargin && y < self.okTopMargin + [[self.okArray objectAtIndex:0] count]) {
                if(!self.particleA || x <= [[self.particleA valueForKey:@"x"] unsignedIntValue])
                    [[gridArray objectAtIndex:x] insertObject:[[self.okArray objectAtIndex:x - self.okLeftMargin] objectAtIndex:y - self.okTopMargin] atIndex:y];
                else
                    [[gridArray objectAtIndex:x] insertObject:[NSNumber numberWithUnsignedInt:0] atIndex:y];
            } else {
                [[gridArray objectAtIndex:x] insertObject:[NSNumber numberWithUnsignedInt:0] atIndex:y];
            }
        }
    }
    
    // Add particle A
    if(self.particleA)
        [[gridArray objectAtIndex:[[self.particleA valueForKey:@"x"] unsignedIntValue]] replaceObjectAtIndex:[[self.particleA valueForKey:@"y"] unsignedIntValue]
                                                                                                  withObject:[NSNumber numberWithUnsignedInt:15]];
    // Add particle B
    if(self.particleB)
        [[gridArray objectAtIndex:[[self.particleB valueForKey:@"x"] unsignedIntValue]] replaceObjectAtIndex:[[self.particleB valueForKey:@"y"] unsignedIntValue]
                                                                                                  withObject:[NSNumber numberWithUnsignedInt:15]];
    // Draw trails
    for(int i = 0; i < [self.particleATrail count]; i++) {
        // startFix ensure the trails are correct when they first appear (before they are full length)
        int startFix = 0;
        if([self.particleATrail count] < TRAIL_LENGTH && self.particleA)
            startFix = TRAIL_LENGTH - (int)[self.particleATrail count];
        
        // The +1s in this maths make sure we don't end up setting 0 brightness
        NSNumber *brightness = [NSNumber numberWithFloat:floor((15.0 / (TRAIL_LENGTH + 1) ) * (i + 1 + startFix))];
        
        // Draw A
        uint x = [[[self.particleATrail objectAtIndex:i] valueForKey:@"x"] unsignedIntValue];
        uint y = [[[self.particleATrail objectAtIndex:i] valueForKey:@"y"] unsignedIntValue];
        if([[[gridArray objectAtIndex:x] objectAtIndex:y] integerValue] < [brightness integerValue]){
            [[gridArray objectAtIndex:x] replaceObjectAtIndex:y withObject:brightness];
        }
        
        // Draw B
        x = [[[self.particleBTrail objectAtIndex:i] valueForKey:@"x"] unsignedIntValue];
        y = [[[self.particleBTrail objectAtIndex:i] valueForKey:@"y"] unsignedIntValue];
        if([[[gridArray objectAtIndex:x] objectAtIndex:y] integerValue] < [brightness integerValue]){
            [[gridArray objectAtIndex:x] replaceObjectAtIndex:y withObject:brightness];
        }

    }
    
    // Update via delegate
    if([self.delegate respondsToSelector:@selector(updateGridWithArray:)])
        [self.delegate performSelector:@selector(updateGridWithArray:) withObject:gridArray];
    
    // Advance the frame counter
    self.currentFrame++;
    
    // Save trail info
    //if(self.particleA) [self.particleATrail insertObject:[self.particleA copy] atIndex:0];
    //if(self.particleB) [self.particleBTrail insertObject:[self.particleB copy] atIndex:0];
    if(self.particleA) [self.particleATrail addObject:[self.particleA copy]];
    if(self.particleB) [self.particleBTrail addObject:[self.particleB copy]];
    
    if([self.particleATrail count] > TRAIL_LENGTH || (!self.particleA && [self.particleATrail count] > 0) ) {
        //[self.particleATrail removeLastObject];
        //[self.particleBTrail removeLastObject];
        [self.particleATrail removeObjectAtIndex:0];
        [self.particleBTrail removeObjectAtIndex:0];
    }
    
    // Move the particles
    if (self.currentFrame <= self.height / 2 - 1) {
        [self.particleA setObject:[NSNumber numberWithUnsignedInt:[[self.particleA valueForKey:@"y"] unsignedIntValue] - 1]  forKey:@"y"];
        [self.particleB setObject:[NSNumber numberWithUnsignedInt:[[self.particleB valueForKey:@"y"] unsignedIntValue] + 1]  forKey:@"y"];
    } else if (self.currentFrame <= (self.height / 2) + self.width - 2) {
        [self.particleA setObject:[NSNumber numberWithUnsignedInt:[[self.particleA valueForKey:@"x"] unsignedIntValue] + 1]  forKey:@"x"];
        [self.particleB setObject:[NSNumber numberWithUnsignedInt:[[self.particleB valueForKey:@"x"] unsignedIntValue] + 1]  forKey:@"x"];
    } else if (self.currentFrame <= self.width + self.height - 3) {
        [self.particleA setObject:[NSNumber numberWithUnsignedInt:[[self.particleA valueForKey:@"y"] unsignedIntValue] + 1]  forKey:@"y"];
        [self.particleB setObject:[NSNumber numberWithUnsignedInt:[[self.particleB valueForKey:@"y"] unsignedIntValue] - 1]  forKey:@"y"];
    } else {
        self.particleA = nil;
        self.particleB = nil;
    }
    
    if (self.currentFrame > self.width + self.height - 2 + TRAIL_LENGTH + PAUSE_AT_END) [self stopAnimation];
}

- (void) startAnimation
{
    [self.animationTimer invalidate];
    self.animationTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 / FRAMERATE
                                                           target:self
                                                         selector:@selector(updateAnimation:)
                                                         userInfo:nil
                                                          repeats:YES];
    NSRunLoop *runloop = [NSRunLoop currentRunLoop];
    
    // Make sure we fire even when the UI is tracking mouse down stuff
    [runloop addTimer:self.animationTimer forMode: NSRunLoopCommonModes];
    [runloop addTimer:self.animationTimer forMode: NSEventTrackingRunLoopMode];

}


@end
