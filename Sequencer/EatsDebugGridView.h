//
//  EatsDebugGridView.h
//  Sequencer
//
//  Created by Mark Wheeler on 07/04/2013.
//  Copyright (c) 2013 Mark Eats. All rights reserved.
//
//
//  Takes a set of SequencerNotes and draws them.

#import <Cocoa/Cocoa.h>

@protocol EatsDebugGridViewDelegateProtocol
- (void) cutCurrentPattern;
- (void) copyCurrentPattern;
- (void) pasteToCurrentPattern;
- (void) keyDownFromEatsDebugGridView:(NSNumber *)keyCode withModifierFlags:(NSNumber *)modifierFlags;
@end

@interface EatsDebugGridView : NSView

@property uint columns;
@property uint rows;
@property uint gutter;

@property uint gridWidth;
@property uint gridHeight;

@property NSSet                 *notes; // Notes to draw
@property BOOL                  drawNotesForReverse; // Should be set if playback is running backwards and note trails should extend the other way
@property int                   currentStep;
@property NSNumber              *nextStep;

@property (weak) id             delegate;

@end
