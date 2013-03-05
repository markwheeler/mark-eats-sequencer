//
//  EatsGridIntroView.m
//  Sequencer
//
//  Created by Mark Wheeler on 04/03/2013.
//  Copyright (c) 2013 Mark Eats. All rights reserved.
//

#import "EatsGridIntroView.h"

@implementation EatsGridIntroView

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
    int seed = arc4random_uniform(self.width - 1);
    
    // Generate the columns
    for(NSUInteger x = 0; x < self.width; x++) {
        [gridArray insertObject:[NSMutableArray arrayWithCapacity:self.height] atIndex:x];
        // Generate the rows
        for(NSUInteger y = 0; y < self.height; y++) {
            // Put lights in interesting places
            if(x % 4 == (seed - y) % 4)
                [[gridArray objectAtIndex:x] insertObject:[NSNumber numberWithUnsignedInt:15] atIndex:y];
            else
                [[gridArray objectAtIndex:x] insertObject:[NSNumber numberWithUnsignedInt:0] atIndex:y];
        }
    }
    
    if([self.delegate respondsToSelector:@selector(updateGridWithArray:)])
        [self.delegate performSelector:@selector(updateGridWithArray:) withObject:gridArray];
}


@end
