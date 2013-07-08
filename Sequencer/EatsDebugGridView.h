//
//  EatsDebugGridView.h
//  Sequencer
//
//  Created by Mark Wheeler on 07/04/2013.
//  Copyright (c) 2013 Mark Eats. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "SequencerState.h"

@interface EatsDebugGridView : NSView

@property uint columns;
@property uint rows;
@property uint gutter;

@property uint gridWidth;
@property uint gridHeight;

@property uint currentPageId;

@property SequencerState         *sequencerState;
@property NSManagedObjectContext *managedObjectContext;

@end
