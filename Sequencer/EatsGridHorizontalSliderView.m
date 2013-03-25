//
//  EatsGridHorizontalSliderView.m
//  Sequencer
//
//  Created by Mark Wheeler on 22/03/2013.
//  Copyright (c) 2013 Mark Eats. All rights reserved.
//

#import "EatsGridHorizontalSliderView.h"

@implementation EatsGridHorizontalSliderView

- (NSArray *) viewArray
{
    if( !self.visible ) return nil;
    
    uint percentageAsStep = roundf(((self.width - 1) / 100.0) * self.percentage);
    
    NSMutableArray *viewArray = [NSMutableArray arrayWithCapacity:self.width];
    
    // Generate the columns with playhead
    for(uint x = 0; x < self.width; x++) {
        [viewArray insertObject:[NSMutableArray arrayWithCapacity:self.height] atIndex:x];
        // Generate the rows
        for(uint y = 0; y < self.height; y++) {
            
            
            
            if( x == percentageAsStep )
                [[viewArray objectAtIndex:x] insertObject:[NSNumber numberWithUnsignedInt:15 * self.opacity] atIndex:y];
            else if ( x < percentageAsStep && self.fillBar )
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
        
        self.percentage = ( x / (self.width - 1.0) ) * 100.0;
        
        if([self.delegate respondsToSelector:@selector(eatsGridHorizontalSliderViewUpdated:)])
            [self.delegate performSelector:@selector(eatsGridHorizontalSliderViewUpdated:) withObject:self];
    }
}

@end
