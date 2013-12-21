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
    // TODO This is only here to help track down crash on connect bug
    if( !views.count )
        NSLog(@"WARNING: No subviews in current view");
    
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
            int x = view.x;
            int y;
            for( NSArray *column in viewArray ) {
                y = view.y;
                for( NSNumber *number in column ) {
                    
                    // TODO This is only here to help track down crash on connect bug
                    if( width > gridArray.count )
                        NSLog(@"WARNING: Width is larger than gridArray width %@", gridArray);
                    else if( x < gridArray.count && height > [[gridArray objectAtIndex:x] count] )
                        NSLog(@"WARNING: Height is larger than gridArray height %@", gridArray);
                    
                    // Don't put in pixels outside the grid (if the view is hanging off the edge)
                    if( x >= 0 && x < width && y >= 0 && y < height )
                        [[gridArray objectAtIndex:x] replaceObjectAtIndex:y withObject:[[viewArray objectAtIndex:x - view.x] objectAtIndex:y - view.y]];
                    y ++;
                }
                x ++;
            }
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
