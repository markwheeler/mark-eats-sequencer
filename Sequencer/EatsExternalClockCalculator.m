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

@property (nonatomic) NSMutableArray    *externalClockIntervals;
@property (nonatomic) uint64_t          externalPulsePreviousTimestamp;

@end


@implementation EatsExternalClockCalculator

- (id)init
{
    self = [super init];
    if (self) {
        _externalClockIntervals = [NSMutableArray arrayWithCapacity:MIDI_CLOCK_PPQN];
    }
    
    return self;
}


- (NSNumber *) externalClockTick:(uint64_t)timestamp
{
    
    if(_externalPulsePreviousTimestamp > 0) {
        [_externalClockIntervals addObject:[NSNumber numberWithLongLong:timestamp - _externalPulsePreviousTimestamp]];
    }
    
    // Keep track of pulses
    if([_externalClockIntervals count] < 24) { // This number defines how many pulses to average out before setting the BPM
        _externalPulsePreviousTimestamp = timestamp;
        
        return nil;
        
    // Average them out and return a new BPM
    } else {
        // Average out the last pulses
        float rangedAverageIntervalInNs = [self rangedAverage:_externalClockIntervals range:0.7]; // Range defines how extreme a peak has to be to consider it noise
        
        // Convert it into a BPM and return it
        // Secs in a min  ((interval in ns * MIDI standard ppqn ) / ns in a sec)
        float bpm = 60.0 / ((rangedAverageIntervalInNs * MIDI_CLOCK_PPQN) / 1000000000.0);
        
        // Reset everything
        [self resetExternalClock];
        
        return [NSNumber numberWithFloat:bpm];
    }
}

- (void) resetExternalClock
{
    [_externalClockIntervals removeAllObjects];
    _externalPulsePreviousTimestamp = 0;
}

- (float) rangedAverage:(NSMutableArray *)valueArray range:(float)r
{
    // Calculate average
    float total = 0;
    for(NSNumber *obj in valueArray) {
        total += [obj floatValue];
    }
    
    float average = total / [valueArray count];
    
    // Re-calculate average within range
    total = 0;
    int totalRemoved = 0;
    for(NSNumber *obj in valueArray) {
        
        if([obj longLongValue] < (average * r) || [obj longLongValue] > (average * (1+r))) { // TODO is there a bug in this code which means it is more generous below the average value than above it?? Also why should the range be dictated by the average? See noise remove in calibration code for a better way.
            //NSLog(@"Skipped interval of %fms", [obj floatValue] / 1000000000.0);
            totalRemoved++;
        } else {
            total += [obj longLongValue];
        }
    }
    average = total / ([valueArray count] - totalRemoved);
    
    //NSLog(@"Returned ranged average of %f (removed %i)", average / 1000000000.0, totalRemoved);
    return average;
}

@end
