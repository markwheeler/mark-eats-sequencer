//
//  EatsQuantizationUtils.h
//  Sequencer
//
//  Created by Mark Wheeler on 18/08/2013.
//  Copyright (c) 2013 Mark Eats. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface EatsQuantizationUtils : NSObject

// Returns an array of dictionary objects with all the step quantization settings
+ (NSArray *) stepQuantizationArrayWithMinimum:(uint)min andMaximum:(uint)max;

// Returns an array of dictionary objects with all the pattern quantization settings
+ (NSArray *) patternQuantizationArrayWithMinimum:(uint)min andMaximum:(uint)max forGridWidth:(uint)gridWidth;

@end
