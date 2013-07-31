//
//  KeyboardInputView.m
//  Sequencer
//
//  Created by Mark Wheeler on 30/07/2013.
//  Copyright (c) 2013 Mark Eats. All rights reserved.
//

#import "KeyboardInputView.h"

@implementation KeyboardInputView

- (id)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code here.
    }
    
    return self;
}

- (BOOL)acceptsFirstResponder
{
    return YES;
}

- (void)keyDown:(NSEvent *)theEvent {
    
    if( self.window.firstResponder == self ) {
        if( [_delegate respondsToSelector:@selector(keyDownFromKeyboardInputView:withModifierFlags:)] )
            [_delegate performSelector:@selector(keyDownFromKeyboardInputView:withModifierFlags:)
                            withObject:[NSNumber numberWithUnsignedShort:theEvent.keyCode]
                            withObject:[NSNumber numberWithUnsignedInteger:theEvent.modifierFlags]];
        
    }
    
    [super keyDown:theEvent];
}

@end
