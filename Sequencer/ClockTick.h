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
@property BOOL isActive;
@end

@interface ClockTick : NSObject <EatsClockDelegateProtocol>

@property (weak) id delegate;

@property float         bpm;
@property int           ppqn;
@property int           ticksPerMeasure;
@property int           midiClockPPQN;
@property int           minQuantization;
@property uint          qnPerMeasure;

@property Sequencer     *sequencer;

- (void) clockSongStart:(uint64_t)ns;
- (void) clockSongStop:(uint64_t)ns;
- (void) songPositionZero;
- (void) clockTick:(uint64_t)ns;
- (void) clockLateBy:(uint64_t)ns;

- (id)initWithSequencer:(Sequencer *)sequencer;

@end
