//
//  WMPool+Utils.h
//  Sequencer
//
//  Created by Mark Wheeler on 14/04/2013.
//  Copyright (c) 2013 Mark Eats. All rights reserved.
//

#import "WMPool.h"

@interface WMPool (Utils)

+ (NSArray *)sequenceOfNotesWithRootShortName:(NSString *)name scaleMode:(WMScaleMode *)mode length:(uint)length;

@end
