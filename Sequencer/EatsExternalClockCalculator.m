//
//  EatsExternalClockCalculator.m
//  Sequencer
//
//  Created by Mark Wheeler on 03/03/2013.
//  Copyright (c) 2013 Mark Eats. All rights reserved.
//

#import "EatsExternalClockCalculator.h"

@interface EatsExternalClockCalculator ()

#define MIDI_CLOCK_PPQN 24

@property NSMutableSet      *externalClockIntervals;
@property uint64_t          externalPulsePreviousTimestamp;

@end


@implementation EatsExternalClockCalculator

- (id)init
{
    self = [super init];
    if (self) {
        self.externalClockIntervals = [NSMutableSet setWithCapacity:MIDI_CLOCK_PPQN];
    }
    
    return self;
}


- (uint) externalClockTick:(uint64_t)timestamp
{
    
    uint bpm = 0;
    
    if(self.externalPulsePreviousTimestamp > 0) {
        [self.externalClockIntervals addObject:[NSNumber numberWithLongLong:timestamp - self.externalPulsePreviousTimestamp]];
    }
    
    if([self.externalClockIntervals count] < 24) { // This number defines how many pulses to average out before setting the BPM
        self.externalPulsePreviousTimestamp = timestamp;
        
    } else {
        // Average out the last pulses
        float rangedAverageIntervalInNs = [self rangedAverage:self.externalClockIntervals range:0.7]; // Range defines how extreme a peak has to be to consider it noise
        
        // Convert it into a BPM and return it
        // Secs in a min  ((interview in ns * MIDI standard ppqn / ns in a sec)
        bpm = 60 / ((rangedAverageIntervalInNs * MIDI_CLOCK_PPQN) / 1000000000.0);
        
        // Reset everything
        [self resetExternalClock];
    }
    
    return bpm;
}

- (void) resetExternalClock
{
    [self.externalClockIntervals removeAllObjects];
    self.externalPulsePreviousTimestamp = 0;
}

- (float) rangedAverage:(NSMutableSet *)valueSet range:(float)r
{
    // Calculate average
    float total = 0;
    for(NSNumber *obj in valueSet) {
        total += [obj floatValue];
    }
    
    float average = total / [valueSet count];
    
    // Re-calculate average within range
    total = 0;
    int totalRemoved = 0;
    for(NSNumber *obj in valueSet) {
        
        if([obj longLongValue] < (average * r) || [obj longLongValue] > (average * (1+r))) {
            //NSLog(@"Skipped interval of %fms", [obj floatValue] / 1000000000.0);
            totalRemoved++;
        } else {
            total += [obj longLongValue];
        }
    }
    average = total / ([valueSet count] - totalRemoved);
    
    //NSLog(@"Returned ranged average of %f (removed %i)", average / 1000000000.0, totalRemoved);
    return average;
}

@end
