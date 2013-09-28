//
//  Document.h
//  Sequencer
//
//  Created by Mark Wheeler on 03/03/2013.
//  Copyright (c) 2013 Mark Eats. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "Sequencer.h"
#import "EatsClock.h"
#import "ClockTick.h"
#import "Preferences.h"
#import "EatsDebugGridView.h"
#import "KeyboardInputView.h"

@interface Document : NSDocument <ClockTickDelegateProtocol, NSTableViewDelegate, KeyboardInputViewDelegateProtocol, EatsDebugGridViewDelegateProtocol>

@property Sequencer                 *sequencer;
@property NSArray                   *currentPagePitches;

@property BOOL                      isActive;

@property Preferences               *sharedPreferences;

- (void) clearPatternStartAlert;
- (void) showClockLateIndicator;

- (void) keyDownFromEatsDebugGridView:(NSNumber *)keyCode withModifierFlags:(NSNumber *)modifierFlags;
- (void) cutCurrentPattern;
- (void) copyCurrentPattern;
- (void) pasteToCurrentPattern;

- (void) keyDownFromKeyboardInputView:(NSNumber *)keyCode withModifierFlags:(NSNumber *)modifierFlags;
- (void) swipeForward;
- (void) swipeBack;

- (void) debugGridViewMouseEntered;
- (void) debugGridViewMouseExited;

@end
