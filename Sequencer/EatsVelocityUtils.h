//
//  EatsVelocityUtils.h
//  Sequencer
//
//  Created by Mark Wheeler on 01/04/2013.
//  Copyright (c) 2013 Mark Eats. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface EatsVelocityUtils : NSObject

// Returns the velocity that a note should be with the groove applied
+ (uint) calculateVelocityForPosition:(uint)position baseVelocity:(uint)baseVelocity type:(int)swingType minQuantization:(uint)minQuantization;

@end