//
//  EatsGridSubView.m
//  Sequencer
//
//  Created by Mark Wheeler on 22/03/2013.
//  Copyright (c) 2013 Mark Eats. All rights reserved.
//

#import "EatsGridSubView.h"

@implementation EatsGridSubView

- (id) init
{
    self = [super init];
    if (self) {
        self.width = 1;
        self.height = 1;
        self.opacity = 1;
        self.visible = YES;
        _enabled = YES;
    }
    return self;
}

- (NSArray *) viewArray
{
    // Over-ride this

    if( !self.visible || self.width < 1 || self.height < 1 ) return nil;
    
    // Displays all lights on
    
    NSMutableArray *viewArray = [NSMutableArray arrayWithCapacity:self.width];
    
    // Generate the columns with playhead
    for(uint x = 0; x < self.width; x++) {
        [viewArray insertObject:[NSMutableArray arrayWithCapacity:self.height] atIndex:x];
        // Generate the rows
        for(uint y = 0; y < self.height; y++) {
            [[viewArray objectAtIndex:x] insertObject:[NSNumber numberWithUnsignedInt:15] atIndex:y];
        }
    }
    
    return viewArray;
}

- (void) inputX:(uint)x y:(uint)y down:(BOOL)down
{
    // Over-ride this
}

@end
