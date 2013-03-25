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

@property dispatch_queue_t tickQueue;

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

- (id) init
{
    self = [super init];
    if (self) {
        
        self.clockStatus = EatsClockStatus_Stopped;
        
        self.bufferTimeInNs = 20000000; // 20ms
        
        self.tickQueue = dispatch_queue_create("com.MarkEatsSequencer.ClockTick", NULL);
        
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

- (void) dealloc
{
    NSLog(@"%s", __func__);
}

- (void) startClock
{
    if(self.clockStatus != EatsClockStatus_Stopped) [self setClockToZero];
    [self continueClock];
    
}

- (void) setClockToZero
{
    if([self.delegate respondsToSelector:@selector(clockSongStart:)]) {
        dispatch_async(self.tickQueue, ^{
            [self.delegate clockSongStart:[NSNumber numberWithUnsignedLongLong:self.tickTimeInNs]];
        });
    }
}

- (void) continueClock
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
        
        // Create a thread to run the clock on
        NSThread* clockThread = [[NSThread alloc] initWithTarget:self
                                                        selector:@selector(timerLoop)
                                                          object:nil];
        [clockThread setThreadPriority:1.0];
        [clockThread setName:@"clock"];
        [clockThread start];
    }
}

- (void) stopClock
{
    if(self.clockStatus == EatsClockStatus_Running)
        self.clockStatus = EatsClockStatus_Stopping;
}



#pragma mark - Private methods

- (void) updateInterval
{    
    self.intervalInNs = 1000000000 / ((self.bpm / 60.0) * self.ppqn); // 1sec / ((bpm / secs in a min) * ppqn)

    //NSLog(@"Interval set to: %fms", self.intervalInNs / 1000000.0);
}

- (void) timerLoop
{
    
    @autoreleasepool {
    
        self.clockStatus = EatsClockStatus_Running;
        
        // Set the start time
        self.tickTimeInNs = (uint64_t)(mach_absolute_time() * self.machTimeToNsFactor);
        self.tickTimeInNs += self.bufferTimeInNs;
        
        mach_wait_until(((self.tickTimeInNs) - self.bufferTimeInNs) * self.nsToMachTimeFactor);
        
        Float64 timeDifferenceInNs;

        [self setClockToZero];
        
        while (self.clockStatus == EatsClockStatus_Running) {
            
            // Send tick
            if( [self.delegate respondsToSelector:@selector(clockTick:)] ) {
                //dispatch_debug(tickQueue, "TICK QUEUE");
                dispatch_async(self.tickQueue, ^{
                    [self.delegate clockTick:[NSNumber numberWithUnsignedLongLong:self.tickTimeInNs]];
                });
            }
            
            // Detect late ticks
            timeDifferenceInNs = (((Float64)(mach_absolute_time() * self.machTimeToNsFactor)) - self.tickTimeInNs);
            if( timeDifferenceInNs > 0 && [self.delegate respondsToSelector:@selector(clockLateBy:)] ) {
                
                dispatch_async(self.tickQueue, ^{
                    [self.delegate clockLateBy:[NSNumber numberWithFloat:timeDifferenceInNs]];
                });
            }
            
            // Wait until the next tick
            self.tickTimeInNs += self.intervalInNs;
            
            // Tried using nanosleep() instead but results seemed identical to mach_wait_until
            //struct timespec req = {0};
            //req.tv_sec = 0;
            //req.tv_nsec = (((self.tickTimeInNs) - self.bufferTimeInNs) * self.nsToMachTimeFactor) - (mach_absolute_time() * self.machTimeToNsFactor);
            //nanosleep(&req, (struct timespec *)NULL);
            
            mach_wait_until(((self.tickTimeInNs) - self.bufferTimeInNs) * self.nsToMachTimeFactor);
            
        }
        
        if([self.delegate respondsToSelector:@selector(clockSongStop:)]) {
            dispatch_async(self.tickQueue, ^{
                [self.delegate clockSongStop:[NSNumber numberWithUnsignedLongLong:(uint64_t)(mach_absolute_time() * self.machTimeToNsFactor)]];
            });
        }
        
        self.clockStatus = EatsClockStatus_Stopped;
        
    }
}

@end
