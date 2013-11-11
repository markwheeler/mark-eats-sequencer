//
//  EatsSwingUtils.h
//  Sequencer
//
//  Created by Mark Wheeler on 01/04/2013.
//  Copyright (c) 2013 Mark Eats. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface EatsSwingUtils : NSObject

// Returns an array of dictionary objects with all the swing settings
+ (NSArray *) swingArray;

// Returns the amount of time in nanoseconds a note should be pushed back
+ (int64_t) calculateSwingNsForPosition:(uint)position type:(int)swingType amount:(int)swingAmount bpm:(float)bpm qnPerMeasure:(uint)qnPerMeasure minQuantization:(uint)minQuantization;

+ (int64_t) calculateNoteLengthAdjustmentNsForPosition:(uint)position type:(int)swingType amount:(int)swingAmount bpm:(float)bpm qnPerMeasure:(uint)qnPerMeasure minQuantization:(uint)minQuantization stepLength:(uint)stepLength;

@end
