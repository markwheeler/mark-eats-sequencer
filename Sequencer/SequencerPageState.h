//
//  SequencerPageState.h
//  Sequencer
//
//  Created by Mark Wheeler on 27/04/2013.
//  Copyright (c) 2013 Mark Eats. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef enum EatsSequencerPlayMode {
    EatsSequencerPlayMode_Pause,
    EatsSequencerPlayMode_Forward,
    EatsSequencerPlayMode_Reverse,
    EatsSequencerPlayMode_Random
} EatsSequencerPlayMode;

@interface SequencerPageState : NSObject

@property NSNumber              *currentPatternId;
@property NSNumber              *nextPatternId;

@property NSNumber              *currentStep;
@property NSNumber              *nextStep;
@property BOOL                  inLoop;

@property EatsSequencerPlayMode playMode;

@end
