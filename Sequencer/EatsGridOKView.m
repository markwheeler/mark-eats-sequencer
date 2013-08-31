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

@property BOOL                  ready;

@property Preferences           *sharedPreferences;

@end

@implementation EatsGridOKView

- (id) init
{
    self = [super init];
    if (self) {
        
        _currentFrame = 0;
        self.trailLength = TRAIL_LENGTH;
        self.okBrightness = [NSNumber numberWithInt:15];
        
        self.sharedPreferences = [Preferences sharedPreferences];

    }
    return self;
}

- (NSArray *) viewArray
{
    if( !self.visible ) return nil;
    
    if( !self.ready )
       [self prepareProperties];
    
    // Move the particles
    if (_currentFrame < self.height / 2 ) {
        [_particleA setObject:[NSNumber numberWithUnsignedInt:self.height / 2 - 1 - _currentFrame]  forKey:@"y"];
        [_particleB setObject:[NSNumber numberWithUnsignedInt:self.height / 2 + _currentFrame]  forKey:@"y"];
    } else if (_currentFrame <= (self.height / 2) + self.width - 2) {
        [_particleA setObject:[NSNumber numberWithUnsignedInt:_currentFrame - self.height / 2 + 1]  forKey:@"x"];
        [_particleB setObject:[NSNumber numberWithUnsignedInt:_currentFrame - self.height / 2 + 1]  forKey:@"x"];
    } else if (_currentFrame <= self.width + self.height - 3) {
        [_particleA setObject:[NSNumber numberWithUnsignedInt:_currentFrame - self.height / 2 + 2 - self.width]  forKey:@"y"];
        [_particleB setObject:[NSNumber numberWithUnsignedInt:self.height - 1 + self.width + self.height / 2 - 2 - _currentFrame]  forKey:@"y"];
    } else {
        _particleA = nil;
        _particleB = nil;
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
            if(x >= _okLeftMargin && x < _okLeftMargin + [okArray count] && y >= _okTopMargin && y < _okTopMargin + [[okArray objectAtIndex:0] count]) {
                if(!_particleA || x <= [[_particleA valueForKey:@"x"] unsignedIntValue])
                    [[gridArray objectAtIndex:x] insertObject:[[okArray objectAtIndex:x - _okLeftMargin] objectAtIndex:y - _okTopMargin] atIndex:y];
                else
                    [[gridArray objectAtIndex:x] insertObject:zero atIndex:y];
            } else {
                [[gridArray objectAtIndex:x] insertObject:zero atIndex:y];
            }
        }
    }
    
    // Add particle A
    if(_particleA) {
        [[gridArray objectAtIndex:[[_particleA valueForKey:@"x"] unsignedIntValue]] replaceObjectAtIndex:[[_particleA valueForKey:@"y"] unsignedIntValue]
                                                                                              withObject:[NSNumber numberWithUnsignedInt:15]];
    }
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
    
    // Save trail info
    if(_particleA) [_particleATrail addObject:[_particleA copy]];
    if(_particleB) [_particleBTrail addObject:[_particleB copy]];
    
    if([_particleATrail count] > TRAIL_LENGTH || (!_particleA && [_particleATrail count] > 0) ) {
        [_particleATrail removeObjectAtIndex:0];
        [_particleBTrail removeObjectAtIndex:0];
    }
    
    return gridArray;
}

- (void) prepareProperties
{
    _okLeftMargin = (self.width - [self.okArray count]) / 2;
    _okTopMargin = (self.height - [[self.okArray objectAtIndex:0] count]) / 2;
    
    // Set the particle start positions
    _particleA = [NSMutableDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithUnsignedInt:0], @"x", [NSNumber numberWithUnsignedInt:(self.height / 2) - 1], @"y", nil];
    _particleB = [NSMutableDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithUnsignedInt:0], @"x", [NSNumber numberWithUnsignedInt:(self.height / 2)], @"y", nil];
    _particleATrail = [NSMutableArray arrayWithCapacity:TRAIL_LENGTH];
    _particleBTrail = [NSMutableArray arrayWithCapacity:TRAIL_LENGTH];
    
    self.ready = YES;
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
