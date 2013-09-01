//
//  SequencerPageState.h
//  Sequencer
//
//  Created by Mark Wheeler on 27/04/2013.
//  Copyright (c) 2013 Mark Eats. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface SequencerPageState : NSObject

@property int                   currentPatternId;
@property NSNumber              *nextPatternId; // This is an NSNumber so we can set it to nil

@property int                   currentStep;
@property NSNumber              *nextStep; // This is an NSNumber so we can set it to nil
@property BOOL                  stutter;
@property BOOL                  inStutter;
@property BOOL                  inLoop;

@property int                   playMode;

@end
