//
//  EatsPieChartProgress.m
//  Sequencer
//
//  Created by Mark Wheeler on 29/12/2013.
//  Copyright (c) 2013 Mark Eats. All rights reserved.
//

#import "EatsPieChartProgress.h"

#define PI 3.14159265358979323846

@implementation EatsPieChartProgress

- (id)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code here.
        self.progress = 0.0;
        self.activeSliceColor = [NSColor darkGrayColor];
        self.inactiveSliceColor = [NSColor colorWithCalibratedHue:0.0 saturation:0.0 brightness:0.8 alpha:1.0];
    }
    return self;
}

- (void)drawRect:(NSRect)dirtyRect
{
    NSBezierPath *inactiveSlice = [NSBezierPath bezierPath];
    NSBezierPath *activeSlice = [NSBezierPath bezierPath];
    
    float shortestSide;
    if( self.frame.size.width < self.frame.size.height )
        shortestSide = self.frame.size.width;
    else
        shortestSide = self.frame.size.height;
    
    // Start at the center
    NSPoint centerPoint = NSMakePoint( self.frame.size.width / 2, self.frame.size.height / 2 );
    [inactiveSlice moveToPoint:centerPoint];
    
    // Draw the inactive slice
    int zeroAngle = 90;
    [inactiveSlice appendBezierPathWithArcWithCenter:centerPoint radius:shortestSide / 2 startAngle:zeroAngle endAngle:360 - ( 360 * self.progress ) + zeroAngle ];
    [inactiveSlice lineToPoint:centerPoint ];
    
    [self.inactiveSliceColor set];
    [inactiveSlice fill];

    
    // Draw the active slice
    [activeSlice appendBezierPathWithArcWithCenter:centerPoint radius:shortestSide / 2 startAngle:360 - ( 360 * self.progress ) + zeroAngle endAngle:zeroAngle ];
    [activeSlice lineToPoint:centerPoint];
    
    [self.activeSliceColor set];
    [activeSlice fill];
}

@end
