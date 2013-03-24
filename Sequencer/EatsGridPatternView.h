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
@end

typedef enum EatsPatternViewMode {
    EatsPatternViewMode_Edit,
    EatsPatternViewMode_NoteEdit,
    EatsPatternViewMode_Play
} EatsPatternViewMode;

@interface EatsGridPatternView : EatsGridSubView

@property uint                  currentStep;
@property SequencerPattern      *pattern;
@property SequencerNote         *activeEditNote;
@property EatsPatternViewMode   mode;
@property uint                  wipe; // 0-100

@end
