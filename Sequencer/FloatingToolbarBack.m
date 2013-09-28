//
//  FloatingToolbarBack.m
//  Sequencer
//
//  Created by Mark Wheeler on 28/09/2013.
//  Copyright (c) 2013 Mark Eats. All rights reserved.
//

#import "FloatingToolbarBack.h"

@interface FloatingToolbarBack()

@property (nonatomic) NSBezierPath      *roundedRect;

@end

@implementation FloatingToolbarBack

- (id)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code here.
        
        NSRect rect = NSMakeRect(0.0, 0.0, self.bounds.size.width, self.bounds.size.height);
        self.roundedRect = [NSBezierPath bezierPathWithRoundedRect:rect xRadius:4 yRadius:4];
    }
    
    return self;
}

- (void)drawRect:(NSRect)dirtyRect
{
    [NSGraphicsContext saveGraphicsState];
    
    // Fill
    [[NSColor windowBackgroundColor] set];
    [_roundedRect fill];
    
    
    // Stroke
    [[NSColor darkGrayColor] set];
    [_roundedRect setLineWidth:1.0];
    [_roundedRect stroke];
    
    [NSGraphicsContext restoreGraphicsState];
}

@end
