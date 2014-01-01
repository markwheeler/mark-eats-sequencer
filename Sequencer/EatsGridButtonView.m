//
//  EatsGridButtonView.m
//  Sequencer
//
//  Created by Mark Wheeler on 23/03/2013.
//  Copyright (c) 2013 Mark Eats. All rights reserved.
//

#import "EatsGridButtonView.h"

@implementation EatsGridButtonView

- (id) init
{
    self = [super init];
    if (self) {
        self.inactiveBrightness = 0;
        self.downBrightness = 15;
        self.activeBrightness = 15;
    }
    return self;
}

- (NSArray *) viewArray
{
    if( !self.visible ) return nil;
    
    NSMutableArray *viewArray = [NSMutableArray arrayWithCapacity:self.width];
    
    // Generate the columns
    for(uint x = 0; x < self.width; x++) {
        [viewArray insertObject:[NSMutableArray arrayWithCapacity:self.height] atIndex:x];
        // Generate the rows
        for(uint y = 0; y < self.height; y++) {
            
            uint currentBrightness;

            if( self.buttonState == EatsButtonViewState_Down )
                currentBrightness = self.downBrightness;
            
            else if( self.buttonState == EatsButtonViewState_Active )
                currentBrightness = self.activeBrightness;
            
            else
                currentBrightness = self.inactiveBrightness;
            
            [[viewArray objectAtIndex:x] insertObject:[NSNumber numberWithUnsignedInt:currentBrightness * self.opacity] atIndex:y];
        }
    }
    
    return viewArray;
}

- (void) inputX:(uint)x y:(uint)y down:(BOOL)down
{
    if([self.delegate respondsToSelector:@selector(eatsGridButtonViewPressed: sender:)])
        [self.delegate performSelector:@selector(eatsGridButtonViewPressed: sender:) withObject:[NSNumber numberWithBool:down] withObject:self];
}

@end
