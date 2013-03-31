//
//  EatsSwingUtils.m
//  Sequencer
//
//  Created by Mark Wheeler on 01/04/2013.
//  Copyright (c) 2013 Mark Eats. All rights reserved.
//

#import "EatsSwingUtils.h"

@implementation EatsSwingUtils

+ (NSArray *) swingArray
{
    return [NSArray arrayWithObjects:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:8], @"type", [NSNumber numberWithInt:50], @"amount", @"8th – 50 (Straight)", @"label", nil],
                                     [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:8], @"type", [NSNumber numberWithInt:54], @"amount", @"8th - 54", @"label", nil],
                                     [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:8], @"type", [NSNumber numberWithInt:58], @"amount", @"8th - 58", @"label", nil],
                                     [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:8], @"type", [NSNumber numberWithInt:63], @"amount", @"8th - 63", @"label", nil],
                                     [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:8], @"type", [NSNumber numberWithInt:67], @"amount", @"8th - 67 (Triplets)", @"label", nil],
                                     [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:8], @"type", [NSNumber numberWithInt:71], @"amount", @"8th - 71", @"label", nil],
                                     [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:0], @"type", [NSNumber numberWithInt:0], @"amount", @"-", @"label", nil],
                                     [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:16], @"type", [NSNumber numberWithInt:50], @"amount", @"16th – 50 (Straight)", @"label", nil],
                                     [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:16], @"type", [NSNumber numberWithInt:54], @"amount", @"16th - 54", @"label", nil],
                                     [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:16], @"type", [NSNumber numberWithInt:58], @"amount", @"16th - 58", @"label", nil],
                                     [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:16], @"type", [NSNumber numberWithInt:63], @"amount", @"16th - 63", @"label", nil],
                                     [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:16], @"type", [NSNumber numberWithInt:67], @"amount", @"16th - 67 (Triplets)", @"label", nil],
                                     [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:16], @"type", [NSNumber numberWithInt:71], @"amount", @"16th - 71", @"label", nil],
                                     nil];
}

// TODO Swing gets a note out of sync when playback is reversed (may nede to know which direction playback is going in this method to allow for it? ie, shift numbers 1 across?)

+ (uint64_t) calculateSwingNsForPosition:(uint)position type:(int)swingType amount:(int)swingAmount bpm:(uint)bpm qnPerMeasure:(uint)qnPerMeasure minQuantization:(uint)minQuantization
{
    // Position must be 0 - minQuantization
    
    // Number of 64ths in each cycle
    uint swingCycle = minQuantization / ( swingType / 2 );
    //uint velocityCycle = swingCycle * 4;
    
    // This gives us the positioning of the note in 64ths
    uint positionInSwingCycle = position % swingCycle;
    //uint positiongInVelocityCycle = position % velocityCycle;
    
    // Start working in NS
    uint64_t barInNs =  1000000000 * ( 60.0 / ( bpm / qnPerMeasure ) );
    uint64_t swingCycleInNs = barInNs / ( minQuantization / swingCycle );
    uint64_t swingInNs = 0;
    uint64_t positionRelativeToZero;
    uint64_t defaultPositionRelativeToZero;
    
    float swingAmountFactor = swingAmount * 0.01;
    
    // Make odd split longer
    if( positionInSwingCycle < swingCycle / 2 ) {
        //velocity = 120;
        
        positionRelativeToZero = ( (swingCycleInNs * swingAmountFactor ) / ( swingCycle / 2 ) ) * positionInSwingCycle;
        defaultPositionRelativeToZero = ( (swingCycleInNs * 0.5) / ( swingCycle / 2 ) ) * positionInSwingCycle;
        swingInNs = positionRelativeToZero - defaultPositionRelativeToZero;
        
        // Make even split shorter
    } else {
        //velocity = 40;
        
        positionRelativeToZero = swingCycleInNs * swingAmountFactor + ( (swingCycleInNs * ( 1.0 - swingAmountFactor )) / ( swingCycle / 2 ) ) * ( positionInSwingCycle - swingCycle / 2 );
        defaultPositionRelativeToZero = swingCycleInNs * 0.5 + ( (swingCycleInNs * 0.5) / ( swingCycle / 2 ) ) * ( positionInSwingCycle - swingCycle / 2 );
        swingInNs = positionRelativeToZero - defaultPositionRelativeToZero;
        
    }
    
    return swingInNs;
}

@end
