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
        
        NSRect rect = NSMakeRect(10.0, 10.0, self.bounds.size.width - 20.0, self.bounds.size.height - 20.0);
        self.roundedRect = [NSBezierPath bezierPathWithRoundedRect:rect xRadius:4 yRadius:4];
    }
    
    return self;
}

- (void)drawRect:(NSRect)dirtyRect
{
    [NSGraphicsContext saveGraphicsState];
    
    // Shadow
    NSShadow *shadow = [[NSShadow alloc] init];
    [shadow setShadowOffset:NSMakeSize(0.0, -1.0)];
    [shadow setShadowBlurRadius:2.0];
    [shadow setShadowColor:[[NSColor blackColor] colorWithAlphaComponent:0.4]];
    [shadow set];
    
    // Fill
    [[NSColor colorWithCalibratedWhite:0.94 alpha:1.0] set];
    [_roundedRect fill];
    
    [NSGraphicsContext restoreGraphicsState];
}

@end
