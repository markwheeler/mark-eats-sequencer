//
//  EatsExternalClockCalculator.h
//  Sequencer
//
//  Created by Mark Wheeler on 03/03/2013.
//  Copyright (c) 2013 Mark Eats. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface EatsExternalClockCalculator : NSObject

- (NSNumber *) externalClockTick:(uint64_t)timestamp;
- (void) resetExternalClock;

@end
