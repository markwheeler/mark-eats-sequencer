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
#define TRAIL_LENGTH 2

@property NSTimer               *animationTimer;
@property uint                  currentFrame;
@property NSArray               *okArray;
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
        
        self.particleA = [NSMutableDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithUnsignedInt:0], @"x", [NSNumber numberWithUnsignedInt:(self.height / 2) - 1], @"y", nil];
        self.particleB = [NSMutableDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithUnsignedInt:0], @"x", [NSNumber numberWithUnsignedInt:(self.height / 2)], @"y", nil];
        
        NSNumber *y = [NSNumber numberWithUnsignedInt:15];;
        NSNumber *n = [NSNumber numberWithUnsignedInt:0];
        self.okArray = [NSArray arrayWithObjects:[NSArray arrayWithObjects: y, y, y, n, n, y, n, y, nil],
                                                 [NSArray arrayWithObjects: y, n, y, n, n, y, y, n, nil],
                                                 [NSArray arrayWithObjects: y, n, y, n, n, y, n, y, nil],
                                                 [NSArray arrayWithObjects: y, y, y, n, n, y, n, y, nil],
                                                 nil];
        [self startAnimation];
        
    }
    return self;
}



#pragma mark - Private methods

- (void) updateAnimation:(NSTimer *)sender
{
    NSMutableArray *gridArray = [NSMutableArray array];
    
    long leftMargin = (self.width - [[self.okArray objectAtIndex:0] count]) / 2;
    long topMargin = (self.height - [self.okArray count]) / 2;
    
    // Generate the columns
    for(uint x = 0; x < self.width; x++) {
        [gridArray insertObject:[NSMutableArray arrayWithCapacity:self.height] atIndex:x];
        // Generate the rows
        for(uint y = 0; y < self.height; y++) {
            // Put OK in
            if(x > leftMargin - 1 && x <= self.width - leftMargin - 1 && y > topMargin - 1 && y <= self.height - topMargin - 1) {
                if(!self.particleA || x <= [[self.particleA valueForKey:@"x"] unsignedIntValue])
                    [[gridArray objectAtIndex:x] insertObject:[[self.okArray objectAtIndex:y - topMargin] objectAtIndex:x - leftMargin] atIndex:y];
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
    
    // Update via delegate
    if([self.delegate respondsToSelector:@selector(updateGridWithArray:)])
        [self.delegate performSelector:@selector(updateGridWithArray:) withObject:gridArray];
    
    self.currentFrame++;
    
    for(int i = 0; i < TRAIL_LENGTH; i++) {
        // save past positions of particles?
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
    
    if (self.currentFrame > self.width + self.height - 2 + 10) [self stopAnimation];
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

- (void) stopAnimation
{
    [self.animationTimer invalidate];   
}

@end
