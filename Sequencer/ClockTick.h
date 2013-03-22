//
//  ClockTick.h
//  Sequencer
//
//  Created by Mark Wheeler on 21/03/2013.
//  Copyright (c) 2013 Mark Eats. All rights reserved.
//
//  Delegate of clock, gets called on tick then sends MIDI events and notifies delegate to update UI

#import <Foundation/Foundation.h>
#import "EatsClock.h"
#import "Sequencer.h"

@protocol ClockTickDelegateProtocol
@optional
- (void) updateUI;
@end

@interface ClockTick : NSObject <EatsClockDelegateProtocol>

@property (weak) id delegate;

@property int ppqn;
@property int ticksPerMeasure;
@property int midiClockPPQN;
@property int minQuantization;

@property Sequencer *sequencer;

@end
