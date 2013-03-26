//
//  EatsClock.h
//  Sequencer
//
//  Created by Mark Wheeler on 03/03/2013.
//  Copyright (c) 2013 Mark Eats. All rights reserved.
//
//  Fires off 'tick' events at intervals

#import <Foundation/Foundation.h>
#import <mach/mach_time.h>

@protocol EatsClockDelegateProtocol
- (void) clockSongStart:(Float64)ns;
- (void) clockSongStop:(Float64)ns;
- (void) clockTick:(Float64)ns;
- (void) clockLateBy:(Float64)ns;
@end

typedef enum EatsClockStatus{
    EatsClockStatus_Stopped,
    EatsClockStatus_Running,
    EatsClockStatus_Stopping
} EatsClockStatus;

@interface EatsClock : NSObject

@property (weak) id delegate;

@property float         bpm;
@property NSUInteger    ppqn; // MIDI clock sends 24. Setting to 48 means we can do that and also 16ppqn triggers.
@property NSUInteger    qnPerMeasure; // Use this to work out when a bar starts/ends (ie, effects count)

// The amount of time before the tick that the code is going to schedule MIDI notes etc. This will also be how early the UI starts to update
@property uint64_t      bufferTimeInNs;

@property double        machTimeToNsFactor;
@property double        nsToMachTimeFactor;

@property EatsClockStatus clockStatus;

- (void)startClock;
- (void)setClockToZero;
- (void)continueClock;
- (void)stopClock;

@end
