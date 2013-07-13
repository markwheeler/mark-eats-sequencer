//
//  Document.h
//  Sequencer
//
//  Created by Mark Wheeler on 03/03/2013.
//  Copyright (c) 2013 Mark Eats. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "Sequencer+Utils.h"
#import "SequencerPage.h"
#import "SequencerRowPitch.h"
#import "SequencerPattern.h"
#import "SequencerNote.h"
#import "SequencerPatternIdInPlaylist.h"
#import "EatsClock.h"
#import "ClockTick.h"
#import "Preferences.h"
#import "SequencerState.h"
#import "SequencerPageState.h"

@interface Document : NSPersistentDocument <ClockTickDelegateProtocol, NSTableViewDelegate>

@property Sequencer                 *sequencer;
@property SequencerPage             *currentPage;
@property SequencerState            *sequencerState;
@property SequencerPageState        *currentSequencerPageState;

@property BOOL                      isActive;

@property NSManagedObjectContext    *managedObjectContextForMainThread;
@property Preferences               *sharedPreferences;

@property dispatch_queue_t          bigSerialQueue;

- (void) updateUI;
- (void) clearPatternStartAlert;
- (void) clearPattern;

@end
