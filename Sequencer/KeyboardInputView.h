//
//  KeyboardInputView.h
//  Sequencer
//
//  Created by Mark Wheeler on 30/07/2013.
//  Copyright (c) 2013 Mark Eats. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@protocol KeyboardInputViewDelegateProtocol
- (void) keyDownFromKeyboardInputView:(NSNumber *)keyCode withModifierFlags:(NSNumber *)modifierFlags;
@optional
- (void) swipeBack;
- (void) swipeForward;
- (void) swipeAmount:(NSNumber *)delta;
@end

@interface KeyboardInputView : NSView

@property (weak) id     delegate;

@end
