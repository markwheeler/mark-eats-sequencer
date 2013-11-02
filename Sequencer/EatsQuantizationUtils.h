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
+ (NSArray *) stepQuantizationArray;

// Returns an array of dictionary objects with all the pattern quantization settings
+ (NSArray *) patternQuantizationArrayForGridWidth:(uint)gridWidth;

@end
