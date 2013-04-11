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
    
    // Set the square size and corner radius – use floor() around these two lines to make squares sit 'on pixel'
    CGFloat squareWidth = ((self.bounds.size.width + _gutter) / _columns) - _gutter;
    CGFloat squareHeight = ((self.bounds.size.height + _gutter) / _rows) - _gutter;
    
    CGFloat squareSize;
    if(squareWidth < squareHeight) squareSize = squareWidth;
    else squareSize = squareHeight;
    
    // Don't bother if we're too small
    if(squareSize < 3) return;
    
    CGFloat cornerRadius = squareSize * 0.1;
    
    for( int r = 0; r < _rows; r++ ){
        for( int c = 0; c < _columns; c++ ) {
            // Draw shape
            NSRect rect = NSMakeRect((squareSize + _gutter) * c, (squareSize + _gutter) * r, squareSize, squareSize);
            NSBezierPath *roundedRect = [NSBezierPath bezierPathWithRoundedRect: rect xRadius:cornerRadius yRadius:cornerRadius];
            
            // Set clip so we can do an 'inner' stroke
            [roundedRect setClip];

            // Colours
            float fillBrightness;
            float strokeBrightness;
            
            // TODO – Notes
            if( r == 99 && c == 99 ) {
                fillBrightness = 0;
                strokeBrightness = 0;
                
            // Active area
            } else if( r < 8 && c < 16 ) {
                fillBrightness = 0.85;
                strokeBrightness = 0.7;
                
            // Inactive area
            } else {
                fillBrightness = 0.9;
                strokeBrightness = 0.8;
            }
            
            // Fill
            [[NSColor colorWithCalibratedHue:0 saturation:0 brightness:fillBrightness alpha:1] set];
            [roundedRect fill];
            
            
            // Stroke
            [[NSColor colorWithCalibratedHue:0 saturation:0 brightness:strokeBrightness alpha:1] set];
            [roundedRect setLineWidth:2.0];
            [roundedRect stroke];
        }
    }
}

@end
