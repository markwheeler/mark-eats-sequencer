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
    if( !self.visible ) return nil;
    
    uint startPercentageAsStep = [EatsGridUtils percentageToSteps:_startPercentage width:self.width];
    uint endPercentageAsStep = [EatsGridUtils percentageToSteps:_endPercentage width:self.width];
    
    NSMutableArray *viewArray = [NSMutableArray arrayWithCapacity:self.width];
    
    // Generate the columns with playhead
    for(uint x = 0; x < self.width; x++) {
        [viewArray insertObject:[NSMutableArray arrayWithCapacity:self.height] atIndex:x];
        // Generate the rows
        for(uint y = 0; y < self.height; y++) {
            
            if( x == startPercentageAsStep || x == endPercentageAsStep)
                [[viewArray objectAtIndex:x] insertObject:[NSNumber numberWithUnsignedInt:15 * self.opacity] atIndex:y];
            else if ( x > startPercentageAsStep && x < endPercentageAsStep && _fillBar )
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
        
        if( _lastDownKey ) {
            
            _startPercentage = [EatsGridUtils stepsToPercentage:[[_lastDownKey valueForKey:@"x"] intValue] width:self.width];
            _endPercentage = [EatsGridUtils stepsToPercentage:x width:self.width];
            
            // Maintain order
            if ( _startPercentage > _endPercentage ) {
                _endPercentage = _startPercentage;
                _startPercentage = [EatsGridUtils stepsToPercentage:x width:self.width];
            }
            
            _setSelection = YES;
            
        } else {
            // Log the last press
            _lastDownKey = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithUnsignedInt:x], @"x", [NSNumber numberWithUnsignedInt:y], @"y", nil];
        }
        
        if([self.delegate respondsToSelector:@selector(eatsGridHorizontalSelectionViewUpdated:)])
            [self.delegate performSelector:@selector(eatsGridHorizontalSelectionViewUpdated:) withObject:self];
        
    // Release
    } else {
        
        // Remove lastDownKey if it's this one and put a 1 step selection haven't already drawn a selection
        if( _lastDownKey && [[_lastDownKey valueForKey:@"x"] intValue] == x && [[_lastDownKey valueForKey:@"y"] intValue] == y ) {
            if (!_setSelection ) {    
                _startPercentage = [EatsGridUtils stepsToPercentage:x width:self.width];
                _endPercentage = [EatsGridUtils stepsToPercentage:x width:self.width];
            }
            _lastDownKey = nil;
            _setSelection = NO;
        }

    }
    

}

@end
