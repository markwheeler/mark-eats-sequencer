//
//  EatsDebugGridView.m
//  Sequencer
//
//  Created by Mark Wheeler on 07/04/2013.
//  Copyright (c) 2013 Mark Eats. All rights reserved.
//

#import "EatsDebugGridView.h"

@implementation EatsDebugGridView

- (id)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        
        self.columns = 32;
        self.rows = 32;
        
        self.gutter = 2;
    }
    
    return self;
}

- (void)drawRect:(NSRect)dirtyRect
{
    // Background color for testing
    //[[NSColor colorWithCalibratedHue:0.5 saturation:0.7 brightness:1.0 alpha:1] set];
    //NSRectFill(dirtyRect);
    
    // Set the square size and corner radius
    CGFloat squareWidth = floor(((self.bounds.size.width + _gutter) / _columns) - _gutter);
    CGFloat squareHeight = floor(((self.bounds.size.height + _gutter) / _rows) - _gutter);
    
    CGFloat squareSize;
    if(squareWidth < squareHeight) squareSize = squareWidth;
    else squareSize = squareHeight;
    
    // Don't bother if we're too small
    if(squareSize < 3) return;
    
    CGFloat cornerRadius = squareSize * 0.1;
    
    for(int r=0; r < _rows; r++){
        for(int c=0; c < _columns; c++) {
            // Draw shape
            NSRect rect = NSMakeRect((squareSize + _gutter) * c, self.bounds.size.height - squareSize - (squareSize + _gutter) * r, squareSize, squareSize);
            NSBezierPath *roundedRect = [NSBezierPath bezierPathWithRoundedRect: rect xRadius:cornerRadius yRadius:cornerRadius];
            
            // Set clip so we can do an 'inner' stroke
            [roundedRect setClip];
            
            // Fill
            [[NSColor colorWithCalibratedHue:0 saturation:0 brightness:0.85 alpha:1] set];
            [roundedRect fill];
            
            
            // Stroke
            [[NSColor colorWithCalibratedHue:0 saturation:0 brightness:0.75 alpha:1] set];
            [roundedRect setLineWidth:2.0];
            [roundedRect stroke];
        }
    }
}

@end
