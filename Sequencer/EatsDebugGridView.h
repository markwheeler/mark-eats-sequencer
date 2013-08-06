//
//  EatsDebugGridView.h
//  Sequencer
//
//  Created by Mark Wheeler on 07/04/2013.
//  Copyright (c) 2013 Mark Eats. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "SequencerState.h"
#import "SequencerPattern.h"

@protocol EatsDebugGridViewDelegateProtocol
- (void) cutPattern:(NSNumber *)patternId inPage:(NSNumber *)pageId;
- (void) copyPattern:(NSNumber *)patternId inPage:(NSNumber *)pageId;
- (void) pastePattern:(NSNumber *)patternId inPage:(NSNumber *)pageId;
- (void) keyDownFromEatsDebugGridView:(NSNumber *)keyCode withModifierFlags:(NSNumber *)modifierFlags;
@end

@interface EatsDebugGridView : NSView

@property uint columns;
@property uint rows;
@property uint gutter;

@property uint gridWidth;
@property uint gridHeight;

@property SequencerState         *sequencerState;
@property SequencerPattern       *currentPattern;

@property NSString               *pasteboardType;

@property BOOL                   patternQuantizationOn;

@property (weak) id              delegate;

@end
