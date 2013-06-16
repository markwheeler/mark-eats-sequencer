//
//  EatsGridNavigationController.h
//  Sequencer
//
//  Created by Mark Wheeler on 04/03/2013.
//  Copyright (c) 2013 Mark Eats. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <VVOSC/VVOSC.h>
#import <VVMIDI/VVMIDI.h>
#import "Sequencer+Utils.h"
#import "SequencerPattern.h"
#import "SequencerPageState.h"

typedef enum EatsGridViewType{
    EatsGridViewType_None,
    EatsGridViewType_Intro,
    EatsGridViewType_Sequencer,
    EatsGridViewType_Play
} EatsGridViewType;

@protocol EatsGridViewDelegateProtocol
@property BOOL                      isActive;
@property Sequencer                 *sequencer;
@property SequencerPattern          *currentPattern;
@property SequencerPageState        *currentSequencerPageState;
- (void) updateGridWithArray:(NSArray *)gridArray;
- (void) showView:(NSNumber *)gridView;
- (void) setNewPageId:(NSNumber *)id;
@end


@interface EatsGridNavigationController : NSObject <EatsGridViewDelegateProtocol>

@property BOOL                      isActive;
@property NSManagedObjectContext    *managedObjectContext;
@property Sequencer                 *sequencer;
@property SequencerPattern          *currentPattern;
@property SequencerPageState        *currentSequencerPageState;

- (id) initWithManagedObjectContext:(NSManagedObjectContext *)context;
- (void) updateGridView;
- (void) updateGridWithArray:(NSArray *)gridArray;
- (void) showView:(NSNumber *)gridView;
- (void) setNewPageId:(NSNumber *)id;

@end
