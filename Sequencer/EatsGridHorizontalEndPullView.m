//
//  EatsGridHorizontalEndPullView.m
//  Sequencer
//
//  Created by Mark Wheeler on 21/07/2013.
//  Copyright (c) 2013 Mark Eats. All rights reserved.
//

#import "EatsGridHorizontalEndPullView.h"

#define TAIL_LENGTH 3

@interface EatsGridHorizontalEndPullView ()

@property NSDictionary          *lastDownKey;
@property BOOL                  setSelection;

@end

@implementation EatsGridHorizontalEndPullView

- (NSArray *) viewArray
{
    if( !self.visible ) return nil;
    
    NSMutableArray *viewArray = [NSMutableArray arrayWithCapacity:self.width];
    
    // Generate the columns with playhead
    for(uint x = 0; x < self.width; x++) {
        [viewArray insertObject:[NSMutableArray arrayWithCapacity:self.height] atIndex:x];
        // Generate the rows
        for(uint y = 0; y < self.height; y++) {
            
            int brightness;
            
            if( ( x == _leftValue && _rightValue == 0 ) || ( x == (int)self.width - 1 - (int)_rightValue && _leftValue == 0 ) )
                brightness = 15;
            else if ( x < _leftValue ) {
                brightness = 8;
                if( (int)x >= (int)_leftValue - TAIL_LENGTH )
                    brightness += ( x - ( _leftValue - TAIL_LENGTH) + 1 ) * 2;
                
            } else if( (int)x > (int)self.width - 1 - (int)_rightValue ) {
                brightness = 8;
                if( (int)x < (int)self.width - (int)_rightValue + TAIL_LENGTH ) {
                    brightness += ( ( (int)self.width - 1 - (int)_rightValue + TAIL_LENGTH) - x + 1 ) * 2;
                }
            
            } else {
                brightness = 0;
            }
            
            [[viewArray objectAtIndex:x] insertObject:[NSNumber numberWithUnsignedInt:brightness * self.opacity] atIndex:y];
        }
    }
    
    return viewArray;
}

- (void) inputX:(uint)x y:(uint)y down:(BOOL)down
{
    // Down
    if( down ) {
        
        if( _lastDownKey ) {
            
            if( [[_lastDownKey valueForKey:@"x"] intValue] < x ) {
                _leftValue = x;
                _rightValue = 0;
            } else {
                _leftValue = 0;
                _rightValue = self.width - 1 - x;
            }
            
            _setSelection = YES;
            
            if([self.delegate respondsToSelector:@selector(eatsGridHorizontalEndPullViewUpdated:)])
                [self.delegate performSelector:@selector(eatsGridHorizontalEndPullViewUpdated:) withObject:self];
            
        } else {
            // Log the last press
            _lastDownKey = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithUnsignedInt:x], @"x", [NSNumber numberWithUnsignedInt:y], @"y", nil];
        }
        
        
    // Release
    } else {
        
        // Remove lastDownKey if it's this one and put a 1 step selection haven't already drawn a selection
        if( _lastDownKey && [[_lastDownKey valueForKey:@"x"] intValue] == x && [[_lastDownKey valueForKey:@"y"] intValue] == y ) {
            if (!_setSelection ) {
                _leftValue = 0;
                _rightValue = 0;
                
                if([self.delegate respondsToSelector:@selector(eatsGridHorizontalEndPullViewUpdated:)])
                    [self.delegate performSelector:@selector(eatsGridHorizontalEndPullViewUpdated:) withObject:self];
            }
            _lastDownKey = nil;
            _setSelection = NO;
        }
    }
}

@end
