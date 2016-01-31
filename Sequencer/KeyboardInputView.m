//
//  KeyboardInputView.m
//  Sequencer
//
//  Created by Mark Wheeler on 30/07/2013.
//  Copyright (c) 2013 Mark Eats. All rights reserved.
//

#import "KeyboardInputView.h"

@interface KeyboardInputView()

@property NSMutableDictionary   *twoFingersTouches;

@end

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

- (BOOL)acceptsTouchEvents
{
    return YES;
}

- (void)keyDown:(NSEvent *)keyEvent
{
    
    BOOL responded = NO;
    
    if( self.window.firstResponder == self ) {
        
        uint keyCode = keyEvent.keyCode;
        NSEventModifierFlags modifierFlags = keyEvent.modifierFlags;
        
        BOOL hasModifiers = false;
        if( ( modifierFlags & NSDeviceIndependentModifierFlagsMask ) > 0 )
            hasModifiers = true;
        
        // Here we have to check if it's something we're going to respond to. If not, pass it up. This list duplicates what's in the delegate responder.
        if( ( keyCode == 49 && !hasModifiers )
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
           || ( keyCode == 0 && !hasModifiers )
           || ( keyCode == 0 && modifierFlags & NSShiftKeyMask )
           || ( keyCode == 35 && !hasModifiers )
           || keyCode == 47
           || keyCode == 43
           || ( keyCode == 44 && !hasModifiers )
           || ( keyCode == 1 && !hasModifiers )
           || keyCode == 33
           || keyCode == 30
           || ( keyCode == 2 && !hasModifiers ) ) {
            
            // Send it to delegate
            if( [_delegate respondsToSelector:@selector(keyDownFromKeyboardInputView:)] )
                [_delegate performSelector:@selector(keyDownFromKeyboardInputView:) withObject:keyEvent];
            
            responded = YES;
            
        }
    }
    
    // Pass it up
    if( !responded )
        [super keyDown:keyEvent];
    
}


// Code to detect two finger swipes from http://stackoverflow.com/questions/26570560/two-finger-swipe-in-yosemite-10-10
// Only works for trackpad, not magic mouse

#define SWIPE_MINIMUM_LENGTH 0.15

- (void) touchesBeganWithEvent:(NSEvent *)event
{
    if( event.type == NSEventTypeGesture ){
        NSSet *touches = [event touchesMatchingPhase:NSTouchPhaseAny inView:self];
        if(touches.count == 2){
            self.twoFingersTouches = [[NSMutableDictionary alloc] init];
            
            for( NSTouch *touch in touches ) {
                [self.twoFingersTouches setObject:touch forKey:touch.identity];
            }
        }
    }
}

- (void) touchesMovedWithEvent:(NSEvent*)event
{
    NSSet *touches = [event touchesMatchingPhase:NSTouchPhaseEnded inView:self];
    if( touches.count > 0 ) {
        NSMutableDictionary *beginTouches = [self.twoFingersTouches copy];
        self.twoFingersTouches = nil;
        
        NSMutableArray *magnitudes = [[NSMutableArray alloc] init];
        
        for( NSTouch *touch in touches )
        {
            NSTouch *beginTouch = [beginTouches objectForKey:touch.identity];
            
            if( !beginTouch )
                continue;
            
            float magnitude = touch.normalizedPosition.x - beginTouch.normalizedPosition.x;
            [magnitudes addObject:[NSNumber numberWithFloat:magnitude]];
        }
        
        float sum = 0;
        
        for( NSNumber *magnitude in magnitudes )
            sum += [magnitude floatValue];
        
        // See if absolute sum is long enough to be considered a complete gesture
        float absoluteSum = fabsf( sum );
        
        if ( absoluteSum < SWIPE_MINIMUM_LENGTH )
            return;
        
        // Handle the actual swipe
        if (sum < 0) {
            if( [_delegate respondsToSelector:@selector(swipeForward)] )
                [_delegate performSelector:@selector(swipeForward)];
        } else {
            if( [_delegate respondsToSelector:@selector(swipeBack)] )
                [_delegate performSelector:@selector(swipeBack)];
        }
    }
}

@end