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

typedef enum EatsPatternViewMode {
    EatsPatternViewMode_Edit,
    EatsPatternViewMode_NoteEdit,
    EatsPatternViewMode_Play
} EatsPatternViewMode;

@interface EatsGridPatternView : EatsGridSubView

@property SequencerPattern      *pattern;
@property uint                  currentStep;
@property EatsPatternViewMode   mode;
@property uint                  wipe; // 0-100

@end
