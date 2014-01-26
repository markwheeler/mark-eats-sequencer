//
//  EatsGridHorizontalSliderView.m
//  Sequencer
//
//  Created by Mark Wheeler on 22/03/2013.
//  Copyright (c) 2013 Mark Eats. All rights reserved.
//

#import "EatsGridHorizontalSliderView.h"
#import "EatsGridUtils.h"

@implementation EatsGridHorizontalSliderView

- (NSArray *) viewArray
{
    if( !self.visible || self.width < 1 || self.height < 1 ) return nil;
    
    uint percentageAsStep = [EatsGridUtils percentageToSteps:self.percentage width:self.width];
    
    NSMutableArray *viewArray = [NSMutableArray arrayWithCapacity:self.width];
    
    // Generate the columns
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

        self.percentage = [EatsGridUtils stepsToPercentage:x width:self.width];
        
        if([self.delegate respondsToSelector:@selector(eatsGridHorizontalSliderViewUpdated:)])
            [self.delegate performSelector:@selector(eatsGridHorizontalSliderViewUpdated:) withObject:self];
    }
}

@end
