//
//  EatsGridHorizontalShiftView.m
//  Sequencer
//
//  Created by Mark Wheeler on 20/07/2013.
//  Copyright (c) 2013 Mark Eats. All rights reserved.
//

#import "EatsGridHorizontalShiftView.h"

@implementation EatsGridHorizontalShiftView

- (NSArray *) viewArray
{
    if( !self.visible ) return nil;
    
    NSMutableArray *viewArray = [NSMutableArray arrayWithCapacity:self.width];
    
    // Generate the columns with playhead
    for(uint x = 0; x < self.width; x++) {
        [viewArray insertObject:[NSMutableArray arrayWithCapacity:self.height] atIndex:x];
        // Generate the rows
        for(uint y = 0; y < self.height; y++) {
            
            if( x == _zeroStep || x == _zeroStep + _shift )
                [[viewArray objectAtIndex:x] insertObject:[NSNumber numberWithUnsignedInt:15 * self.opacity] atIndex:y];
            else if ( ( _shift > 0 && x > _zeroStep && x < _zeroStep + _shift ) || ( _shift < 0 && x < _zeroStep && (int)x > (int)_zeroStep + _shift ) )
                [[viewArray objectAtIndex:x] insertObject:[NSNumber numberWithUnsignedInt:10 * self.opacity] atIndex:y];
            else
                [[viewArray objectAtIndex:x] insertObject:[NSNumber numberWithUnsignedInt:0] atIndex:y];
        }
    }
    
    return viewArray;
}

- (void) inputX:(uint)x y:(uint)y down:(BOOL)down
{
    // Down
    if( down ) {
        _shift = x - (int)_zeroStep;
        
        if([self.delegate respondsToSelector:@selector(eatsGridHorizontalShiftViewUpdated:)])
            [self.delegate performSelector:@selector(eatsGridHorizontalShiftViewUpdated:) withObject:self];
    }
}

@end
