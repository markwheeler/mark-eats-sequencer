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
            
            if( ( x == self.leftValue && self.rightValue == 0 ) || ( x == (int)self.width - 1 - (int)self.rightValue && self.leftValue == 0 ) )
                brightness = 15;
            else if ( x < self.leftValue ) {
                brightness = 8;
                if( (int)x >= (int)self.leftValue - TAIL_LENGTH )
                    brightness += ( x - ( self.leftValue - TAIL_LENGTH) + 1 ) * 2;
                
            } else if( (int)x > (int)self.width - 1 - (int)self.rightValue ) {
                brightness = 8;
                if( (int)x < (int)self.width - (int)self.rightValue + TAIL_LENGTH ) {
                    brightness += ( ( (int)self.width - 1 - (int)self.rightValue + TAIL_LENGTH) - x + 1 ) * 2;
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
        
        if( self.lastDownKey ) {
            
            if( [[self.lastDownKey valueForKey:@"x"] intValue] < x ) {
                self.leftValue = x;
                self.rightValue = 0;
            } else {
                self.leftValue = 0;
                self.rightValue = self.width - 1 - x;
            }
            
            self.setSelection = YES;
            
            if([self.delegate respondsToSelector:@selector(eatsGridHorizontalEndPullViewUpdated:)])
                [self.delegate performSelector:@selector(eatsGridHorizontalEndPullViewUpdated:) withObject:self];
            
        } else {
            // Log the last press
            self.lastDownKey = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithUnsignedInt:x], @"x", [NSNumber numberWithUnsignedInt:y], @"y", nil];
        }
        
        
    // Release
    } else {
        
        // Remove lastDownKey if it's this one and put a 1 step selection haven't already drawn a selection
        if( self.lastDownKey && [[self.lastDownKey valueForKey:@"x"] intValue] == x && [[self.lastDownKey valueForKey:@"y"] intValue] == y ) {
            if ( !self.setSelection ) {
                self.leftValue = 0;
                self.rightValue = 0;
                
                if([self.delegate respondsToSelector:@selector(eatsGridHorizontalEndPullViewUpdated:)])
                    [self.delegate performSelector:@selector(eatsGridHorizontalEndPullViewUpdated:) withObject:self];
            }
            self.lastDownKey = nil;
            self.setSelection = NO;
        }
    }
}

@end
