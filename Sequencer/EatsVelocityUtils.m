//
//  EatsVelocityUtils.m
//  Sequencer
//
//  Created by Mark Wheeler on 01/04/2013.
//  Copyright (c) 2013 Mark Eats. All rights reserved.
//

#import "EatsVelocityUtils.h"

// These values as they are set create a start of bar very close to the SP1200, and the end of bar is close but not QUITE as extreme.

// This is the percentage between the velocity and 0 that it will end up at (eg, 64 becomes 64 * 0.7 )
#define LOW_VELOCITY_PULL 0.7

// This is the percentage between the velocity and 127 that it will end up at (eg, 64 becomes (127 - 64) * (1 - 0.2) )
#define HIGH_VELOCITY_PULL 0.2


@implementation EatsVelocityUtils

+ (uint) calculateVelocityForPosition:(uint)position baseVelocity:(uint)baseVelocity type:(int)swingType minQuantization:(uint)minQuantization
{
    // Position must be 0 - minQuantization - 1
    
    uint velocity = baseVelocity;
    float velocityDifference = 0;
    
    // Number of 64ths in each cycle
    uint velocityCycle = minQuantization / ( swingType / 8 );
    
    // This gives us the positioning of the note in 64ths
    uint positionInVelocityCycle = position % velocityCycle;
    
    uint eighthOfCycle = velocityCycle / 8;
    
    // Make start quieter
    if( positionInVelocityCycle < eighthOfCycle ) {
        
        velocityDifference = velocity - ( velocity * LOW_VELOCITY_PULL );
        velocityDifference *= ( eighthOfCycle - positionInVelocityCycle ) / (float)eighthOfCycle;

        velocity -= roundf( velocityDifference );
        
    // Make end louder
    } else if( positionInVelocityCycle >= velocityCycle - eighthOfCycle ) {
        
        velocityDifference = ( 127 - velocity ) * ( 1.0 - HIGH_VELOCITY_PULL );
        velocityDifference *= ( positionInVelocityCycle - velocityCycle + eighthOfCycle ) / (float)eighthOfCycle;
        
        velocity += roundf( velocityDifference );
    }
    
    //NSLog(@"Velocity %u", velocity );
    
    return velocity;
}

@end