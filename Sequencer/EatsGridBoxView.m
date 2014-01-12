//
//  EatsGridBoxView.m
//  Sequencer
//
//  Created by Mark Wheeler on 30/12/2013.
//  Copyright (c) 2013 Mark Eats. All rights reserved.
//

#import "EatsGridBoxView.h"

@implementation EatsGridBoxView

- (id) init
{
    self = [super init];
    if (self) {
        self.brightness = 15;
    }
    return self;
}

- (NSArray *) viewArray
{
    if( !self.visible ) return nil;
    
    NSMutableArray *viewArray = [NSMutableArray arrayWithCapacity:self.width];
    
    // Generate the columns
    for(uint x = 0; x < self.width; x++) {
        [viewArray insertObject:[NSMutableArray arrayWithCapacity:self.height] atIndex:x];
        // Generate the rows
        for(uint y = 0; y < self.height; y++) {
            [[viewArray objectAtIndex:x] insertObject:[NSNumber numberWithUnsignedInt:self.brightness * self.opacity] atIndex:y];
        }
    }
    
    return viewArray;
}

@end
