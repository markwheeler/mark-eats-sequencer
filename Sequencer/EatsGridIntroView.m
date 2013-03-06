//
//  EatsGridIntroView.m
//  Sequencer
//
//  Created by Mark Wheeler on 04/03/2013.
//  Copyright (c) 2013 Mark Eats. All rights reserved.
//

#import "EatsGridIntroView.h"

@implementation EatsGridIntroView

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
    NSNumber *on = [NSNumber numberWithUnsignedInt:15];;
    NSNumber *off = [NSNumber numberWithUnsignedInt:0];
    NSArray *okArray = [NSArray arrayWithObjects:[NSArray arrayWithObjects: on, on, on, off, off, on, off, on, nil],
                                                   [NSArray arrayWithObjects: on, off, on, off, off, on, on, off, nil],
                                                   [NSArray arrayWithObjects: on, off, on, off, off, on, off, on, nil],
                                                   [NSArray arrayWithObjects: on, on, on, off, off, on, off, on, nil],
                                                   nil];
    
    NSMutableArray *gridArray = [NSMutableArray array];
    
    long leftMargin = (self.width - [[okArray objectAtIndex:0] count]) / 2;
    long topMargin = (self.height - [okArray count]) / 2;
    
    // Generate the columns
    for(uint x = 0; x < self.width; x++) {
        [gridArray insertObject:[NSMutableArray arrayWithCapacity:self.height] atIndex:x];
        // Generate the rows
        for(uint y = 0; y < self.height; y++) {
            // Put lights in interesting places
            if(x > leftMargin - 1 && x <= self.width - leftMargin - 1 && y > topMargin - 1 && y <= self.height - topMargin - 1)
                [[gridArray objectAtIndex:x] insertObject:[[okArray objectAtIndex:y - topMargin] objectAtIndex:x - leftMargin] atIndex:y];
            else
                [[gridArray objectAtIndex:x] insertObject:[NSNumber numberWithUnsignedInt:0] atIndex:y];
        }
    }
    
    if([self.delegate respondsToSelector:@selector(updateGridWithArray:)])
        [self.delegate performSelector:@selector(updateGridWithArray:) withObject:gridArray];
}

@end
