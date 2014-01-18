//
//  EatsGridOKView.m
//  Sequencer
//
//  Created by Mark Wheeler on 19/08/2013.
//  Copyright (c) 2013 Mark Eats. All rights reserved.
//

#import "EatsGridOKView.h"
#import "Preferences.h"

@interface EatsGridOKView ()

#define TRAIL_LENGTH 6

@property long                  okLeftMargin;
@property long                  okTopMargin;
@property NSMutableDictionary   *particleA;
@property NSMutableDictionary   *particleB;
@property NSMutableArray        *particleATrail;
@property NSMutableArray        *particleBTrail;

@property NSNumber              *okBrightness;

@property Preferences           *sharedPreferences;

@end

@implementation EatsGridOKView

- (id) init
{
    self = [super init];
    if (self) {
        
        self.currentFrame = 0;
        self.trailLength = TRAIL_LENGTH;
        self.okBrightness = [NSNumber numberWithInt:15];
        
        self.sharedPreferences = [Preferences sharedPreferences];
        
        self.particleATrail = [NSMutableArray arrayWithCapacity:TRAIL_LENGTH];
        self.particleBTrail = [NSMutableArray arrayWithCapacity:TRAIL_LENGTH];
        
        // Set the particle start positions
        self.particleA = [NSMutableDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithUnsignedInt:0], @"x", [NSNumber numberWithUnsignedInt:(self.height / 2) - 1], @"y", nil];
        self.particleB = [NSMutableDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithUnsignedInt:0], @"x", [NSNumber numberWithUnsignedInt:(self.height / 2)], @"y", nil];

    }
    return self;
}

- (NSArray *) viewArray
{
    if( !self.visible ) return nil;
    
    self.okLeftMargin = (self.width - [self.okArray count]) / 2;
    self.okTopMargin = (self.height - [[self.okArray objectAtIndex:0] count]) / 2;
    
    // Move the particles
    if (self.currentFrame < self.height / 2 ) {
        [self.particleA setObject:[NSNumber numberWithUnsignedInt:self.height / 2 - 1 - self.currentFrame]  forKey:@"y"];
        [self.particleB setObject:[NSNumber numberWithUnsignedInt:self.height / 2 + self.currentFrame]  forKey:@"y"];
    } else if (self.currentFrame <= (self.height / 2) + self.width - 2) {
        [self.particleA setObject:[NSNumber numberWithUnsignedInt:self.currentFrame - self.height / 2 + 1]  forKey:@"x"];
        [self.particleB setObject:[NSNumber numberWithUnsignedInt:self.currentFrame - self.height / 2 + 1]  forKey:@"x"];
    } else if (self.currentFrame <= self.width + self.height - 3) {
        [self.particleA setObject:[NSNumber numberWithUnsignedInt:self.currentFrame - self.height / 2 + 2 - self.width]  forKey:@"y"];
        [self.particleB setObject:[NSNumber numberWithUnsignedInt:self.height - 1 + self.width + self.height / 2 - 2 - self.currentFrame]  forKey:@"y"];
    } else {
        self.particleA = nil;
        self.particleB = nil;
    }
    
    // Pulse the OK if we support variable brightness
    if( self.sharedPreferences.gridSupportsVariableBrightness ) {
        int lengthOfPulseCycle = 90;
        int halfLengthOfPulseCycle = lengthOfPulseCycle / 2;
        int pulseCycle = self.currentFrame % lengthOfPulseCycle;
        if( pulseCycle < lengthOfPulseCycle / 2 )
            self.okBrightness = [NSNumber numberWithInt:4 + roundf(11.0 * ( (float)pulseCycle / halfLengthOfPulseCycle ) )];
        else
            self.okBrightness = [NSNumber numberWithInt:15 - roundf(11.0 * ( (float)( pulseCycle - halfLengthOfPulseCycle ) / halfLengthOfPulseCycle ) ) ];
    } else if( self.okBrightness.intValue != 15 ) {
        self.okBrightness = [NSNumber numberWithInt:15];
    }
    
    // Generate the array
    NSMutableArray *gridArray = [NSMutableArray arrayWithCapacity:self.height * self.width];
    NSNumber *zero = [NSNumber numberWithInt:0];
    NSArray *okArray = [self okArray];
    
    for(uint x = 0; x < self.width; x++) {
        [gridArray insertObject:[NSMutableArray arrayWithCapacity:self.height] atIndex:x];
        for(uint y = 0; y < self.height; y++) {
            // Put OK in
            if(x >= self.okLeftMargin && x < self.okLeftMargin + [okArray count] && y >= self.okTopMargin && y < self.okTopMargin + [[okArray objectAtIndex:0] count]) {
                if(!self.particleA || x <= [[self.particleA valueForKey:@"x"] unsignedIntValue])
                    [(NSMutableArray *)[gridArray objectAtIndex:x] insertObject:[[okArray objectAtIndex:x - self.okLeftMargin] objectAtIndex:y - self.okTopMargin] atIndex:y];
                else
                    [(NSMutableArray *)[gridArray objectAtIndex:x] insertObject:zero atIndex:y];
            } else {
                [(NSMutableArray *)[gridArray objectAtIndex:x] insertObject:zero atIndex:y];
            }
        }
    }
    
    // Add particle A
    if(self.particleA) {
        [[gridArray objectAtIndex:[[self.particleA valueForKey:@"x"] unsignedIntValue]] replaceObjectAtIndex:[[self.particleA valueForKey:@"y"] unsignedIntValue]
                                                                                              withObject:[NSNumber numberWithUnsignedInt:15]];
    }
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
    
    // Save trail info
    if(self.particleA) [self.particleATrail addObject:[self.particleA copy]];
    if(self.particleB) [self.particleBTrail addObject:[self.particleB copy]];
    
    if([self.particleATrail count] > TRAIL_LENGTH || (!self.particleA && [self.particleATrail count] > 0) ) {
        [self.particleATrail removeObjectAtIndex:0];
        [self.particleBTrail removeObjectAtIndex:0];
    }
    
    return gridArray;
}


- (void) inputX:(uint)x y:(uint)y down:(BOOL)down
{
    NSDictionary *xyDown = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithUnsignedInt:x], @"x",
                                                                      [NSNumber numberWithUnsignedInt:y], @"y",
                                                                      [NSNumber numberWithBool:down], @"down",
                                                                      nil];
    if([self.delegate respondsToSelector:@selector(eatsGridOKViewPressAt: sender:)])
        [self.delegate performSelector:@selector(eatsGridOKViewPressAt: sender:) withObject:xyDown withObject:self];
}

- (NSArray *) okArray {
    NSNumber *y = self.okBrightness;
    NSNumber *n = [NSNumber numberWithUnsignedInt:0];
    NSArray *okArray = [NSArray arrayWithObjects:[NSArray arrayWithObjects: y, y, y, y, nil],
                       [NSArray arrayWithObjects: y, n, n, y, nil],
                       [NSArray arrayWithObjects: y, y, y, y, nil],
                       [NSArray arrayWithObjects: n, n, n, n, nil],
                       [NSArray arrayWithObjects: n, n, n, n, nil],
                       [NSArray arrayWithObjects: y, y, y, y, nil],
                       [NSArray arrayWithObjects: n, y, n, n, nil],
                       [NSArray arrayWithObjects: y, n, y, y, nil],
                       nil];
    return okArray;
}



@end
