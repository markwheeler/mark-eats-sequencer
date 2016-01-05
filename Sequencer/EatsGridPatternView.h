//
//  EatsGridPatternView.h
//  Sequencer
//
//  Created by Mark Wheeler on 22/03/2013.
//  Copyright (c) 2013 Mark Eats. All rights reserved.
//
//  Displays a grid of notes from a given pattern

#import <Foundation/Foundation.h>
#import "EatsGridSubView.h"
#import "SequencerNote.h"

@class EatsGridPatternView;

@protocol EatsGridPatternViewDelegateProtocol
- (void) eatsGridPatternViewPressAt:(NSDictionary *)xyDown sender:(EatsGridPatternView *)sender;
@optional
- (void) eatsGridPatternViewLongPressAt:(NSDictionary *)xy sender:(EatsGridPatternView *)sender;
- (void) eatsGridPatternViewSelection:(NSDictionary *)selection sender:(EatsGridPatternView *)sender;
@end

typedef enum EatsPatternViewMode {
    EatsPatternViewMode_Edit,
    EatsPatternViewMode_NoteEdit,
    EatsPatternViewMode_Play
} EatsPatternViewMode;

typedef enum EatsPatternViewFoldFrom {
    EatsPatternViewFoldFrom_Top,
    EatsPatternViewFoldFrom_Bottom
} EatsPatternViewFoldFrom;


@interface EatsGridPatternView : EatsGridSubView

@property NSSet                     *notes;
@property BOOL                      drawNotesForReverse;
@property int                       currentStep;
@property NSNumber                  *nextStep;


@property uint                      patternHeight;
@property SequencerNote             *activeEditNote;
@property float                     noteEditModeAnimationAmount;
@property BOOL                      animatingIn;
@property EatsPatternViewMode       mode;
@property EatsPatternViewFoldFrom   foldFrom;
@property uint                      wipe; // 0-100

@property dispatch_queue_t          gridQueue;

@end
