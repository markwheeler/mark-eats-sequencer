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
#import "SequencerPattern.h"

@class EatsGridPatternView;

@protocol EatsGridPatternViewDelegateProtocol
- (void) eatsGridPatternViewPressAt:(NSDictionary *)xyDown sender:(EatsGridPatternView *)sender;
@optional
- (void) eatsGridPatternViewDoublePressAt:(NSDictionary *)xy sender:(EatsGridPatternView *)sender;
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

@property NSManagedObjectContext    *managedObjectContext;
@property NSNumber                  *currentPageId;

@property uint                      patternHeight;
@property SequencerNote             *activeEditNote;
@property EatsPatternViewMode       mode;
@property EatsPatternViewFoldFrom   foldFrom;
@property uint                      wipe; // 0-100

@property uint                      playheadBrightness;
@property uint                      nextStepBrightness;
@property uint                      noteBrightness;
@property uint                      noteLengthBrightness;
@property float                     doublePressTime;

@end
