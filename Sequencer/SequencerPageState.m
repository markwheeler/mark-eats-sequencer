//
//  SequencerPageState.m
//  Sequencer
//
//  Created by Mark Wheeler on 27/04/2013.
//  Copyright (c) 2013 Mark Eats. All rights reserved.
//

#import "SequencerPageState.h"

@implementation SequencerPageState

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@: %p, CurrentPatternId: %i, NextPatternId: %@, CurrentStep: %i, NextStep: %@, InLoop: %i, PageTick: %i, PlayMode: %i>", NSStringFromClass([self class]), self, self.currentPatternId, self.nextPatternId, self.currentStep, self.nextStep, self.inLoop, self.pageTick, self.playMode];
}

@end