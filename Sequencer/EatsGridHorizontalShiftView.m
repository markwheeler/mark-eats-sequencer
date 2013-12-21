//
//  EatsGridHorizontalShiftView.m
//  Sequencer
//
//  Created by Mark Wheeler on 20/07/2013.
//  Copyright (c) 2013 Mark Eats. All rights reserved.
//

#import "EatsGridHorizontalShiftView.h"

@interface EatsGridHorizontalShiftView ()

@property NSDictionary          *lastDownKey;
@property BOOL                  setSelection;

@end

@implementation EatsGridHorizontalShiftView

- (NSArray *) viewArray
{
    if( !self.visible ) return nil;
    
    int tailLength;
    int tailBaseBrightness;
    
    if( self.useWideBrightnessRange ) {
        tailLength = 7;
        tailBaseBrightness = 4;
        
    } else {
        tailLength = 3;
        tailBaseBrightness = 8;
    }
    
    NSMutableArray *viewArray = [NSMutableArray arrayWithCapacity:self.width];
    
    // Generate the columns
    for(uint x = 0; x < self.width; x++) {
        [viewArray insertObject:[NSMutableArray arrayWithCapacity:self.height] atIndex:x];
        // Generate the rows
        for(uint y = 0; y < self.height; y++) {
            
            int brightness;
            
            if( x == self.zeroStep ) {
                brightness = 15;
            } else if ( self.shift > 0 && x > self.zeroStep && x <= self.zeroStep + self.shift ) {
                brightness = tailBaseBrightness;
                if( (int)x >= (int)self.zeroStep + self.shift - tailLength )
                    brightness += ( x - ( (int)self.zeroStep + self.shift - tailLength ) + 1 );
            } else if ( self.shift < 0 && x < self.zeroStep && (int)x >= (int)self.zeroStep + self.shift ) {
                brightness = tailBaseBrightness;
                if( (int)x <= (int)self.zeroStep + self.shift + tailLength )
                    brightness += ( ( (int)self.zeroStep + self.shift + tailLength + 1 ) - x );
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
        
        if( self.lastDownKey && [[self.lastDownKey valueForKey:@"x"] unsignedIntValue] == self.zeroStep ) {
            self.zeroStep = x;
            
            self.setSelection = YES;
            
            if([self.delegate respondsToSelector:@selector(eatsGridHorizontalShiftViewUpdated:)])
                [self.delegate performSelector:@selector(eatsGridHorizontalShiftViewUpdated:) withObject:self];
            
        } else {
            // Log the last press
            self.lastDownKey = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithUnsignedInt:x], @"x", [NSNumber numberWithUnsignedInt:y], @"y", nil];
        }
        
        
    // Release
    } else {
        
        // Remove lastDownKey if it's this one etc
        if( self.lastDownKey && [[self.lastDownKey valueForKey:@"x"] intValue] == x && [[self.lastDownKey valueForKey:@"y"] intValue] == y ) {
            if (!self.setSelection ) {
                self.shift = x - (int)self.zeroStep;
                
                if([self.delegate respondsToSelector:@selector(eatsGridHorizontalShiftViewUpdated:)])
                    [self.delegate performSelector:@selector(eatsGridHorizontalShiftViewUpdated:) withObject:self];
            }
            self.lastDownKey = nil;
            self.setSelection = NO;
        }
    }
}

@end
