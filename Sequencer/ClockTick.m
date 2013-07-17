//
//  ClockTick.m
//  Sequencer
//
//  Created by Mark Wheeler on 21/03/2013.
//  Copyright (c) 2013 Mark Eats. All rights reserved.
//

#import "ClockTick.h"
#import "EatsCommunicationManager.h"
#import "EatsSwingUtils.h"
#import "EatsVelocityUtils.h"
#import "Preferences.h"
#import "Sequencer+Utils.h"
#import "SequencerPage.h"
#import "SequencerRowPitch.h"
#import "SequencerPattern.h"
#import "SequencerNote.h"
#import "SequencerState.h"
#import "SequencerPageState.h"

typedef enum EatsStepAdvance {
    EatsStepAdvance_None,
    EatsStepAdvance_Normal,
    EatsStepAdvance_Scrubbed
} EatsStepAdvance;

@interface ClockTick ()

@property EatsCommunicationManager      *sharedCommunicationManager;
@property Preferences                   *sharedPreferences;
@property SequencerState                *sequencerState;
@property Sequencer                     *sequencer;

@property uint              currentTick;
@property NSMutableArray    *activeNotes;

@end

@implementation ClockTick


#pragma mark - Public methods

- (id)initWithManagedObjectContext:(NSManagedObjectContext *)context andSequencerState:(SequencerState *)sequencerState
{
    self = [super init];
    if (self) {
        _sharedCommunicationManager = [EatsCommunicationManager sharedCommunicationManager];
        _sharedPreferences = [Preferences sharedPreferences];
        _sequencerState = sequencerState;
        _managedObjectContext = context;
        
        [self.managedObjectContext performBlockAndWait:^(void) {
            NSError *requestError = nil;
            NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"Sequencer"];
            
            NSArray *matches = [self.managedObjectContext executeFetchRequest:request error:&requestError];
            
            if( requestError )
                NSLog(@"Request error: %@", requestError);
            
            _sequencer = [matches lastObject];
        }];
    }
    return self;
}

//- (void) dealloc
//{
//    NSLog(@"%s", __func__);
//}



#pragma mark - Clock delegate methods

- (void) clockSongStart:(uint64_t)ns
{
    
    // Create the objects needed for keeping track of active notes
    if(!_activeNotes) {
        _activeNotes = [NSMutableArray arrayWithCapacity:32];
    }
    
    _currentTick = 0;
    
    if( _sharedPreferences.sendMIDIClock
       && _sharedPreferences.midiClockSourceName == nil
       && [[_delegate valueForKey:@"isActive"] boolValue] ) {
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
    if( _sharedPreferences.sendMIDIClock
       && _sharedPreferences.midiClockSourceName == nil
       && [[_delegate valueForKey:@"isActive"] boolValue] ) {
        // Send stop
        VVMIDIMessage *msg = nil;
        msg = [VVMIDIMessage createWithType:VVMIDIStopVal channel:0 timestamp:ns];
        if (msg != nil) {
            [_sharedCommunicationManager.midiManager sendMsg:msg];
        }
    }
    
    [self stopNotes:_activeNotes atTime:ns];
    [_activeNotes removeAllObjects];
}

- (void) clockTick:(uint64_t)ns
{
    // This function only works when both MIN_QUANTIZATION and MIDI_CLOCK_PPQN can cleanly divide into the clock ticks
    // Could re-work it in future to allow other time signatures
    
    // TODO: Only fire on MIN_QUANTIZATION. Schedule more than 1 clock pulse if need be
    
    //NSLog(@"Tick: %lu Time: %@", (unsigned long)_currentTick, ns);
    //if( [NSThread isMainThread] ) NSLog(@"%s is running on main thread", __func__);
    
    // Every second tick (even) – 1/96 notes – send MIDI Clock pulse
    if( _currentTick % (_ppqn / _midiClockPPQN) == 0
       && _sharedPreferences.sendMIDIClock
       && _sharedPreferences.midiClockSourceName == nil
       && [[_delegate valueForKey:@"isActive"] boolValue] ) {
        [self sendMIDIClockPulseAtTime:ns];
    }
    
    // Every third tick – 1/64 notes (smallest quantization possible)
    if( _currentTick % (_ticksPerMeasure / _minQuantization) == 0 ) {
        
        // Check if any of the active notes need to be stopped this tick
        
        NSMutableArray *toRemove = [NSMutableArray arrayWithCapacity:8];
        for( NSMutableDictionary *note in _activeNotes ) {
            
            int lengthRemaining = [[note objectForKey:@"lengthRemaining"] intValue];
            lengthRemaining --;
            
            if( lengthRemaining <= 0 )
                [toRemove addObject:note];
            else
                [note setObject:[NSNumber numberWithInt:lengthRemaining] forKey:@"lengthRemaining"];
        }
        
        [self stopNotes:toRemove atTime:ns];
        [_activeNotes removeObjectsInArray:toRemove];
        
        
        [self.managedObjectContext performBlock:^(void) {
            
            BOOL aPageNeedsToAdvance = NO;
            
            // Update the current step for each page and send new notes
            
            for(SequencerPage *page in _sequencer.pages) {
                
                SequencerPageState *pageState = [_sequencerState.pageStates objectAtIndex:page.id.unsignedIntegerValue];
                
                // This will return if the user is scrubbing or the page is ready to advance on it's own (or neither)
                EatsStepAdvance needsToAdvance = [self needToAdvanceStep:page];
                
                // If we need to advance and it's not paused
                if( needsToAdvance != EatsStepAdvance_None && pageState.playMode.intValue != EatsSequencerPlayMode_Pause ) {
                    
                    aPageNeedsToAdvance = YES;
                    
                    // If the page has been scrubbed
                    if( needsToAdvance == EatsStepAdvance_Scrubbed ) {
                        pageState.currentStep = [pageState.nextStep copy];
                        pageState.nextStep = nil;
                        
                    // Otherwise we need to calculate the next step
                    } else {
                        
                        int playNow = pageState.currentStep.intValue;
                        
                        // Forward
                        if( pageState.playMode.intValue == EatsSequencerPlayMode_Forward ) {
                            playNow ++;
                            if( page.loopStart.intValue <= page.loopEnd.intValue ) {
                                if( ( pageState.inLoop || _sharedPreferences.loopFromScrubArea ) && playNow > page.loopEnd.intValue )
                                    playNow = page.loopStart.intValue;
                                else if( pageState.inLoop && playNow < page.loopStart.intValue )
                                    playNow = page.loopEnd.intValue;
                            } else {
                                if( ( pageState.inLoop || _sharedPreferences.loopFromScrubArea ) && playNow > page.loopEnd.intValue && playNow < page.loopStart.intValue )
                                    playNow = page.loopStart.intValue;
                            }
                            
                            if( playNow >= _sharedPreferences.gridWidth )
                                playNow = 0;
                            
                        // Reverse
                        } else if( pageState.playMode.intValue == EatsSequencerPlayMode_Reverse ) {
                            playNow --;
                            if( page.loopStart.intValue <= page.loopEnd.intValue ) {
                                if( ( pageState.inLoop || _sharedPreferences.loopFromScrubArea ) && playNow < page.loopStart.intValue )
                                    playNow = page.loopEnd.intValue;
                                else if( pageState.inLoop && playNow > page.loopEnd.intValue )
                                    playNow = page.loopStart.intValue;
                            } else {
                                if( ( pageState.inLoop || _sharedPreferences.loopFromScrubArea ) && playNow > page.loopEnd.intValue && playNow < page.loopStart.intValue )
                                    playNow = page.loopEnd.intValue;
                            }
                            
                            if( playNow < 0 )
                                playNow = _sharedPreferences.gridWidth - 1;
                            
                        // Random
                        } else if( pageState.playMode.intValue == EatsSequencerPlayMode_Random ) {
                            playNow = [Sequencer randomStepForPage:page ofWidth:_sharedPreferences.gridWidth];
                        }
                        
                        pageState.currentStep = [NSNumber numberWithInt: playNow];
                    }
                    
                    
                    // Are we in a loop
                    if( page.loopStart.intValue <= page.loopEnd.intValue ) {
                        if( pageState.currentStep.intValue >= page.loopStart.intValue && pageState.currentStep.intValue <= page.loopEnd.intValue
                           && page.loopEnd.intValue - page.loopStart.intValue != _sharedPreferences.gridWidth - 1 )
                            pageState.inLoop = YES;
                        else
                            pageState.inLoop = NO;
                    } else {
                        if( pageState.currentStep.intValue >= page.loopStart.intValue || pageState.currentStep.intValue <= page.loopEnd.intValue )
                            pageState.inLoop = YES;
                        else
                            pageState.inLoop = NO;
                    }
                    
                    
                    // OK now we know what the step is we can get on with acting upon it!
                    
                    
                    // Position of step in the loop 0 - minQuantization (unless loop is shorter)
                    uint position = ( pageState.currentStep.intValue * ( _minQuantization / page.stepLength.intValue ) );
                    
                    // Use the appropriate value if pattern quantization is set to none
                    int patternQuantization = _sequencer.patternQuantization.intValue;
                    if( patternQuantization == 0 )
                        patternQuantization = _sharedPreferences.gridWidth;
                    
                    // Position of step within loop 0 – minQuantization
                    int positionWithinLoop;
                    if( pageState.playMode.intValue == EatsSequencerPlayMode_Reverse )
                        positionWithinLoop = ( ((_sharedPreferences.gridWidth - 1 - pageState.currentStep.floatValue) / _sharedPreferences.gridWidth) * _minQuantization );
                    else
                        positionWithinLoop = ( (pageState.currentStep.floatValue / _sharedPreferences.gridWidth) * _minQuantization );
                    
                    // Check if we need to advance the pattern (depending on where we are within it)
                    if( pageState.nextPatternId && positionWithinLoop % (_minQuantization / patternQuantization ) == 0 ) {
                        pageState.currentPatternId = [pageState.nextPatternId copy];
                        pageState.nextPatternId = nil;
                    }


                    // Send notes that need to be sent
                    
                    for( SequencerNote *note in [[page.patterns objectAtIndex:pageState.currentPatternId.intValue] notes] ) {
                        
                        int pitch = [[[page.pitches objectAtIndex:note.row.intValue] pitch] intValue];
                        
                        // Play it!
                        if( note.step.intValue == pageState.currentStep.intValue ) {
                            
                            //Set the basic note properties
                            int channel = page.channel.intValue;
                            int velocity = floor( 127 * ([note.velocityAsPercentage floatValue] / 100.0 ) );
                            
                            // Calculate swing and velocity
                            
                            uint64_t nsSwing = 0;
                            
                            // We only add swing and velocity groove when playing forward or reverse
                            if( pageState.playMode.intValue== EatsSequencerPlayMode_Forward || pageState.playMode.intValue == EatsSequencerPlayMode_Reverse ) {
                                
                                // Reverse position if we're playing in reverse
                                if( pageState.playMode.intValue == EatsSequencerPlayMode_Reverse )
                                    position = _minQuantization - 1 - position;
                                
                                //NSLog(@"Note position: %u", position);
                                
                                // Calculate the swing based on note position etc
                                nsSwing = [EatsSwingUtils calculateSwingNsForPosition:position
                                                                                 type:page.swingType.intValue
                                                                               amount:page.swingAmount.intValue
                                                                                  bpm:_bpm
                                                                         qnPerMeasure:_qnPerMeasure
                                                                      minQuantization:_minQuantization];
                                // Velocity groove if enabled
                                if( page.velocityGroove.boolValue ) {
                                    velocity = [EatsVelocityUtils calculateVelocityForPosition:position
                                                                                  baseVelocity:velocity
                                                                                          type:page.swingType.intValue
                                                                               minQuantization:_minQuantization];
                                }
                            }
                            
                            
                            // Send MIDI note
                            [self startMIDINote:pitch
                                      onChannel:channel
                                   withVelocity:velocity
                                         atTime:ns + nsSwing];
                            
                            // This number in the end here is the MIN_QUANTIZATION steps that the note will be in length.
                            int length = roundf( note.length.floatValue * ( _minQuantization / page.stepLength.floatValue ) );
                            if( length < 1 )
                                NSLog(@"Note added to active notes was too short: %i", length);
                            // Add to activeNotes so we know when to stop it
                            [_activeNotes addObject:[NSMutableDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:pitch], @"pitch",
                                                                                                      [NSNumber numberWithInt:channel], @"channel",
                                                                                                      [NSNumber numberWithInt:velocity], @"velocity",
                                                                                                      [NSNumber numberWithInt:length], @"lengthRemaining",
                                                                                                      page, @"fromPage",
                                                                                                      nil]];
                        }
                        
                    }
                    
                }
                
            }
            
            // Tell the delegate to update the interface
            if( aPageNeedsToAdvance && [_delegate respondsToSelector:@selector(updateUI)] )
                [_delegate performSelectorOnMainThread:@selector(updateUI) withObject:nil waitUntilDone:NO];
            
            [self incrementTick];
        }];

        
    } else {
        [self incrementTick];
    }
    
}

- (void) clockLateBy:(uint64_t)ns
{
    //NSLog(@"\nClock tick was late by: %fms", (Float64)ns / 1000000.0);
    
    if( [_delegate respondsToSelector:@selector(showClockLateIndicator)] )
        [_delegate performSelectorOnMainThread:@selector(showClockLateIndicator) withObject:nil waitUntilDone:NO];
}



#pragma mark - Private methods

- (EatsStepAdvance) needToAdvanceStep:(SequencerPage *)page
{
    SequencerPageState *pageState = [_sequencerState.pageStates objectAtIndex:page.id.unsignedIntegerValue];
    
    // If the page has been scrubbed
    if( pageState.nextStep && _currentTick % (_ticksPerMeasure / page.inSequencer.stepQuantization.intValue) == 0 ) {
        return EatsStepAdvance_Scrubbed;
        
    // If the sequence needs to advance
    } else if( _currentTick % (_ticksPerMeasure / page.stepLength.intValue) == 0 ) {
        return EatsStepAdvance_Normal;
        
    } else {
        return EatsStepAdvance_None;
    }
    
}

- (void) incrementTick
{
    // Increment the tick
    _currentTick++;
    if(_currentTick >= _ticksPerMeasure) _currentTick = 0;
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

- (void) stopNotes:(NSArray *)notes atTime:(uint64_t)ns
{
    
    for( NSMutableDictionary *note in notes ) {
        
        // Calculate swing
        SequencerPage *pageForNote = [note objectForKey:@"fromPage"];
        SequencerPageState *pageState = [_sequencerState.pageStates objectAtIndex:pageForNote.id.unsignedIntegerValue];
        uint64_t nsSwing = 0;
        
        // We only add swing when playing forward or reverse
        if( pageState.playMode.intValue == EatsSequencerPlayMode_Forward || pageState.playMode.intValue == EatsSequencerPlayMode_Reverse ) {
            
            // Position of note in the loop 0 - minQuantization
            uint position = ( pageState.currentStep.intValue * ( _minQuantization / pageForNote.stepLength.intValue ) );
            
            // Reverse position if we're playing in reverse
            if( pageState.playMode.intValue == EatsSequencerPlayMode_Reverse )
                position = _minQuantization - 1 - position;
            
            nsSwing = [EatsSwingUtils calculateSwingNsForPosition:position
                                                             type:pageForNote.swingType.intValue
                                                           amount:pageForNote.swingAmount.intValue
                                                              bpm:_bpm
                                                     qnPerMeasure:_qnPerMeasure
                                                  minQuantization:_minQuantization];
        }
        
        // Stop it
        [self stopMIDINote:[[note objectForKey:@"pitch"] intValue]
                 onChannel:[[note objectForKey:@"channel"] intValue]
              withVelocity:[[note objectForKey:@"velocity"] intValue]
                    atTime:ns + nsSwing];
    }
}

@end
