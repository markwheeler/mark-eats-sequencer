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
    
    // Generate the columns
    for(uint x = 0; x < width; x++) {
        [gridArray insertObject:[NSMutableArray arrayWithCapacity:height] atIndex:x];
        // Generate the rows
        for(uint y = 0; y < height; y++) {
            
            BOOL foundView = NO;
            NSEnumerator *enumerator = [views objectEnumerator];
            EatsGridSubView *view;
            
            while ( (view = [enumerator nextObject]) && !foundView) {
                
                // TODO: Modify this so views can overlap? Brightest pixel takes priority. Or add their values?!
                
                if( view.visible && x >= view.x && x < view.x + view.width && y >= view.y && y < view.y + view.height ) {
                    [[gridArray objectAtIndex:x] insertObject:[[[view viewArray] objectAtIndex:x - view.x] objectAtIndex:y - view.y ] atIndex:y];
                    foundView = YES;
                }
            }
            
            if(!foundView)
                [[gridArray objectAtIndex:x] insertObject:[NSNumber numberWithUnsignedInt:0] atIndex:y];
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
