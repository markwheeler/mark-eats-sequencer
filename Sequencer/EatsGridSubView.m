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
        _width = 1;
        _height = 1;
        _opacity = 1;
        _visible = YES;
    }
    return self;
}

- (NSArray *) viewArray
{
    // Over-ride this
    
    // Displays all lights on

    if( !_visible ) return nil;
    
    NSMutableArray *viewArray = [NSMutableArray arrayWithCapacity:_width];
    
    // Generate the columns with playhead
    for(uint x = 0; x < _width; x++) {
        [viewArray insertObject:[NSMutableArray arrayWithCapacity:_height] atIndex:x];
        // Generate the rows
        for(uint y = 0; y < _height; y++) {
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
