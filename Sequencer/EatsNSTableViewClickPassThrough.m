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

- (void) keyDown:(NSEvent *)keyEvent
{
    BOOL responded = NO;
    
    if( self.window.firstResponder == self ) {
        
        uint keyCode = keyEvent.keyCode;
        NSEventModifierFlags modifierFlags = keyEvent.modifierFlags;
        
        // Here we have to check if it's something we're going to respond to. If not, pass it up. This list duplicates what's in the delegate responder.
        if( ( keyCode == 49 && modifierFlags == 256 )
           || keyCode == 27
           || keyCode == 24
           || keyCode == 122
           || keyCode == 120
           || keyCode == 99
           || keyCode == 118
           || keyCode == 96
           || keyCode == 97
           || keyCode == 98
           || keyCode == 100
           || keyCode == 123
           || keyCode == 124
           || keyCode == 18
           || keyCode == 19
           || keyCode == 20
           || keyCode == 21
           || keyCode == 23
           || keyCode == 22
           || keyCode == 26
           || keyCode == 28
           || keyCode == 25
           || keyCode == 29
           || ( keyCode == 0 && modifierFlags == 256 )
           || ( keyCode == 0 && modifierFlags & NSShiftKeyMask )
           || ( keyCode == 35 && modifierFlags == 256 )
           || keyCode == 47
           || keyCode == 43
           || ( keyCode == 44 && modifierFlags == 256 )
           || ( keyCode == 1 && modifierFlags == 256 )
           || keyCode == 33
           || keyCode == 30
           || ( keyCode == 2 && modifierFlags == 256 ) ) {
            
            // Send it to delegate
            if( [_delegate respondsToSelector:@selector(keyDownFromTableView:)] )
                [_delegate performSelector:@selector(keyDownFromTableView:) withObject:keyEvent];
            
            responded = YES;
            
        }
    }
    
    // Pass it up
    if( !responded )
        [super keyDown:keyEvent];
}

@end
