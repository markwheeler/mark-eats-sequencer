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
    return [NSString stringWithFormat:@"<%@: %p, CurrentPatternId: %i, NextPatternId: %@, CurrentStep: %i, NextStep: %@, Stutter: %i, InStutter: %i, InLoop: %i, PlayMode: %i>", NSStringFromClass([self class]), self, self.currentPatternId, self.nextPatternId, self.currentStep, self.nextStep, self.stutter, self.inStutter, self.inLoop, self.playMode];
}

@end