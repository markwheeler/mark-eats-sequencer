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

- (void) setBpm:(float)bpm
{
    @synchronized( self ) {
        _bpm = bpm;
    }
    [self updateInterval];
}

- (float) bpm
{    
    float result;
    @synchronized( self ) {
        result = _bpm;
    }
    return result;
}

- (void) setPpqn:(uint)ppqn
{
    @synchronized( self ) {
        _ppqn = ppqn;
    }
    [self updateInterval];
}

- (uint) ppqn
{
    uint result;
    @synchronized( self ) {
        result = _ppqn;
    }
    return result;
}

- (void) setQnPerMeasure:(uint)qnPerMeasure
{
    @synchronized( self ) {
        _qnPerMeasure = qnPerMeasure;
    }
    [self updateInterval];
}

- (uint) qnPerMeasure
{
    uint result;
    @synchronized( self ) {
        result = _qnPerMeasure;
    }
    return result;
}



#pragma mark - Public methods

- (id) init
{
    self = [super init];
    if (self) {
        
        _clockStatus = EatsClockStatus_Stopped;
        
        _bufferTimeInNs = 10000000; // 10ms
        
        // Create the serial queue and make it high priority
        _tickQueue = dispatch_queue_create("com.MarkEatsSequencer.ClockTickQueue", NULL);
        dispatch_queue_t globalHigh = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0);
        dispatch_set_target_queue(_tickQueue, globalHigh);
        
        kern_return_t kernError;
        mach_timebase_info_data_t timebaseInfo;
        
        kernError = mach_timebase_info(&timebaseInfo);
        if (kernError != KERN_SUCCESS) {
            NSLog(@"Error getting mach_timebase");
        } else {
            // Set the time factors so we can work in ns
            _machTimeToNsFactor = (double)timebaseInfo.numer / timebaseInfo.denom;
            _nsToMachTimeFactor = 1.0 / _machTimeToNsFactor;
        }
        
    }
    
    return self;
}

//- (void) dealloc
//{
//    NSLog(@"%s", __func__);
//}

- (void) startClock
{
    if(_clockStatus != EatsClockStatus_Stopped) [self setClockToZero];
    [self continueClock];
    
}

- (void) setClockToZero
{
    dispatch_async(_tickQueue, ^{
        [_delegate clockSongStart:self.tickTimeInNs];
    });
}

- (void) continueClock
{
    // If someone tries to start a timer while we're stopping, just cancel the stop
    if(_clockStatus == EatsClockStatus_Stopping) {
        _clockStatus = EatsClockStatus_Running;
        return;
        
    // Start one up if need be
    } else if(self.clockStatus == EatsClockStatus_Stopped) {
        // Set defaults if they haven't been set
        if(_bpm == 0) self.bpm = 120;
        if(_ppqn == 0) self.ppqn = 48;
        if(_qnPerMeasure == 0) self.qnPerMeasure = 4;
        
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
    if(_clockStatus == EatsClockStatus_Running)
        _clockStatus = EatsClockStatus_Stopping;
}



#pragma mark - Private methods

- (void) updateInterval
{
    // 1sec / ((bpm / secs in a min) * ppqn)
    _intervalInNs = 1000000000 / ((_bpm / 60.0) * _ppqn);
}

- (void) timerLoop
{
    _clockStatus = EatsClockStatus_Running;
    
    Float64 timeDifferenceInNs;
    
    // Set the start time
    _tickTimeInNs = (uint64_t)(mach_absolute_time() * _machTimeToNsFactor);
    _tickTimeInNs += _bufferTimeInNs;
    
    mach_wait_until( ( _tickTimeInNs - _bufferTimeInNs ) * _nsToMachTimeFactor );

    [self setClockToZero];

    // Clock loop
    while (_clockStatus == EatsClockStatus_Running) {
        
        // Send tick
        dispatch_async(_tickQueue, ^{
            [_delegate clockTick:_tickTimeInNs];
        });
        
        
        // Detect late ticks
        timeDifferenceInNs = ( (Float64)mach_absolute_time() * (Float64)_machTimeToNsFactor ) - (Float64)_tickTimeInNs;
        if( timeDifferenceInNs > _bufferTimeInNs ) {
            dispatch_async(_tickQueue, ^{
                [_delegate clockLateBy:(uint64_t)timeDifferenceInNs];
            });
        }
        
        // Wait until the next tick
        _tickTimeInNs += _intervalInNs;
        mach_wait_until( ( _tickTimeInNs - _bufferTimeInNs ) * _nsToMachTimeFactor );
        
    }

    // Stop
    dispatch_async(_tickQueue, ^{
        [_delegate clockSongStop:_tickTimeInNs];
    });

    _clockStatus = EatsClockStatus_Stopped;
    
}

@end
