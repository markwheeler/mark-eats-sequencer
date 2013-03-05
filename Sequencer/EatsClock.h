//
//  EatsClock.h
//  Sequencer
//
//  Created by Mark Wheeler on 03/03/2013.
//  Copyright (c) 2013 Mark Eats. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <mach/mach_time.h>

@protocol EatsClockDelegateProtocol
- (void) clockSongStart:(NSNumber *)ns;
- (void) clockSongStop:(NSNumber *)ns;
- (void) clockTick:(NSNumber *)ns;
@optional
- (void) clockLateBy:(NSNumber *)ns;
@end

@interface EatsClock : NSObject

@property (weak) id delegate;

@property float         bpm;
@property NSUInteger    ppqn; // MIDI clock sends 24. Setting to 48 means we can do that and also 16ppqn triggers.
@property NSUInteger    qnPerMeasure; // Use this to work out when a bar starts/ends (ie, effects count)

// The amount of time before the tick that the code is going to schedule MIDI notes etc. This will also be how early the UI starts to update
@property uint64_t      bufferTimeInNs;

@property double        machTimeToNsFactor;
@property double        nsToMachTimeFactor;

@property int           clockStatus;
extern int const        CLOCK_STATUS_STOPPED;
extern int const        CLOCK_STATUS_RUNNING;
extern int const        CLOCK_STATUS_STOPPING;

- (void)startClock;
- (void)setClockToZero;
- (void)continueClock;
- (void)stopClock;

@end
