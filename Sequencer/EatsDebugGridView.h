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

@property (nonatomic) uint columns;
@property (nonatomic) uint rows;
@property (nonatomic) uint gutter;

@property (nonatomic) uint gridWidth;
@property (nonatomic) uint gridHeight;

@property (nonatomic) NSSet                 *notes; // Notes to draw
@property (nonatomic) BOOL                  drawNotesForReverse; // Should be set if playback is running backwards and note trails should extend the other way
@property (nonatomic) int                   currentStep;
@property (nonatomic) NSNumber              *nextStep;

@property (nonatomic, weak) id              delegate;

@end
