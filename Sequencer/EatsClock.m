//
//  EatsClock.m
//  Sequencer
//
//  Created by Mark Wheeler on 03/03/2013.
//  Copyright (c) 2013 Mark Eats. All rights reserved.
//

#import "EatsClock.h"

@interface EatsClock()

// The time in nanoseconds between ticks
@property uint64_t intervalInNs;

@property uint64_t tickTimeInNs;

@end


@implementation EatsClock

@synthesize bpm = _bpm;
@synthesize ppqn = _ppqn;
@synthesize qnPerMeasure = _qnPerMeasure;



#pragma mark - Setters and getters

- (void)setBpm:(float)bpm
{
    _bpm = bpm;
    [self updateInterval];
}

- (float)bpm {
    return _bpm;
}

- (void)setPpqn:(NSUInteger)ppqn
{
    _ppqn = ppqn;
    [self updateInterval];
}

- (NSUInteger)ppqn {
    return _ppqn;
}

- (void)setQnPerMeasure:(NSUInteger)qnPerMeasure
{
    _qnPerMeasure = qnPerMeasure;
    [self updateInterval];
}

- (NSUInteger)qnPerMeasure {
    return _qnPerMeasure;
}



#pragma mark - Public methods

- (id)init
{
    self = [super init];
    if (self) {
        
        
        
        self.clockStatus = EatsClockStatus_Stopped;
        
        self.bufferTimeInNs = 5000000; // 5ms
        
        kern_return_t kernError;
        mach_timebase_info_data_t timebaseInfo;
        
        kernError = mach_timebase_info(&timebaseInfo);
        if (kernError != KERN_SUCCESS) {
            NSLog(@"Error getting mach_timebase");
        } else {
            // Set the time factors so we can work in ns
            self.machTimeToNsFactor = (double)timebaseInfo.numer / timebaseInfo.denom;
            self.nsToMachTimeFactor = 1.0 / self.machTimeToNsFactor;
        }
        
    }
    
    return self;
}

- (void)startClock
{
    if(self.clockStatus != EatsClockStatus_Stopped) [self setClockToZero];
    [self continueClock];
    
}

- (void)setClockToZero
{
    if([self.delegate respondsToSelector:@selector(clockSongStart:)])
        [self.delegate performSelectorOnMainThread:@selector(clockSongStart:)
                                        withObject:[NSNumber numberWithUnsignedLongLong:self.tickTimeInNs]
                                     waitUntilDone:NO];
}

- (void)continueClock
{
    // If someone tries to start a timer while we're stopping, just cancel the stop
    if(self.clockStatus == EatsClockStatus_Stopping) {
        self.clockStatus = EatsClockStatus_Running;
        return;
        
        // Start one up if need be
    } else if(self.clockStatus == EatsClockStatus_Stopped) {
        // Set defaults if they haven't been set
        if(self.bpm == 0) self.bpm = 120;
        if(self.ppqn == 0) self.ppqn = 48;
        if(self.qnPerMeasure == 0) self.qnPerMeasure = 4;
        
        //self.timerStatus = EatsClockStatus_Stopped;
        
        // Create a thread to run the clock on
        NSThread* timerThread = [[NSThread alloc] initWithTarget:self
                                                        selector:@selector(timerLoop)
                                                          object:nil];
        [timerThread setThreadPriority:1.0];
        [timerThread start];
    }
}

- (void)stopClock
{
    if(self.clockStatus == EatsClockStatus_Running)
        self.clockStatus = EatsClockStatus_Stopping;
}



#pragma mark - Private methods

- (void)updateInterval {
    self.intervalInNs = 1000000000 / ((self.bpm / 60.0) * self.ppqn); // 1sec / ((bpm / secs in a min) * ppqn)
    
    //NSLog(@"Interval set to: %fms", self.intervalInNs / 1000000.0);
}

- (void)timerLoop
{
    self.clockStatus = EatsClockStatus_Running;
    
    // Set the start time
    self.tickTimeInNs = (uint64_t)(mach_absolute_time() * self.machTimeToNsFactor);
    
    self.tickTimeInNs += self.intervalInNs;
    mach_wait_until(((self.tickTimeInNs) - self.bufferTimeInNs) * self.nsToMachTimeFactor);
    
    Float64 timeDifferenceInNs;
    
    [self setClockToZero];
    
    while (self.clockStatus == EatsClockStatus_Running) {
        // Use autoreleasepool so we clear out everything on each loop
        @autoreleasepool {
            
            // Send tick
            if([self.delegate respondsToSelector:@selector(clockTick:)])
                [self.delegate performSelectorOnMainThread:@selector(clockTick:)
                                                withObject:[NSNumber numberWithUnsignedLongLong:self.tickTimeInNs]
                                             waitUntilDone:NO];
            
            // Detect late ticks
            timeDifferenceInNs = (((Float64)(mach_absolute_time() * self.machTimeToNsFactor)) - self.tickTimeInNs);
            if(timeDifferenceInNs > 0 && [self.delegate respondsToSelector:@selector(clockLateBy:)])
                [self.delegate performSelectorOnMainThread:@selector(clockLateBy:)
                                                withObject:[NSNumber numberWithFloat:timeDifferenceInNs]
                                             waitUntilDone:NO];
            
            // Wait until the next tick
            self.tickTimeInNs += self.intervalInNs;
            mach_wait_until(((self.tickTimeInNs) - self.bufferTimeInNs) * self.nsToMachTimeFactor);
        }
        
    }
    
    if([self.delegate respondsToSelector:@selector(clockSongStop:)])
        [self.delegate performSelectorOnMainThread:@selector(clockSongStop:)
                                        withObject:[NSNumber numberWithUnsignedLongLong:(uint64_t)(mach_absolute_time() * self.machTimeToNsFactor)]
                                     waitUntilDone:NO];
    
    self.clockStatus = EatsClockStatus_Stopped;
}

@end
