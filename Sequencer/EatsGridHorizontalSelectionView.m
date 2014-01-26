//
//  EatsGridHorizontalSelectionView.m
//  Sequencer
//
//  Created by Mark Wheeler on 25/03/2013.
//  Copyright (c) 2013 Mark Eats. All rights reserved.
//

#import "EatsGridHorizontalSelectionView.h"
#import "EatsGridUtils.h"

@interface EatsGridHorizontalSelectionView ()

@property NSDictionary          *lastDownKey;
@property BOOL                  setSelection;

@end

@implementation EatsGridHorizontalSelectionView

- (NSArray *) viewArray
{
    if( !self.visible || self.width < 1 || self.height < 1 ) return nil;
    
    uint startPercentageAsStep = [EatsGridUtils percentageToSteps:self.startPercentage width:self.width];
    uint endPercentageAsStep = [EatsGridUtils percentageToSteps:self.endPercentage width:self.width];
    
    NSMutableArray *viewArray = [NSMutableArray arrayWithCapacity:self.width];
    
    // Generate the columns
    for(uint x = 0; x < self.width; x++) {
        [viewArray insertObject:[NSMutableArray arrayWithCapacity:self.height] atIndex:x];
        // Generate the rows
        for(uint y = 0; y < self.height; y++) {
            
            if( x == startPercentageAsStep || x == endPercentageAsStep)
                [[viewArray objectAtIndex:x] insertObject:[NSNumber numberWithUnsignedInt:15 * self.opacity] atIndex:y];
            else if ( x > startPercentageAsStep && x < endPercentageAsStep && self.fillBar )
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
        
        if( self.lastDownKey ) {
            
            self.startPercentage = [EatsGridUtils stepsToPercentage:[[self.lastDownKey valueForKey:@"x"] intValue] width:self.width];
            self.endPercentage = [EatsGridUtils stepsToPercentage:x width:self.width];
            
            // Maintain order
            if ( self.startPercentage > self.endPercentage ) {
                self.endPercentage = self.startPercentage;
                self.startPercentage = [EatsGridUtils stepsToPercentage:x width:self.width];
            }
            
            self.setSelection = YES;
            
        } else {
            // Log the last press
            self.lastDownKey = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithUnsignedInt:x], @"x", [NSNumber numberWithUnsignedInt:y], @"y", nil];
        }
        
        if([self.delegate respondsToSelector:@selector(eatsGridHorizontalSelectionViewUpdated:)])
            [self.delegate performSelector:@selector(eatsGridHorizontalSelectionViewUpdated:) withObject:self];
        
    // Release
    } else {
        
        // Remove lastDownKey if it's this one and put a 1 step selection haven't already drawn a selection
        if( self.lastDownKey && [[self.lastDownKey valueForKey:@"x"] intValue] == x && [[self.lastDownKey valueForKey:@"y"] intValue] == y ) {
            if (!self.setSelection ) {
                self.startPercentage = [EatsGridUtils stepsToPercentage:x width:self.width];
                self.endPercentage = [EatsGridUtils stepsToPercentage:x width:self.width];
            }
            self.lastDownKey = nil;
            self.setSelection = NO;
        }

    }
    

}

@end
