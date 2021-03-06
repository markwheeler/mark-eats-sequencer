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
    for(int x = 0; x < width; x ++ ) {
        [gridArray insertObject:[NSMutableArray arrayWithCapacity:height] atIndex:x];
        // Generate the rows
        for(int y = 0; y < height; y ++ ) {
            [[gridArray objectAtIndex:x] insertObject:zero atIndex:y];
        }
    }
    
    // Go through the sub views
    
    // DEBUG LOG
//    NSLog( @"!--------------------------- w %u h %u", width, height );
    for( EatsGridSubView *view in views ) {
        // DEBUG LOG
//        NSLog( @"!View %@", view);
        if( view.visible ) {
            
            NSArray *viewArray = [view viewArray];
            
            if( [viewArray count] ) { // TODO should be able to remove this debug check
                int x = view.x;
                int y;
                for( NSArray *column in viewArray ) {
                    y = view.y;
                    for( NSNumber *number in column ) {
                        
                        // Don't put in pixels outside the grid (if the view is hanging off the edge)
                        if( x >= 0 && x < width && y >= 0 && y < height ) {
                            // Only replace brighter pixels
                            if( [[[gridArray objectAtIndex:x] objectAtIndex:y] intValue] < number.intValue )
                                [[gridArray objectAtIndex:x] replaceObjectAtIndex:y withObject:number];
                        }
                        y ++;
                    }
                    x ++;
                }
                
            // DEBUG LOG If the view array is empty, what went wrong?
            } else {
                NSLog( @"WARNING: Empty view array from: %@", view );
                NSLog( @"Break!" );
            }
        }
    }
    
    // DEBUG LOG TODO remove this debug code
    NSUInteger noOfRows = [[gridArray objectAtIndex:0] count];
    // The following checks that all the columns have the correct number of rows in them
    for( int i = 0; i < gridArray.count; i ++ ) {
        if( [[gridArray objectAtIndex:i] count] != noOfRows ) {
            NSLog( @"WARNING: gridArray rows are not equal! Should be %lu but col %i is %lu", (unsigned long)noOfRows, i, (unsigned long)[[gridArray objectAtIndex:i] count] );
            NSLog( @"DUMP OF gridArray %@", gridArray );
        }
    }
    
    return [gridArray copy];
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
