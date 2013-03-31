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
+ (uint64_t) calculateSwingNsForPosition:(uint)position type:(int)swingType amount:(int)swingAmount bpm:(uint)bpm qnPerMeasure:(uint)qnPerMeasure minQuantization:(uint)minQuantization;

@end
