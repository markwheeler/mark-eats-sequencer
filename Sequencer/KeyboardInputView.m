//
//  KeyboardInputView.m
//  Sequencer
//
//  Created by Mark Wheeler on 30/07/2013.
//  Copyright (c) 2013 Mark Eats. All rights reserved.
//

#import "KeyboardInputView.h"

#define SWIPE_MINIMUM_LENGTH 0.3

@interface KeyboardInputView()

@property NSMutableDictionary   *twoFingersTouches;

//@property CGFloat currentSum;
//@property NSTimer *drawTimer;
//@property CGFloat scrollDeltaX;
//@property CGFloat scrollDeltaY;

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

- (void)keyDown:(NSEvent *)theEvent {
    
    if( self.window.firstResponder == self ) {
        if( [_delegate respondsToSelector:@selector(keyDownFromKeyboardInputView:withModifierFlags:)] )
            [_delegate performSelector:@selector(keyDownFromKeyboardInputView:withModifierFlags:)
                            withObject:[NSNumber numberWithUnsignedShort:theEvent.keyCode]
                            withObject:[NSNumber numberWithUnsignedInteger:theEvent.modifierFlags]];
        
    }
    
    [super keyDown:theEvent];
}

// Code to detect two finger swipes from http://stackoverflow.com/questions/6874047/swipewithevent-equivalent-for-lion
// Only works for trackpad, not magic mouse

- (void)beginGestureWithEvent:(NSEvent *)event
{
    NSSet *touches = [event touchesMatchingPhase:NSTouchPhaseAny inView:nil];
    
    self.twoFingersTouches = [[NSMutableDictionary alloc] init];
    
    for (NSTouch *touch in touches) {
        [_twoFingersTouches setObject:touch forKey:touch.identity];
    }
}

- (void)endGestureWithEvent:(NSEvent *)event
{
    if (!_twoFingersTouches) return;
    
    NSSet *touches = [event touchesMatchingPhase:NSTouchPhaseAny inView:nil];
    
    // release twoFingersTouches early
    NSMutableDictionary *beginTouches = [_twoFingersTouches copy];
    self.twoFingersTouches = nil;
    
    NSMutableArray *magnitudes = [[NSMutableArray alloc] init];
    
    for (NSTouch *touch in touches) {
        NSTouch *beginTouch = [beginTouches objectForKey:touch.identity];
        
        if (!beginTouch) continue;
        
        float magnitude = touch.normalizedPosition.x - beginTouch.normalizedPosition.x;
        [magnitudes addObject:[NSNumber numberWithFloat:magnitude]];
    }
    
    // Need at least two points
    if ([magnitudes count] < 2) return;
    
    float sum = 0;
    
    for (NSNumber *magnitude in magnitudes)
        sum += [magnitude floatValue];
    
    // Handle natural direction in Lion
    BOOL naturalDirectionEnabled = [[[NSUserDefaults standardUserDefaults] valueForKey:@"com.apple.swipescrolldirection"] boolValue];
    
    if (naturalDirectionEnabled)
        sum *= -1;
    
    // See if absolute sum is long enough to be considered a complete gesture
    float absoluteSum = fabsf(sum);
    
    if (absoluteSum < SWIPE_MINIMUM_LENGTH) return;
    
    // Handle the actual swipe
    if (sum > 0) {
        if( [_delegate respondsToSelector:@selector(swipeForward)] )
            [_delegate performSelector:@selector(swipeForward)];
    } else {
        if( [_delegate respondsToSelector:@selector(swipeBack)] )
            [_delegate performSelector:@selector(swipeBack)];
    }
    
}

// Swipe code is based on
// https://github.com/Kapeli/SwipableWebView/blob/master/Swipable%20WebView/DHSwipeClipView.m
//
//- (void)scrollWheel:(NSEvent *)event
//{
//    if(![NSEvent isSwipeTrackingFromScrollEventsEnabled]) {
//        [super scrollWheel:event];
//        return;
//    }
//    if([event phase] == NSEventPhaseBegan) {
//        _currentSum = 0;
//        _scrollDeltaX = 0;
//        _scrollDeltaY = 0;
//        
//    } else if([event phase] == NSEventPhaseChanged) {
//        _scrollDeltaX += [event scrollingDeltaX];
//        _scrollDeltaY += [event scrollingDeltaY];
//        
//        CGFloat flippedDeltaX = _scrollDeltaX * -1;
//        // Draw the back/forward indicators
//        _currentSum = flippedDeltaX/1000;
//        [self launchDrawTimer];
//        return;
//        
//    } else if([event phase] == NSEventPhaseEnded) {
//        if( _currentSum < -SWIPE_MINIMUM_LENGTH ) {
//            if( [_delegate respondsToSelector:@selector(swipeBack)] )
//                [_delegate performSelector:@selector(swipeBack)];
//            
//        } else if( _currentSum >= SWIPE_MINIMUM_LENGTH ) {
//            if( [_delegate respondsToSelector:@selector(swipeForward)] )
//                [_delegate performSelector:@selector(swipeForward)];
//        }
//        if(_currentSum != 0) {
//            _currentSum = 0;
//            [self launchDrawTimer];
//        }
//    } else if([event phase] == NSEventPhaseMayBegin || [event phase] == NSEventPhaseCancelled) {
//        if(_currentSum != 0) {
//            _currentSum = 0;
//            [self launchDrawTimer];
//        }
//    }
//    [super scrollWheel:event];
//}
//
//- (void) launchDrawTimer
//{   
//    // A timer is needed because events are queued and processing and drawing
//    // takes longer than they are delivered, so the queue fills up
//    if(!_drawTimer || ![_drawTimer isValid]) {
//        self.drawTimer = [NSTimer scheduledTimerWithTimeInterval:1.0f/25 target:self selector:@selector(drawSwipe) userInfo:nil repeats:NO];
//    }
//}
//
//- (void) drawSwipe
//{
//    if( [_delegate respondsToSelector:@selector(swipeAmount:)] )
//        [_delegate performSelector:@selector(swipeAmount:) withObject:[NSNumber numberWithFloat:_currentSum]];
//}

@end