//
//  ClockTick.m
//  Sequencer
//
//  Created by Mark Wheeler on 21/03/2013.
//  Copyright (c) 2013 Mark Eats. All rights reserved.
//

#import "ClockTick.h"
#import "EatsCommunicationManager.h"
#import "Preferences.h"
#import "Sequencer+Utils.h"
#import "SequencerPage.h"
#import "SequencerRowPitch.h"
#import "SequencerPattern.h"
#import "SequencerNote.h"

@interface ClockTick ()

@property EatsCommunicationManager      *sharedCommunicationManager;
@property Preferences                   *sharedPreferences;

@property NSUInteger        currentTick;
@property NSMutableArray    *activeNotes;

@end

@implementation ClockTick


#pragma mark - Public methods

- (id)init
{
    self = [super init];
    if (self) {
        _sharedCommunicationManager = [EatsCommunicationManager sharedCommunicationManager];
        _sharedPreferences = [Preferences sharedPreferences];
    }
    return self;
}

- (void) dealloc
{
    NSLog(@"%s", __func__);
}



#pragma mark - Clock delegate methods

- (void) clockSongStart:(uint64_t)ns
{
    
    // Create the objects needed for keeping track of active notes
    if(!_activeNotes) {
        _activeNotes = [NSMutableArray array];
        for(int i = 0; i < _minQuantization; i++)
            [_activeNotes addObject:[NSMutableSet setWithCapacity:32]];
    }
    
    _currentTick = 0;
    
    if(_sharedPreferences.sendMIDIClock) {
        // Send song position 0
        VVMIDIMessage *msg = nil;
        msg = [VVMIDIMessage createFromVals:VVMIDISongPosPointerVal :0 :0 :0 :ns];
        if (msg != nil)
            [_sharedCommunicationManager.midiManager sendMsg:msg];
        
        // Send start
        msg = nil;
        msg = [VVMIDIMessage createWithType:VVMIDIStartVal channel:0 timestamp:ns];
        if (msg != nil)
            [_sharedCommunicationManager.midiManager sendMsg:msg];
    }
}

- (void) clockSongStop:(uint64_t)ns
{
    
    // [_externalClockCalculator resetExternalClock]; TODO: Add external clock support back in (AppController? Or at Document level?)
    
    if(_sharedPreferences.sendMIDIClock) {
        // Send stop
        VVMIDIMessage *msg = nil;
        msg = [VVMIDIMessage createWithType:VVMIDIStopVal channel:0 timestamp:ns];
        if (msg != nil) {
            [_sharedCommunicationManager.midiManager sendMsg:msg];
        }
    }
    
    [self stopAllActiveMIDINotes:ns];
}

- (void) clockTick:(uint64_t)ns
{
    // This function only works when both MIN_QUANTIZATION and MIDI_CLOCK_PPQN can cleanly divide into the clock ticks
    // Could re-work it in future to allow other time signatures
    
    // TODO: Only fire on MIN_QUANTIZATION. Schedule more than 1 clock pulse if need be
    
    //NSLog(@"Tick: %lu Time: %@", (unsigned long)_currentTick, ns);
    //if( [NSThread isMainThread] ) NSLog(@"%s is running on main thread", __func__);
    
    // Every second tick (even) – 1/96 notes – send MIDI Clock pulse
    if(_currentTick % (_ppqn / _midiClockPPQN) == 0 && _sharedPreferences.sendMIDIClock) {
        [self sendMIDIClockPulseAtTime:ns];
    }
    
    // Every third tick – 1/64 notes (smallest quantization possible)
    if( _currentTick % (_ticksPerMeasure / _minQuantization) == 0 ) {
        
        // Check if any of the active notes need to be stopped this tick
        NSMutableSet *notesToStop = [_activeNotes objectAtIndex:_currentTick / (_ticksPerMeasure / _minQuantization)];
        for( NSDictionary *note in notesToStop ) {
            [self stopMIDINote:[[note objectForKey:@"pitch"] intValue]
                     onChannel:[[note objectForKey:@"channel"] intValue]
                  withVelocity:[[note objectForKey:@"velocity"] intValue]
                        atTime:ns];
        }
        [notesToStop removeAllObjects];
        
        // Update the sequencer pages and send notes
        
        // For each page...
        for(SequencerPage *page in _sequencer.pages) {
            
            // Play notes for current step, playMode != paused
            if( _currentTick % (_ticksPerMeasure / [page.stepLength intValue]) == 0 && [page.playMode intValue] != EatsSequencerPlayMode_Pause ) {
                
                // TODO: Something in these lines is causing a memory leak if it's running when we close the document.
                //       Seems to be anything that sets the page's properties means this class doesn't get released quick enough.
                
                // If page has been scrubbed
                if( page.nextStep ) {
                    page.currentStep = [page.nextStep copy];
                    
                } else {
                    
                    int playNow = page.currentStep.intValue;
                    
                    // Forward
                    if( page.playMode.intValue == EatsSequencerPlayMode_Forward ) {
                        playNow ++;
                        if( page.loopStart.intValue <= page.loopEnd.intValue ) {
                            if( playNow == page.loopEnd.intValue + 1 && !page.nextStep )
                                playNow = page.loopStart.intValue;
                            
                        } else {
                            if( playNow == page.loopEnd.intValue + 1 && !page.nextStep )
                                playNow = page.loopStart.intValue;
                        }
                        if( playNow >= _sharedPreferences.gridWidth )
                            playNow = 0;
                    
                    // Reverse
                    } else if( page.playMode.intValue == EatsSequencerPlayMode_Reverse ) {
                        playNow --;
                        if( page.loopStart.intValue <= page.loopEnd.intValue ) {
                            if( playNow == page.loopStart.intValue -1 && !page.nextStep )
                                playNow = page.loopEnd.intValue;
                        } else {
                            if( playNow == page.loopStart.intValue - 1 && !page.nextStep )
                                playNow = page.loopEnd.intValue;
                        }
                        if( playNow < 0 )
                            playNow = _sharedPreferences.gridWidth - 1;
                     
                    // Random
                    } else if( page.playMode.intValue == EatsSequencerPlayMode_Random ) {
                        playNow = [Sequencer randomStepForPage:page ofWidth:_sharedPreferences.gridWidth];
                    }
                    
                    page.currentStep = [NSNumber numberWithInt: playNow];
                }
                
                page.nextStep = nil;
                
                

                // Send notes that need to be sent
                
                for( SequencerNote *note in [[page.patterns objectAtIndex:[page.currentPattern intValue]] notes] ) {
                    
                    if( note.step == page.currentStep ) {
                        
                        //Set note properties
                        int channel = [page.channel intValue];
                        int velocity = floor( 127 * ([note.velocityAsPercentage floatValue] / 100.0 ) );
                        int pitch = [[[page.pitches objectAtIndex:[note.row intValue]] pitch] intValue];
                        
                        // This number in the end here is the number of MIN_QUANTIZATION steps that the note will be in length. Must be between 1 and MIN_QUANTIZATION
                        int endStep = ((int)_currentTick / ( _ticksPerMeasure / _minQuantization )) + 2; // TODO: base this on note.length
                        if(endStep >= _minQuantization)
                            endStep -= _minQuantization;
                        
                        // Send MIDI note
                        [self startMIDINote:pitch
                                  onChannel:channel
                               withVelocity:velocity
                                     atTime:ns];
                        
                        // Add to activeNotes so we know when to stop it
                        [[_activeNotes objectAtIndex:endStep] addObject:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:pitch], @"pitch",
                                                                             [NSNumber numberWithInt:channel], @"channel",
                                                                             [NSNumber numberWithInt:velocity], @"velocity",
                                                                             nil]];
                        
                        // TODO: See if it's possible to check if notes are being sent late based on their timestamp vs current time?
                    }
                    
                }
                
            }
            
        }
        
        // Tell the delegate to update the interface (doing this on main thread because it uses non-thread-safe NSManagedObjectContext
        if([_delegate respondsToSelector:@selector(updateUI)])
            [_delegate performSelectorOnMainThread:@selector(updateUI)
                                            withObject:nil
                                         waitUntilDone:NO];
        
    }
    
    // Increment the tick to the next step
    _currentTick++;
    if(_currentTick >= _ticksPerMeasure) _currentTick = 0;
}

- (void) clockLateBy:(uint64_t)ns
{
    // TODO: Create a visual indicator for this
    NSLog(@"\nClock tick was late by: %fms", (Float64)ns / 1000000.0);
}



#pragma mark - Private methods for sending and stopping MIDI

- (void) startMIDINote:(int)n
             onChannel:(int)c
          withVelocity:(int)v
                atTime:(uint64_t)ns
{
    VVMIDIMessage *msg = nil;
	//	Create a message
	msg = [VVMIDIMessage createFromVals:VVMIDINoteOnVal :c :n :v :ns];
    // Send it
	if (msg != nil)
		[_sharedCommunicationManager.midiManager sendMsg:msg];
}

- (void) stopMIDINote:(int)n
            onChannel:(int)c
         withVelocity:(int)v
               atTime:(uint64_t)ns
{
    VVMIDIMessage *msg = nil;
	//	Create a message
	msg = [VVMIDIMessage createFromVals:VVMIDINoteOffVal :c :n :v :ns];
    // Send it
	if (msg != nil)
		[_sharedCommunicationManager.midiManager sendMsg:msg];
}

- (void) sendMIDIClockPulseAtTime:(uint64_t)ns
{
    VVMIDIMessage *msg = nil;
	//	Create a message
	msg = [VVMIDIMessage createWithType:VVMIDIClockVal channel:0 timestamp:ns];
    // Send it
	if (msg != nil)
		[_sharedCommunicationManager.midiManager sendMsg:msg];
}

- (void) stopAllActiveMIDINotes:(Float64)ns
{
    for( NSMutableSet *notesToStop in _activeNotes ) {
        for( NSDictionary *note in notesToStop ) {
            [self stopMIDINote:[[note objectForKey:@"pitch"] intValue]
                     onChannel:[[note objectForKey:@"channel"] intValue]
                  withVelocity:[[note objectForKey:@"velocity"] intValue]
                        atTime:ns];
        }
        [notesToStop removeAllObjects];
    }
}

@end
