//
//  EatsNSTableViewClickPassThrough.m
//  Sequencer
//
//  Created by Mark Wheeler on 27/12/2013.
//  Copyright (c) 2013 Mark Eats. All rights reserved.
//

#import "EatsNSTableViewClickPassThrough.h"

@implementation EatsNSTableViewClickPassThrough

- (id)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code here.
    }
    return self;
}

- (void)drawRect:(NSRect)dirtyRect
{
	[super drawRect:dirtyRect];
	
    // Drawing code here.
}

- (void) keyDown:(NSEvent *)theEvent
{
    if( self.window.firstResponder == self ) {
        if( [_delegate respondsToSelector:@selector(keyDownFromTableView:withModifierFlags:)] )
            [_delegate performSelector:@selector(keyDownFromTableView:withModifierFlags:)
                            withObject:[NSNumber numberWithUnsignedShort:theEvent.keyCode]
                            withObject:[NSNumber numberWithUnsignedInteger:theEvent.modifierFlags]];
    }
    
    [super keyDown:theEvent];
}

@end
