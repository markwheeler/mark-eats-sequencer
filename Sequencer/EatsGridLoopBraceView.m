//
//  EatsGridLoopBraceView.m
//  Sequencer
//
//  Created by Mark Wheeler on 27/03/2013.
//  Copyright (c) 2013 Mark Eats. All rights reserved.
//

#import "EatsGridLoopBraceView.h"

@interface EatsGridLoopBraceView ()

@property NSDictionary          *lastDownKey;
@property BOOL                  setSelection;

@end

@implementation EatsGridLoopBraceView

- (NSArray *) viewArray
{
    if( !self.visible ) return nil;
    
    uint startPercentageAsStep = roundf(((self.width - 1) / 100.0) * self.startPercentage);
    uint endPercentageAsStep = roundf(((self.width - 1) / 100.0) * self.endPercentage);
    
    NSMutableArray *viewArray = [NSMutableArray arrayWithCapacity:self.width];
    
    // Generate the columns with playhead
    for(uint x = 0; x < self.width; x++) {
        [viewArray insertObject:[NSMutableArray arrayWithCapacity:self.height] atIndex:x];
        // Generate the rows
        for(uint y = 0; y < self.height; y++) {
            
            if( x == startPercentageAsStep || x == endPercentageAsStep)
                [[viewArray objectAtIndex:x] insertObject:[NSNumber numberWithUnsignedInt:15 * self.opacity] atIndex:y];
            else if ( ( startPercentageAsStep < endPercentageAsStep &&  x > startPercentageAsStep && x < endPercentageAsStep && self.fillBar )
                     || ( startPercentageAsStep > endPercentageAsStep &&  x > startPercentageAsStep && self.fillBar )
                     || ( startPercentageAsStep > endPercentageAsStep && x < endPercentageAsStep && self.fillBar ) )
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
            
            int loopEndX = x - 1;
            if( loopEndX < 0 )
                loopEndX += self.width;
            
            // Set a selection
            self.startPercentage = ( [[self.lastDownKey valueForKey:@"x"] intValue] / (self.width - 1.0) ) * 100.0;
            self.endPercentage = ( loopEndX / (self.width - 1.0) ) * 100.0;
            
            self.setSelection = YES;
            
            if([self.delegate respondsToSelector:@selector(eatsGridLoopBraceViewUpdated:)])
                [self.delegate performSelector:@selector(eatsGridLoopBraceViewUpdated:) withObject:self];
            
        } else {
            // Log the last press
            self.lastDownKey = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithUnsignedInt:x], @"x", [NSNumber numberWithUnsignedInt:y], @"y", nil];
        }
        
        
        
        // Release
    } else {
        
        // Remove lastDownKey if it's this one and set the selection to all
        if( self.lastDownKey && [[self.lastDownKey valueForKey:@"x"] intValue] == x && [[self.lastDownKey valueForKey:@"y"] intValue] == y ) {
            if (!self.setSelection ) {
                
                self.startPercentage = 0;
                self.endPercentage = 100;
                
                if([self.delegate respondsToSelector:@selector(eatsGridLoopBraceViewUpdated:)])
                    [self.delegate performSelector:@selector(eatsGridLoopBraceViewUpdated:) withObject:self];
            }
            self.lastDownKey = nil;
            self.setSelection = NO;
        }
        
    }
    
    
}

@end
