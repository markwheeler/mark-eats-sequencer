//
//  EatsGridLoopBraceView.m
//  Sequencer
//
//  Created by Mark Wheeler on 27/03/2013.
//  Copyright (c) 2013 Mark Eats. All rights reserved.
//

#import "EatsGridLoopBraceView.h"
#import "EatsGridUtils.h"

@interface EatsGridLoopBraceView ()

@property NSDictionary          *lastDownKey;
@property BOOL                  setSelection;

@end

@implementation EatsGridLoopBraceView

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
            else if ( ( startPercentageAsStep < endPercentageAsStep &&  x > startPercentageAsStep && x < endPercentageAsStep && _fillBar )
                     || ( startPercentageAsStep > endPercentageAsStep &&  x > startPercentageAsStep && _fillBar )
                     || ( startPercentageAsStep > endPercentageAsStep && x < endPercentageAsStep && _fillBar ) )
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
            
            int loopEndX = x - 1;
            if( loopEndX < 0 )
                loopEndX += self.width;
            
            // Set a selection
            _startPercentage = [EatsGridUtils stepsToPercentage:[[_lastDownKey valueForKey:@"x"] intValue] width:self.width];
            _endPercentage = [EatsGridUtils stepsToPercentage:loopEndX width:self.width];
            
            _setSelection = YES;
            
            if([self.delegate respondsToSelector:@selector(eatsGridLoopBraceViewUpdated:)])
                [self.delegate performSelector:@selector(eatsGridLoopBraceViewUpdated:) withObject:self];
            
        } else {
            // Log the last press
            _lastDownKey = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithUnsignedInt:x], @"x", [NSNumber numberWithUnsignedInt:y], @"y", nil];
        }
        
        
        
    // Release
    } else {
        
        // Remove lastDownKey if it's this one and set the selection to all
        if( _lastDownKey && [[_lastDownKey valueForKey:@"x"] intValue] == x && [[_lastDownKey valueForKey:@"y"] intValue] == y ) {
            if (!_setSelection ) {
                
                _startPercentage = 0;
                _endPercentage = 100;
                
                if([self.delegate respondsToSelector:@selector(eatsGridLoopBraceViewUpdated:)])
                    [self.delegate performSelector:@selector(eatsGridLoopBraceViewUpdated:) withObject:self];
            }
            _lastDownKey = nil;
            _setSelection = NO;
        }
        
    }
    
    
}

@end
