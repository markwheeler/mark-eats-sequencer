//
//  EatsGridUtils.m
//  Sequencer
//
//  Created by Mark Wheeler on 22/03/2013.
//  Copyright (c) 2013 Mark Eats. All rights reserved.
//

#import "EatsGridUtils.h"
#import "EatsGridSubView.h"

@implementation EatsGridUtils

// Takes an NSSet of Dictionary objects, each containing x, y, width, height and a viewArray
+ (NSArray *) combineSubViews:(NSSet *)views gridWidth:(uint)width gridHeight:(uint)height
{
    // Combine sub views to create the complete view
    NSMutableArray *gridArray = [NSMutableArray arrayWithCapacity:width];
    
    NSNumber *zero = [NSNumber numberWithUnsignedInt:0];
    
    // Generate the columns
    for(int x = 0; x < width; x++) {
        [gridArray insertObject:[NSMutableArray arrayWithCapacity:height] atIndex:x];
        // Generate the rows
        for(int y = 0; y < height; y++) {
            [[gridArray objectAtIndex:x] insertObject:zero atIndex:y];
        }
    }
    
    for( EatsGridSubView *view in views ) {
        if( view.visible ) {
            
            NSArray *viewArray = [view.viewArray copy];
            uint x = view.x;
            uint y;
            for( NSArray *column in viewArray ) {
                y = view.y;
                for( NSNumber *number in column ) {
                    [[gridArray objectAtIndex:x] replaceObjectAtIndex:y withObject:[[viewArray objectAtIndex:x - view.x] objectAtIndex:y - view.y]];
                    y ++;
                }
                x ++;
            }
        }
    }
    
    return gridArray;
}

+ (float) stepsToPercentage:(int)steps width:(uint)width
{
    return ( (float)steps / (width - 1) ) * 100.0;
}

+ (uint) percentageToSteps:(float)percentage width:(uint)width
{
    return roundf( ((width - 1) / 100.0) * percentage );
}

@end
