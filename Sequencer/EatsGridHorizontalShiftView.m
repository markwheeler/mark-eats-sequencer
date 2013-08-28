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
    
    uint tailLength;
    uint tailBaseBrightness;
    
    if( self.useWideBrightnessRange ) {
        tailLength = 7;
        tailBaseBrightness = 4;
        
    } else {
        tailLength = 3;
        tailBaseBrightness = 8;
    }
    
    NSMutableArray *viewArray = [NSMutableArray arrayWithCapacity:self.width];
    
    // Generate the columns with playhead
    for(uint x = 0; x < self.width; x++) {
        [viewArray insertObject:[NSMutableArray arrayWithCapacity:self.height] atIndex:x];
        // Generate the rows
        for(uint y = 0; y < self.height; y++) {
            
            int brightness;
            
            if( x == _zeroStep ) {
                brightness = 15;
            } else if ( _shift > 0 && x > _zeroStep && x <= _zeroStep + _shift ) {
                brightness = tailBaseBrightness;
                if( (int)x >= (int)_zeroStep + _shift - tailLength )
                    brightness += ( x - ( (int)_zeroStep + _shift - tailLength ) + 1 );
            } else if ( _shift < 0 && x < _zeroStep && (int)x >= (int)_zeroStep + _shift ) {
                brightness = tailBaseBrightness;
                if( (int)x <= (int)_zeroStep + _shift + tailLength )
                    brightness += ( ( (int)_zeroStep + _shift + tailLength + 1 ) - x );
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
        
        if( _lastDownKey && [[_lastDownKey valueForKey:@"x"] unsignedIntValue] == _zeroStep ) {
            _zeroStep = x;
            
            _setSelection = YES;
            
            if([self.delegate respondsToSelector:@selector(eatsGridHorizontalShiftViewUpdated:)])
                [self.delegate performSelector:@selector(eatsGridHorizontalShiftViewUpdated:) withObject:self];
            
        } else {
            // Log the last press
            _lastDownKey = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithUnsignedInt:x], @"x", [NSNumber numberWithUnsignedInt:y], @"y", nil];
        }
        
        
    // Release
    } else {
        
        // Remove lastDownKey if it's this one etc
        if( _lastDownKey && [[_lastDownKey valueForKey:@"x"] intValue] == x && [[_lastDownKey valueForKey:@"y"] intValue] == y ) {
            if (!_setSelection ) {
                _shift = x - (int)_zeroStep;
                
                if([self.delegate respondsToSelector:@selector(eatsGridHorizontalShiftViewUpdated:)])
                    [self.delegate performSelector:@selector(eatsGridHorizontalShiftViewUpdated:) withObject:self];
            }
            _lastDownKey = nil;
            _setSelection = NO;
        }
    }
}

@end
