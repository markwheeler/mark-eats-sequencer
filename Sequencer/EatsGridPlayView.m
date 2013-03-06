//
//  EatsGridPlayView.m
//  Sequencer
//
//  Created by Mark Wheeler on 05/03/2013.
//  Copyright (c) 2013 Mark Eats. All rights reserved.
//

#import "EatsGridPlayView.h"

@implementation EatsGridPlayView

#pragma mark - Public methods

- (id) initWithDelegate:(id)delegate width:(uint)w height:(uint)h
{
    self = [super init];
    if (self) {
        
        self.delegate = delegate;
        self.width = w;
        self.height = h;
        
        [self updateView];
        
    }
    return self;
}

- (void) updateView
{
    
    NSMutableArray *gridArray = [NSMutableArray arrayWithCapacity:self.width];
    
    // Generate the columns
    for(uint x = 0; x < self.width; x++) {
        [gridArray insertObject:[NSMutableArray arrayWithCapacity:self.height] atIndex:x];
        // Generate the rows
        for(uint y = 0; y < self.height; y++) {
            [[gridArray objectAtIndex:x] insertObject:[NSNumber numberWithUnsignedInt:x] atIndex:y];
        }
    }
    
    if([self.delegate respondsToSelector:@selector(updateGridWithArray:)])
        [self.delegate performSelector:@selector(updateGridWithArray:) withObject:gridArray];
}

@end
