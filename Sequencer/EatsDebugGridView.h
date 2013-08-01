//
//  EatsDebugGridView.h
//  Sequencer
//
//  Created by Mark Wheeler on 07/04/2013.
//  Copyright (c) 2013 Mark Eats. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "SequencerState.h"

@protocol EatsDebugGridViewProtocol
- (void) cutPattern:(NSNumber *)patternId inPage:(NSNumber *)pageId;
- (void) copyPattern:(NSNumber *)patternId inPage:(NSNumber *)pageId;
- (void) pastePattern:(NSNumber *)patternId inPage:(NSNumber *)pageId;
@end

@interface EatsDebugGridView : NSView

@property uint columns;
@property uint rows;
@property uint gutter;

@property uint gridWidth;
@property uint gridHeight;

@property uint currentPageId;

@property SequencerState         *sequencerState;
@property NSManagedObjectContext *managedObjectContext;

@property BOOL                   patternQuantizationOn;

@property (weak) id             delegate;

@end
