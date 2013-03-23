//
//  EatsGridUtils.m
//  Sequencer
//
//  Created by Mark Wheeler on 22/03/2013.
//  Copyright (c) 2013 Mark Eats. All rights reserved.
//

#import "EatsGridUtils.h"

@implementation EatsGridUtils

// Takes an NSSet of Dictionary objects, each containing x, y, width, height and a viewArray
+ (NSArray *) combineSubViews:(NSSet *)views gridWidth:(uint)width gridHeight:(uint)height
{
    // Combine sub views to create the complete view
    NSMutableArray *gridArray = [NSMutableArray arrayWithCapacity:width];
    
    // Generate the columns
    for(uint x = 0; x < width; x++) {
        [gridArray insertObject:[NSMutableArray arrayWithCapacity:height] atIndex:x];
        // Generate the rows
        for(uint y = 0; y < height; y++) {
            
            BOOL foundView = NO;
            NSEnumerator *enumerator = [views objectEnumerator];
            NSDictionary *view;
            
            while ( (view = [enumerator nextObject]) && !foundView) {
                
                NSArray *viewArray = [view valueForKey:@"viewArray"];
                uint viewX = [[view valueForKey:@"x"] intValue];
                uint viewY = [[view valueForKey:@"y"] intValue];
                uint viewWidth = [[view valueForKey:@"width"] intValue];
                uint viewHeight = [[view valueForKey:@"height"] intValue];
                
                if(x >= viewX && x < viewX + viewWidth && y >= viewY && y < viewY + viewHeight) {
                    [[gridArray objectAtIndex:x] insertObject:[[viewArray objectAtIndex:x - viewX] objectAtIndex:y - viewY ] atIndex:y];
                    foundView = YES;
                }
            }
            
            if(!foundView)
                [[gridArray objectAtIndex:x] insertObject:[NSNumber numberWithUnsignedInt:0] atIndex:y];
        }
    }
    
    return gridArray;
}

@end
