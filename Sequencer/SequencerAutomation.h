//
//  SequencerAutomation.h
//  Sequencer
//
//  Created by Mark Wheeler on 24/12/2013.
//  Copyright (c) 2013 Mark Eats. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef enum EatsSequencerAutomationMode {
    EatsSequencerAutomationMode_Inactive,
    EatsSequencerAutomationMode_Armed,
    EatsSequencerAutomationMode_Recording,
    EatsSequencerAutomationMode_Playing
} EatsSequencerAutomationMode;

typedef enum EatsSequencerAutomationType {
    EatsSequencerAutomationType_SetNextPatternId,
    EatsSequencerAutomationType_SetNextStep,
    EatsSequencerAutomationType_SetLoop,
    EatsSequencerAutomationType_SetTranspose,
    EatsSequencerAutomationType_SetPlayMode
} EatsSequencerAutomationType;

@interface SequencerAutomation : NSObject <NSCoding>

@property uint                          currentTick;
@property EatsSequencerAutomationMode   mode;
@property uint                          loopLength;
@property NSMutableSet                  *changes; // Contains SequencerAutomationChange objects

@property NSArray                       *automationTypes;

@end